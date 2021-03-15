#include <Foundation/Foundation.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <fcntl.h>
#include <microhttpd.h>
#include <stdio.h>

#define min(a, b) a < b ? a : b

// void hexDump (const char * desc, const void * addr, const int len) {
//     int i;
//     unsigned char buff[17];
//     const unsigned char * pc = (const unsigned char *)addr;

//     // Output description if given.

//     if (desc != NULL)
//         printf ("%s:\n", desc);

//     // Length checks.

//     if (len == 0) {
//         printf("  ZERO LENGTH\n");
//         return;
//     }
//     else if (len < 0) {
//         printf("  NEGATIVE LENGTH: %d\n", len);
//         return;
//     }

//     // Process every byte in the data.

//     for (i = 0; i < len; i++) {
//         // Multiple of 16 means new line (with line offset).

//         if ((i % 16) == 0) {
//             // Don't print ASCII buffer for the "zeroth" line.

//             if (i != 0)
//                 printf ("  %s\n", buff);

//             // Output the offset.

//             printf ("  %04x ", i);
//         }

//         // Now the hex code for the specific character.
//         printf (" %02x", pc[i]);

//         // And buffer a printable ASCII character for later.

//         if ((pc[i] < 0x20) || (pc[i] > 0x7e)) // isprint() may be better.
//             buff[i % 16] = '.';
//         else
//             buff[i % 16] = pc[i];
//         buff[(i % 16) + 1] = '\0';
//     }

//     // Pad out last line if not exactly 16 characters.

//     while ((i % 16) != 0) {
//         printf ("   ");
//         i++;
//     }

//     // And print the final ASCII buffer.

//     printf ("  %s\n", buff);
// }

#define PORT 2021

typedef struct {
    char *data;
    size_t length;
} post_data;

static void copyToSharedMemory(char *buf, size_t len) {
    // Open shared memory.
    // PS: yes it's a file for now, maybe try shm_open later.
    int sharedMem = open("/tmp/xenlived", O_RDWR | O_CREAT, 0666);
    // Resize.
    ftruncate(sharedMem, len);
    // Write.
    if (write(sharedMem, buf, len) < 0)
        printf("write error: %d", errno);
    // Close.
    close(sharedMem);
}

static void notifyTweak() {
	CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterPostNotification(center, CFSTR("com.zx02.xenlive/newthing"), nil, nil, true);
}

int answer_to_connection(void *cls, struct MHD_Connection *connection,
                         const char *url,
                         const char *method, const char *version,
                         const char *upload_data,
                         size_t *upload_data_size, post_data **con_cls) {
    struct MHD_Response *response;
    int ret;
    // Main post request.
    if (strcmp(method, "POST") == 0) {
        if (*con_cls == NULL) {
            // New request.
            // Definitely use malloc to have it on the heap.
            post_data *data = malloc(sizeof(post_data));
            data->length = 0;
            data->data = NULL;
            *con_cls = data;
            return MHD_YES;
        }
        if (*upload_data_size > 0) {
            // Append data.
            post_data *data = *con_cls;
            const int new_data_length = data->length + *upload_data_size;
            char *new_data = (char *) malloc(new_data_length);
            memcpy(new_data, data->data, data->length);
            memcpy(new_data + data->length, upload_data, *upload_data_size);
            if (data->data)
                free(data->data);
            data->data = new_data;
            data->length = new_data_length;
            // Report that we've 'considered' this chunk.
            *upload_data_size = 0;
            return MHD_YES;
        }
        // End of request:
        // Not new request && no upload_data
        post_data *data = *con_cls;
        // Send data to tweak.
        copyToSharedMemory(data->data, data->length);
        notifyTweak();
        // Send response.
        response = MHD_create_response_from_buffer(7, (void*) "Gotit\n", MHD_RESPMEM_PERSISTENT);
        ret = MHD_queue_response(connection, MHD_HTTP_OK, response);
        MHD_destroy_response(response);
        return ret;
    }
    // Handle other requests.
    response = MHD_create_response_from_buffer(strlen("Unsupported request\n"), (void *) "Unsupported request\n", MHD_RESPMEM_PERSISTENT);
    ret = MHD_queue_response(connection, MHD_HTTP_BAD_REQUEST, response);
    MHD_destroy_response(response);
    return ret;
}

static int startServer(int port) {
    // Launch MHD server.
    struct MHD_Daemon *daemon;
    daemon = MHD_start_daemon(MHD_USE_SELECT_INTERNALLY, PORT, 0, 0, &answer_to_connection, 0, MHD_OPTION_END);
    if (!daemon) return -1;
    // Block.
    getchar();
    // Stop MHD server.
    MHD_stop_daemon(daemon);
    return 0;
}

int main(int argc, char *argv[], char *envp[]) {
    // Start server.
    startServer(2021);
}