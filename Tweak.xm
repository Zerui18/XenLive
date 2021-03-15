#import <Foundation/Foundation.h>
#include <stdint.h>
#import <dlfcn.h>
#import "XenHWidgetController.h"
#import "XenHWidgetConfiguration.h"
#import "xenlive-protocol.h"

#define STREQ(a, b) [a isEqualToString: b]
#define ACTION_IS(type) STREQ(action.type, kRequestType##type)

%group main

%hook XENHWidgetController

- (instancetype) init {
    XENHWidgetController *s = %orig;

    // Doesn't look good but smh we can't create a new method on this class.
    [NSNotificationCenter.defaultCenter
        addObserverForName: @"XenLiveReceivedUpdate"
        object: nil
        queue: nil
        usingBlock: ^(NSNotification *notification) {
            NSString *name = s.widgetIndexFile.stringByDeletingLastPathComponent.lastPathComponent;
            XenLiveAction *action = (XenLiveAction *) notification.object;
            // Check if the action's targeted at this widget.
            if (STREQ(action.widgetName, name)) {
                // 1: Get filePath of targeted file.
                NSString *folder = s.widgetIndexFile.stringByDeletingLastPathComponent;
                NSString *filePath = [folder stringByAppendingPathComponent: action.fileRelativePath];
                // 2: Perform action.
                // We try to do things the safest way to prevent mis-syncs as much as possible.
                if (ACTION_IS(Update) || ACTION_IS(Create) || ACTION_IS(CreateNoReload)) {
                    // Purge file by removing it.
                    if ([NSFileManager.defaultManager fileExistsAtPath: filePath]) {
                        [NSFileManager.defaultManager removeItemAtPath: filePath error: nil];
                    }
                    // Create intermediate directories if necessary.
                    
                    // Create new file with data.
                    [NSFileManager.defaultManager createFileAtPath: filePath contents: action.data attributes: nil];
                    if (ACTION_IS(CreateNoReload)) return;
                }
                else if (ACTION_IS(Delete) || ACTION_IS(DeleteNoReload)) {
                    [NSFileManager.defaultManager removeItemAtPath: filePath error: nil];
                    if (ACTION_IS(DeleteNoReload)) return;
                }
                // 3: Refresh XenHTML
                if (STREQ(action.fileRelativePath, @"config.json")) {
                    // If the user changed the config, we should inject the new config params and perform full reload.
                    // Load new config.
                    XENHWidgetConfiguration *config = [%c(XENHWidgetConfiguration) defaultConfigurationForPath: filePath];
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
        }];
    return s;
}

%end

%end

static void loadLookinServer() {
    const char* lookinPath = "/Library/Frameworks/LookinServer.framework/LookinServer";
    if(!dlopen(lookinPath, RTLD_NOW)) {
        const char* error = dlerror();
        NSLog(@"LookinServer failed to load with error: %s", error);
    }
    else {
        NSLog(@"LookinServer loaded.");
    }
}

static void newthingCallback(CFNotificationCenterRef center, void * observer, CFStringRef name, void const * object, CFDictionaryRef userInfo) {
    NSData *data = [NSData dataWithContentsOfFile: @"/tmp/xenlived"];
    XenLiveAction *action = [[%c(XenLiveAction) alloc] initWithData: data];
    NSLog(@"got action: %@", action);
    [NSNotificationCenter.defaultCenter postNotificationName: @"XenLiveReceivedUpdate" object: action];
}

%ctor {
    %init(main);
    // loadLookinServer();
    // Listen for respring requests from pref.
	CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(center, nil, newthingCallback, CFSTR("com.zx02.xenlive/newthing"), nil, CFNotificationSuspensionBehaviorDeliverImmediately);
}