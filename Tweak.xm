#import <Foundation/Foundation.h>
#include <stdint.h>
#import <dlfcn.h>
#import "XenHWidgetController.h"
#import "XenHWidgetConfiguration.h"
#include "NSDistributedNotificationCenter.h"

#define HTTPPORT 2021

%group main

%hook XENHWidgetController

- (instancetype) init {
    XENHWidgetController *s = %orig;
    [NSDistributedNotificationCenter.defaultCenter
        addObserver: s
        selector: sel_registerName("didReceiveRemoteNotification:")
        name: @"XenLiveReceivedUpdate"
        object: nil
        // NSNotificationSuspensionBehaviorDeliverImmediately = 4
        suspensionBehavior: 4];
    return s;
}

%new
- (void) didReceiveRemoteNotification: (NSNotification *) notification {
    NSString *notiWidgetPath = [notification.userInfo objectForKey: @"widgetPath"];
    // Check if the action's targeted at this widget.
    if ([self.widgetIndexFile hasPrefix: notiWidgetPath]) {
        // 3: Refresh XenHTML
        if ([[notification.userInfo objectForKey: @"action"] isEqualToString: @"R"]) {
            // If the user changed the config, we should inject the new config params and perform full reload.
            // Load new config.
            XENHWidgetConfiguration *config = [%c(XENHWidgetConfiguration) defaultConfigurationForPath:
                                                [notiWidgetPath stringByAppendingPathComponent: @"config.json"]];
            // Inject config into metadata.
            NSMutableDictionary *newMetadata = config.serialise.mutableCopy;
            // Preserve x and y values.
            for (id key in self.widgetMetadata) {
                if ([key hasPrefix: @"x"] || [key hasPrefix: @"y"]) {
                    [newMetadata setValue: [self.widgetMetadata valueForKey: key] forKey: key];
                }
            }
            // Finally overwrite widgetMetadata.
            self.widgetMetadata = newMetadata;
            // Reload widget.
            [self reloadWidget];
        }
        else {
            // Simply reload the webview.
            [self.webView reload];
        }
    }
}

%end

%end

// MHD_Result answer_to_connection(void *cls, struct MHD_Connection *connection,
//                          const char *url,
//                          const char *method, const char *version,
//                          const char *upload_data,
//                          size_t *upload_data_size, void **con_cls) {
//     struct MHD_Response *response;
//     MHD_Result ret;
//     // Main get request.
//     if (strcmp(method, "GET") == 0) {
//         [NSNotificationCenter.defaultCenter postNotificationName: @"XenLiveReceivedUpdate" object: nil];
//         NSLog(@"url: %s", url);
//         NSLog(@"data size: %lu", *upload_data_size);
//         // Send response.
//         response = MHD_create_response_from_buffer(7, (void*) "Gotit\n", MHD_RESPMEM_PERSISTENT);
//         ret = MHD_queue_response(connection, MHD_HTTP_OK, response);
//         MHD_destroy_response(response);
//         return ret;
//     }
//     // Handle other requests.
//     response = MHD_create_response_from_buffer(strlen("Unsupported request\n"), (void *) "Unsupported request\n", MHD_RESPMEM_PERSISTENT);
//     ret = MHD_queue_response(connection, MHD_HTTP_BAD_REQUEST, response);
//     MHD_destroy_response(response);
//     return ret;
// }

%ctor {
    %init(main);
    // Start http server.
    // static struct MHD_Daemon *daemon = MHD_start_daemon(MHD_USE_SELECT_INTERNALLY, HTTPPORT, 0, 0, &answer_to_connection, 0, MHD_OPTION_END);
}