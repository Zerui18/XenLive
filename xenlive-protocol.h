#import <Foundation/Foundation.h>
#import <stdint.h>

/*
Protocol:
Data begins with a `request_header`.
Followed by non-null-terminated widgetName, fileRelativePath and data.

In case of 'DEL' and 'del': dataLength will be 0 and data empty.
*/

typedef struct {
    char type[4]; // One of RequestType, last byte denotes isDirectory and is one of '/' or '.'
    uint32_t widgetNameLength;
    uint32_t fileRelativePathLength;
    uint32_t dataLength;
} request_header;

@interface XenLiveAction: NSObject
@property NSString *type;
@property NSString *widgetName;
@property NSString *fileRelativePath;
@property bool *isDirectory;
@property NSData *data;
    - (id) initWithData: (NSData *) data;
@end

// enum RequestType
#define kRequestTypeCreate = 'CRE',
#define kRequestTypeUpdate = 'UPD',
#define kRequestTypeDelete = 'DEL',
#define kRequestTypeDeleteNoReload = 'del',
#define kRequestTypeCreateNoReload = 'cre',
