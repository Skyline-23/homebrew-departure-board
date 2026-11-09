#import <Cocoa/Cocoa.h>

@interface DBDesktopController : NSObject
- (void)tick;
- (NSTimeInterval)preferredAnimationInterval;
- (void)refresh;
- (BOOL)applyWallpaper;
@end
