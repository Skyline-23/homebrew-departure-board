#import <Cocoa/Cocoa.h>

@interface DBDesktopController : NSObject
- (void)tick;
- (NSTimeInterval)preferredAnimationInterval;
- (void)refresh;
- (void)applyWallpaperWithCompletion:(void (^)(BOOL success))completion;
- (void)stop;
@end
