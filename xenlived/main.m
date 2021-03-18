#include <Foundation/Foundation.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <fcntl.h>
#include <microhttpd.h>
#include <stdio.h>
#include "NSDistributedNotificationCenter.h"

static void notifyTweak(const char *url) {
    NSDistributedNotificationCenter *center = NSDistributedNotificationCenter.defaultCenter;
    size_t len = strlen(url);
	[center postNotificationName: @"XenLiveReceivedUpdate" object: nil userInfo: @{
        @"action" : [[NSString alloc] initWithBytes: url+1 length: 1 encoding: NSUTF8StringEncoding],
        @"widgetPath" : [[NSString alloc] initWithBytes: url+2 length: len-2 encoding: NSUTF8StringEncoding]
    } deliverImmediately: true];
    NSLog(@"notification posted");
}

enum MHD_Result answer_to_connection(void *cls, struct MHD_Connection *connection,
                         const char *url,
                         const char *method, const char *version,
                         const char *upload_data,
                         size_t *upload_data_size, void **con_cls) {
    struct MHD_Response *response;
    enum MHD_Result ret;
    // Main get request.
    if (strcmp(method, "GET") == 0) {
        notifyTweak(url);
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
    daemon = MHD_start_daemon(MHD_USE_SELECT_INTERNALLY, 2021, 0, 0, &answer_to_connection, 0, MHD_OPTION_END);
    if (!daemon) return -1;
    // Block.
    NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
    [runLoop run];
    return 0;
}

int main(int argc, char *argv[], char *envp[]) {
    // Start server.
    startServer(2021);
}