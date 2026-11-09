#import "SettingsStore.h"
#import "DepartureBoardView.h"
#import "LiveFlightStore.h"
#import <unistd.h>

NSString *const DBSettingsChangedNotification = @"com.skyline23.departureboard.settingsChanged";
NSString *const DBStoredAPIKeyMask = @"••••••••••••";

static NSDictionary *cachedSettings;
static NSDate *settingsModified;
static NSTimeInterval nextSettingsCheck;

@implementation DBSettingsStore

+ (NSURL *)settingsURL {
    NSString *folder = [[LiveFlightStore userHome]
        stringByAppendingPathComponent:@"Library/Application Support/DepartureBoard"];
    return [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"Settings.plist"]];
}

+ (NSDictionary *)settings {
    @synchronized(self) {
        NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
        if (cachedSettings && now < nextSettingsCheck) {
            return cachedSettings;
        }
        nextSettingsCheck = now + 1;
        NSURL *url = self.settingsURL;
        NSDate *modified =
            [NSFileManager.defaultManager attributesOfItemAtPath:url.path
                                                           error:NULL][NSFileModificationDate];
        if (cachedSettings && modified && [modified isEqual:settingsModified]) {
            return cachedSettings;
        }
        cachedSettings = [NSDictionary dictionaryWithContentsOfURL:url]
            ?: [NSUserDefaults.standardUserDefaults persistentDomainForName:DBDefaultsDomain]
            ?: [NSUserDefaults.standardUserDefaults persistentDomainForName:@"io.skyline.departureboard"]
            ?: @{};
        settingsModified = modified;
        return cachedSettings;
    }
}

+ (BOOL)saveSettings:(NSDictionary *)settings
    replacementAPIKey:(NSString *)apiKey
                error:(NSError **)error {
    NSMutableDictionary *saved = [settings mutableCopy];
    [saved removeObjectForKey:@"gatewayURL"];
    [saved removeObjectForKey:@"hasAccessToken"];
    if (apiKey.length && ![apiKey isEqual:DBStoredAPIKeyMask]) {
        if (![LiveFlightStore saveAPIKey:apiKey error:error]) {
            return NO;
        }
        saved[@"hasAPIKey"] = @YES;
    } else if (!saved[@"hasAPIKey"]) {
        saved[@"hasAPIKey"] = @([LiveFlightStore APIKey].length > 0);
    }
    NSURL *url = self.settingsURL;
    if (![NSFileManager.defaultManager createDirectoryAtURL:url.URLByDeletingLastPathComponent
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:error]) {
        return NO;
    }
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:saved
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:error];
    if (!data || ![data writeToURL:url options:NSDataWritingAtomic error:error]) {
        return NO;
    }
    [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions : @0600}
                                   ofItemAtPath:url.path
                                          error:NULL];
    @synchronized(self) {
        cachedSettings = [saved copy];
        settingsModified = nil;
        nextSettingsCheck = 0;
    }
    [NSUserDefaults.standardUserDefaults setPersistentDomain:saved forName:DBDefaultsDomain];
    [NSDistributedNotificationCenter.defaultCenter
        postNotificationName:DBSettingsChangedNotification
                      object:nil
                    userInfo:nil
          deliverImmediately:YES];
    return YES;
}

+ (void)submitSettings:(NSDictionary *)settings
     replacementAPIKey:(NSString *)apiKey
            completion:(void (^)(NSError *error))completion {
    NSError *error = nil;
    [self saveSettings:settings replacementAPIKey:apiKey error:&error];
    completion(error);
}

@end
