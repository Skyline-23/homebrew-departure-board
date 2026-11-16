#import <Cocoa/Cocoa.h>

FOUNDATION_EXPORT NSString *const DBSettingsChangedNotification;
FOUNDATION_EXPORT NSString *const DBStoredAPIKeyMask;

@interface DBSettingsStore : NSObject
+ (NSDictionary *)settings;
+ (NSString *)identifierForScreen:(NSScreen *)screen;
+ (BOOL)desktopIncludesScreen:(NSScreen *)screen settings:(NSDictionary *)settings;
+ (BOOL)saveSettings:(NSDictionary *)settings
    replacementAPIKey:(NSString *)apiKey
                error:(NSError **)error;
+ (void)submitSettings:(NSDictionary *)settings
     replacementAPIKey:(NSString *)apiKey
            completion:(void (^)(NSError *error))completion;
@end
