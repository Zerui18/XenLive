#include <libgen.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <unistd.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <string.h>
#include <sys/ioctl.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <poll.h>
#include <pthread.h>
#include "protocol.h"
#include "tools.h"

#define RESP_OK "ok!"
#define RESP_ERR "err"
#define MAX_CONN_THREADS 5

int server_fd;
struct sockaddr_in server_addr;
unsigned int addr_len = sizeof(server_addr);

// Note: tids is accessed from multiple threads but it should be sparse enough to not require mutex.
pthread_t *tids[MAX_CONN_THREADS];
typedef struct {
    pthread_t tid;
    int conn_fd;
} conn_args;

int is_regular_file(const char *path) {
    struct stat path_stat;
    stat(path, &path_stat);
    return S_ISREG(path_stat.st_mode);
}

// Implemented in objc.m
void notify_tweak(char *widget_name, char is_config);

static void handle_request(request_header header, int conn_fd) {

    // Special request that takes no parameters.
    if (header.opcode == request_restart) {
        // Close server_fd and exit.
        close(server_fd);
        exit(0);
    }

    char *widget_name = read_into_cstr(conn_fd, header.widget_name_len);
    char *widget_type = read_into_cstr(conn_fd, header.widget_type_len);
    char *rel_path = read_into_cstr(conn_fd, header.file_relative_path_len);
    char file_path[256];
    sprintf(file_path, "/var/mobile/Library/Widgets/%s/%s/%s", widget_type, widget_name, rel_path);
    printf("got filepath: %s\n", file_path);
    // Success only reflect the status of getting the file_path correctly,
    // as well as writing to the file. We don't want to give too many errors.
    char success = 1;
    // NOTE: xenlived will be running as root with group mobile,
    // so we want to grant same file permissions to root and group mobile.
    switch (header.opcode) {
        case request_write: {
            // Open file, allowing creation and always clearing initial contents.
            int target_fd = open(file_path, O_WRONLY | O_CREAT | O_TRUNC, 0664);
            if (target_fd < 0) {
                success = 0;
                perror("open failed");
            }
            else {
                success = copy_into_file(conn_fd, target_fd, header.file_data_len);
            }
            close(target_fd);
            break;
        }
        case request_delete:
            if (is_regular_file((file_path))) {
                remove(file_path);
            }
            else {
                rm_tree(file_path, 0);
            }
            break;
        case request_create_folder:
            mkdir(file_path, 0774);
            break;
        case request_clear_folder:
            // Here the file_path would be the root folder of the widget.
            // To allow for transfering of new widgets, we create the folder if not exists.
            mkdir(file_path, 0774);
            // rm_tree should skip the root folder.
            rm_tree(file_path, 1);
            break;
        case request_refresh:
            // Perform full reload.
            notify_tweak(widget_name, 1);
            goto end;
            break;
    }

    if (header.options & option_perform_refresh) {
        char *filename = basename(file_path);
        notify_tweak(widget_name, strcmp(filename, "config.json") == 0);
    }

    end:

    free(widget_name);
    free(widget_type);
    free(rel_path);

    // Respond.
    write(conn_fd, success ? RESP_OK : RESP_ERR, 4);
}

static void cleanup_connection(conn_args *args) {
    close(args->conn_fd);
    char found_thread = 0;
    // Remove this thread from the global tids.
    printf("cleaning up %d\n", args->conn_fd);
    for (int i=0; i<MAX_CONN_THREADS; i++) {
        // Find this thread.
        if (tids[i] && pthread_equal(args->tid, *tids[i]) == 0) {
            found_thread = 1;
            // printf("found tid at %d\n", i);
            continue;
        }
        // Remove spaces in tids.
        // If found_thread, move current tid back a slot.
        if (found_thread) {
            tids[i-1] = tids[i];
            tids[i] = 0;
        }
    }
    free(args);
}

#define setsockopt_check(expr) if (expr < 0) { perror("setsockopt_check failed"); return; }

