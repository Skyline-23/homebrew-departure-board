#import "Diagnostics.h"
#import <os/log.h>

NSDictionary *DBDiagnosticFields(NSDictionary *fields) {

    static NSSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        allowed = [NSSet setWithArray:@[
            @"airport", @"state", @"mode", @"status", @"count", @"elapsedMs", @"retrySeconds",
            @"errorCode", @"errorDomain", @"preview", @"version", @"view", @"cacheAgeSeconds"
        ]];
    });
    NSMutableDictionary *result = NSMutableDictionary.new;

    for (NSString *key in fields) {
        id value = fields[key];

        if (![allowed containsObject:key]) {
            continue;
        }

        if ([value isKindOfClass:NSNumber.class]) {
            result[key] = value;
        } else if ([value isKindOfClass:NSString.class]) {
            result[key] = [value substringToIndex:MIN(128, [value length])];
        }
    }
    return result;
}

void DBDiagnosticEvent(NSString *category, NSString *event, NSDictionary *fields) {

    static NSMutableDictionary *loggers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        loggers = NSMutableDictionary.new;
    });
    os_log_t logger;
    @synchronized(loggers) {
        logger = loggers[category];

        if (!logger) {
            logger = os_log_create("com.skyline23.departureboard", category.UTF8String);
            loggers[category] = logger;
        }
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:DBDiagnosticFields(fields ?: @{})
                                                   options:NSJSONWritingSortedKeys
                                                     error:NULL];
    NSString *details = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    os_log(logger, "%{public}@ %{public}@", event, details ?: @"{}");
}
