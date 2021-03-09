#import "echo.h"

#define PRODUCTION
#define ADDR @"192.168.0.106"
#define PORT 8765

static const dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

void echo(NSString *format, ...) {
    #ifndef PRODUCTION
    va_list args;
    va_start(args, format);
    NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *encodedStr = [str stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSURL *url = [NSURL URLWithString: [[NSString alloc] initWithFormat:@"http://%@:%d?info=%@", ADDR, PORT, encodedStr]];
    dispatch_async(queue, ^{
        NSLog(@"%@", [[NSData alloc] initWithContentsOfURL: url]);
    });
    #endif
}