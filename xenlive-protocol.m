#import "xenlive-protocol.h"

@implementation XenLiveAction

- (instancetype) initWithData: (NSData *) data {
    const char *bytes = data.bytes;
    // Parse header.
    request_header header = *(request_header *) bytes;
    self.type = [[NSString alloc] initWithBytes: header.type length: 3 encoding: NSUTF8StringEncoding];
    self.isDirectory = bytes[3] == '/' ? true:false;
    bytes += sizeof(request_header);
    // Parse actual data.
    // Read widget name.
    NSData *widgetNameData = [NSData dataWithBytes: bytes length: header.widgetNameLength];
    self.widgetName = [[NSString alloc] initWithData: widgetNameData encoding: NSUTF8StringEncoding];
    bytes += header.widgetNameLength;
    // Read file name.
    NSData *fileRelativePathData = [NSData dataWithBytes: bytes length: header.fileRelativePathLength];
    self.fileRelativePath = [[NSString alloc] initWithData: fileRelativePathData encoding: NSUTF8StringEncoding];
    bytes += header.fileRelativePathLength;
    // Read data.
    if (header.dataLength > 0) {
        self.data = [NSData dataWithBytes: bytes length: header.dataLength];
    }
    return [super init];
}

- (NSString *) description {
    return [NSString stringWithFormat: @"<type = %@, widgetName = %@, fileRelativePath = %@, dataLength = %lu>", 
                self.type, self.widgetName, self.fileRelativePath, self.data.length];
}

@end