void enable_keepalive(int sock) {
    int yes = 1;
    setsockopt_check(setsockopt(sock, SOL_SOCKET, SO_KEEPALIVE, &yes, sizeof(int)))

    int interval = 1;
    setsockopt_check(setsockopt(sock, IPPROTO_TCP, TCP_KEEPINTVL, &interval, sizeof(int)));

    int maxpkt = 3;
    setsockopt_check(setsockopt(sock, IPPROTO_TCP, TCP_KEEPCNT, &maxpkt, sizeof(int)));
}

// Note: this is run is a new thread.
static void *handle_connection(conn_args *args) {
    int conn_fd = args->conn_fd;
    printf("handle connection with fd: %d\n", conn_fd);

    // enable_keepalive(conn_fd);
    pthread_cleanup_push(cleanup_connection, args);

    int idle_cnt = 0;
    request_header header;

    while (1) {
        // Block till new data is available.
        struct pollfd pollfd = {
            .fd = conn_fd,
            .events = POLLIN,
            .revents = 0
        };
        // 1s of timeout, bad things might happen if we do -1.
        poll(&pollfd, 1, 1000);
        // Case 1: socket closed.
        if (pollfd.revents & POLLHUP) {
            // Socket closed by client, exit thread.
            printf("client socket closed %d\n", conn_fd);
            break;
        }
        // Case 2: new connection.
        else if (pollfd.revents & POLLIN) {
            idle_cnt = 0;
            // Data is available.
            read(conn_fd, &header, sizeof(header));
            // Validate request header.
            if (strcmp(header.magic, "ZXL\0") == 0)
                handle_request(header, conn_fd);
        }
        // Case 3: just empty.
        else if (++idle_cnt == 1800) {
            // 30 mins of inactivity, client might be offline.
            // Close socket and exit thread.
            printf("idle_cnt == 1800, closing %d\n", conn_fd);
            break;
        }
    }

    pthread_cleanup_pop(1);
    pthread_exit(0);
}

static void accept_loop() {
    int conn_fd;

    while ((conn_fd = accept(server_fd, (struct sockaddr *) &server_addr, &addr_len)) >= 0) {
        conn_args *args = malloc(sizeof(conn_args));
        args->conn_fd = conn_fd;
        // Find empty slot in tids or cancel the 1st thread there.
        int i = 0;
        while (i<MAX_CONN_THREADS) {
            if (!tids[i]) {
                printf("found empty slot at: %d\n", i);
                break;
            }
            i++;
        }
        // If no empyt slot found, cancel the 1st thread.
        if (i == MAX_CONN_THREADS) {
            printf("no empty slot, cancelling 1st thread\n");
            pthread_cancel(*tids[0]);
            // Wait for the thread to perform cleanup and terminate.
            pthread_join(*tids[0], 0);
            // Now the last slot should be open.
            i = MAX_CONN_THREADS - 1;
        }
        // Apparently pthread_create doesn't malloc, so we do it manually to prevent SEGFAULT.
        tids[i] = malloc(sizeof(pthread_t));
        if (pthread_create(tids[i], 0, handle_connection, args) < 0) {
            perror("pthread_create failed");
        }
    }

    if (conn_fd < 0) {
        perror("accept failed");
    }

    close(server_fd);
}

static int start_server() {
    server_fd = socket(AF_INET, SOCK_STREAM, 0);

    if (server_fd == 0) {
        perror("socket failed");
        exit(1);
    }

    int opt = 1;
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, sizeof(opt)) == 0) {
        perror("setsockopt failed");
        exit(1);
    }

    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(2021);

    if (bind(server_fd, (struct sockaddr *) &server_addr, sizeof(server_addr)) < 0) {
        perror("bind failed");
        exit(1);
    }

    if (listen(server_fd, 5) < 0) {
        perror("listen failed");
        exit(1);
    }

    accept_loop();

    return 0;
}

void sigint(int sig) {
    close(server_fd);
    exit(0);
}

int main() {
    signal(SIGINT, sigint); 
    return start_server();
}