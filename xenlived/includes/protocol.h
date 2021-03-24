typedef enum {
    request_write  = 0,
    request_delete = 1,
    request_create_folder = 2,
    request_clear_folder = 3,
} request_type;

typedef struct {
    char magic[4];
    request_type opcode:4;
    unsigned int widget_name_len;
    unsigned int widget_type_len;
    unsigned int file_relative_path_len;
    unsigned int file_data_len;
} request_header;