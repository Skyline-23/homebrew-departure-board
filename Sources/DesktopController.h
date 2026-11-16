#import <Cocoa/Cocoa.h>

@interface DBDesktopController : NSObject
- (void)tick;
- (BOOL)hasDesktopWindows;
- (NSTimeInterval)preferredAnimationInterval;
- (void)refresh;
- (void)applyWallpaperWithCompletion:(void (^)(BOOL success))completion;
- (void)stop;
@end
