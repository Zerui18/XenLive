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

%ctor {
    %init(main);
}