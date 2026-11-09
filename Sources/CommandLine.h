#import <Foundation/Foundation.h>

@class DBBoardView;

@interface DBCommandLine : NSObject
// Returns nil for an interactive launch; handled commands return their exit code.
+ (NSNumber *)runWithArguments:(NSArray<NSString *> *)arguments;
+ (DBBoardView *)boardWithArguments:(NSArray<NSString *> *)arguments;
@end
