typedef enum {
    request_connect = 0,
    request_write  = 1,
    request_delete = 2,
    request_create_folder = 3,
    request_clear_folder = 4,
    request_refresh = 5,
    request_restart = 6,
} request_type;

typedef struct {
    char magic[4];
    request_type opcode:4;
    unsigned int widget_name_len;
    unsigned int widget_type_len;
    unsigned int file_relative_path_len;
    unsigned int file_data_len;
    unsigned int options;
} request_header;

#define option_perform_refresh 1<<0