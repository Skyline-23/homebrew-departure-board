#import <Cocoa/Cocoa.h>

@interface DBBackgroundAgent : NSObject
+ (void)configure;
+ (void)recordApplicationStarted;
+ (void)recordApplicationQuit;
+ (void)performMaintenance;
+ (NSRunningApplication *)runningApplication;
+ (BOOL)shouldStartForSettings:(NSDictionary *)settings
                  runtimeState:(NSDictionary *)state
                bootIdentifier:(NSString *)bootIdentifier;
@end
