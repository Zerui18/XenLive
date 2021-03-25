#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ftw.h>

#define BUF_SIZE 1024 * 4
#define min(a, b) a < b ? a:b

// REMOVE TREE
static char skip_root_folder;
static char *root_folder_path;

static inline int rm_file(const char *path, const struct stat *sbuf, int type, struct FTW *ftwb) {
    if (skip_root_folder && strcmp(path, root_folder_path) == 0) {
        return 0;
    }
    if (remove(path) < 0) {
        perror("rm_file failed");
        return -1;
    }
    printf("removed: %s\n", path);
    return 0;
}

int rm_tree(char *path, char skip_root_folder_flag) {
    skip_root_folder = skip_root_folder_flag;
    root_folder_path = path;
    if (nftw(path, rm_file, 10, FTW_DEPTH | FTW_MOUNT | FTW_PHYS) < 0) {
        perror("ntfw failed");
        return -1;
    }
    root_folder_path = 0;
    return 0;
}

// READING
char *read_into_cstr(int sock_fd, size_t len) {
    char *buffer = malloc(len + 1);
    int read_len = 0, part_len;
    while(read_len < len) {
        part_len = read(sock_fd, buffer + read_len, min(BUF_SIZE, len - read_len));
        if (part_len < 0) {
            perror("read failed");
            free(buffer);
            return 0;
        }
        read_len += part_len;
    }
    buffer[len] = '\0';
    return buffer;
}

int copy_into_file(int sock_fd, int file_fd, size_t len) {
    char buffer[BUF_SIZE];
    int read_len = 0, part_len;
    while(read_len < len) {
        part_len = read(sock_fd, buffer, min(BUF_SIZE, len - read_len));
        if (part_len < 0) {
            perror("read failed");
            return -1;
        }
        read_len += part_len;
        write(file_fd, buffer, part_len);
    }
    return 0;
}