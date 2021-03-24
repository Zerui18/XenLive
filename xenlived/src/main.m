#import <Foundation/Foundation.h>
#include <libgen.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <unistd.h>
#include <netinet/in.h>
#include <string.h>
#include <sys/ioctl.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <poll.h>
#include "protocol.h"
#include "tools.h"
#import "NSDistributedNotificationCenter.h"

#define RESP_OK "ok!"
#define RESP_ERR "err"

int server_fd;
struct sockaddr_in server_addr;
unsigned int addr_len = sizeof(server_addr);

int is_regular_file(const char *path) {
    struct stat path_stat;
    stat(path, &path_stat);
    return S_ISREG(path_stat.st_mode);
}

static void notify_tweak(char *widget_name, char is_config) {
    NSDistributedNotificationCenter *center = NSDistributedNotificationCenter.defaultCenter;
	[center postNotificationName: @"XenLiveRefresh" object: nil userInfo: @{
        @"widgetName" : [NSString stringWithUTF8String: widget_name],
        @"isConfig" : [NSNumber numberWithChar: is_config]
    } deliverImmediately: true];
    NSLog(@"notification posted");
}

static void handle_request(request_header header, int sock_fd) {
    char *widget_name = read_into_cstr(sock_fd, header.widget_name_len);
    char *widget_type = read_into_cstr(sock_fd, header.widget_type_len);
    char *rel_path = read_into_cstr(sock_fd, header.file_relative_path_len);
    char file_path[256];
    sprintf(file_path, "/var/mobile/Library/Widgets/%s/%s/%s", widget_type, widget_name, rel_path);
    // Success only reflect the status of getting the file_path correctly,
    // as well as writing to the file. We don't want to give too many errors.
    char success = 1;

    switch (header.opcode) {
        case request_write: {
            // Open file, allowing creation and always clearing initial contents.
            int target_fd = open(file_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
            success = copy_into_file(sock_fd, target_fd, header.file_data_len);
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
            mkdir(file_path, 0744);
            break;
        case request_clear_folder:
            // Here the file_path would be the root folder of the widget,
            // so we tell rm_tree to skip the root folder.
            rm_tree(file_path, 1);
            break;
    }

    char *filename = basename(file_path);
    notify_tweak(widget_name, strcmp(filename, "config.json") == 0);

    free(widget_name);
    free(widget_type);
    free(rel_path);

    // Respond.
    write(sock_fd, success ? RESP_OK : RESP_ERR, 4);
}

static void handle_connection(int sock_fd) {
    request_header header;
    while (1) {
        // Block till new data is available.
        struct pollfd pollfd = {
            .fd = sock_fd,
            .events = POLLIN,
            .revents = 0
        };
        // 5s of timeout, bad things might happen if we do -1.
        poll(&pollfd, 1, 5000);
        if (pollfd.revents & POLLIN) {
            // Data is available.
            read(sock_fd, &header, sizeof(header));
            // Validate request header.
            if (strcmp(header.magic, "ZXL\0") == 0)
                handle_request(header, sock_fd);
        }
        else if (pollfd.revents & POLLHUP) {
            // Socket closed.
            break;
        }
    }
}

static void accept_loop() {
    int sock_fd;

    while ((sock_fd = accept(server_fd, (struct sockaddr *) &server_addr, &addr_len)) >= 0) {
        handle_connection(sock_fd);
    }

    if (sock_fd < 0) {
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