#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import "echo.h"
#import "XenHWidgetController.h"

%group main

%hook XENHWidgetController

- (instancetype) init {
    XENHWidgetController *s = %orig;
    [NSNotificationCenter.defaultCenter addObserver: self
                                        selector: sel_registerName("handleUpdateWithNotification:")
                                        name: @"XenLiveReceivedUpdate"
                                        object: nil];
    return s;
}

%new
- (void) handleUpdateWithNotification: (NSNotification *) notification {
    NSLog(@"%@ got notification with data: %@.", self, (NSData *) notification.object);
    if ([self.widgetIndexFile rangeOfString: @"/var/mobile/Library/SBHTML/Dynamic"] != NSStringNotFound) {
        // Overwrite self.widgetIndexFile with the new data and reload self.
        NSData *data = (NSData *) notification.object;
        [data writeToFile: self.widgetIndexFile atomically: true];
        [self reloadWidget];
        NSLog(@"Widget reloaded.");
    }
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
    [NSNotificationCenter.defaultCenter postNotificationName: @"XenLiveReceivedUpdate" object: data];
}

%ctor {
    %init(main);
    loadLookinServer();
    // Listen for respring requests from pref.
	CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(center, nil, newthingCallback, CFSTR("com.zx02.xenlive/newthing"), nil, CFNotificationSuspensionBehaviorDeliverImmediately);
}