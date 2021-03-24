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
        name: @"XenLiveRefresh"
        object: nil
        // NSNotificationSuspensionBehaviorDeliverImmediately = 4
        suspensionBehavior: 4];
    return s;
}

%new
- (void) didReceiveRemoteNotification: (NSNotification *) notification {
    NSString *widgetName = [notification.userInfo objectForKey: @"widgetName"];
    NSNumber *isConfig = [notification.userInfo objectForKey: @"isConfig"];
    // Check if the action's targeted at this widget.
    NSString *selfWidgetName = self.widgetIndexFile.stringByDeletingLastPathComponent.lastPathComponent;
    if ([selfWidgetName isEqualToString: widgetName]) {
        // 3: Refresh XenHTML
        if (isConfig.boolValue) {
            // If the user changed the config, we should inject the new config params and perform full reload.
            // Load new config.
            NSString *configPath = [self.widgetIndexFile.stringByDeletingLastPathComponent stringByAppendingPathComponent: @"config.json"];
            XENHWidgetConfiguration *config = [%c(XENHWidgetConfiguration) defaultConfigurationForPath: configPath];
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