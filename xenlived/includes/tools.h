int rm_tree(const char *path, char skip_root_folder);

char *read_into_cstr(int sock_fd, size_t len);

int copy_into_file(int sock_fd, int file_fd, size_t len);