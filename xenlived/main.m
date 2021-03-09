#include <Foundation/Foundation.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <fcntl.h>
#include <microhttpd.h>

#define PORT 2021

typedef struct {
    char *data;
    size_t length;
} post_data;

static void copyToSharedMemory(char *buf, size_t len) {
    // Open shared memory.
    int sharedMem = open("/tmp/xenlived", O_RDWR | O_CREAT, 0666);
    // Resize.
    ftruncate(sharedMem, len + 1);
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
            post_data data = { 0, 0 };
            *con_cls = &data;
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
        response = MHD_create_response_from_buffer(strlen("Gotit\n"), (void*) "Gotit\n", MHD_RESPMEM_PERSISTENT);
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
    daemon = MHD_start_daemon(MHD_USE_INTERNAL_POLLING_THREAD, PORT, 0, 0, &answer_to_connection, 0, MHD_OPTION_END);
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