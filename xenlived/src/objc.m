#include <Foundation/Foundation.h>
#include "NSDistributedNotificationCenter.h"

void notify_tweak(char *widget_name, char is_config) {
    NSDistributedNotificationCenter *center = NSDistributedNotificationCenter.defaultCenter;
	[center postNotificationName: @"XenLiveRefresh" object: nil userInfo: @{
        @"widgetName" : [NSString stringWithUTF8String: widget_name],
        @"isConfig" : [NSNumber numberWithChar: is_config]
    } deliverImmediately: true];
    NSLog(@"notification posted");
}