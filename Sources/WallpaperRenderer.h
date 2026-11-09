#import <Cocoa/Cocoa.h>

// Runs in a short-lived, windowless process so image buffers are returned on exit.
@interface DBWallpaperRenderer : NSObject
+ (NSString *)rootPath;
+ (NSString *)identifierForScreen:(NSScreen *)screen;
+ (BOOL)renderRequest:(NSDictionary *)request;
@end
