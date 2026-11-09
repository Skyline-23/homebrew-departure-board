#import "LiveFlightStore.h"
#import "DepartureBoardView.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <Security/Security.h>
#import <pwd.h>
#import <unistd.h>

static NSString *const TokenService = @"io.skyline.departureboard.gateway";

@implementation LiveFlightStore

+ (NSString *)userHome {
    // legacyScreenSaver can report the host's container as NSHomeDirectory().
    struct passwd *user = getpwuid(getuid());
    return user ? [NSString stringWithUTF8String:user->pw_dir] : NSHomeDirectory();
}

+ (NSURL *)cacheURLForAirport:(NSString *)airport {
    NSString *path = [[self userHome]
        stringByAppendingPathComponent:@"Library/Application Support/DepartureBoard/Flights"];
    [NSFileManager.defaultManager createDirectoryAtPath:path
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:NULL];
    return [NSURL
        fileURLWithPath:[path
                            stringByAppendingPathComponent:[airport stringByAppendingPathExtension:@"json"]]];
}

+ (NSDictionary *)tokenQuery {
    return @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : TokenService,
        (__bridge id)kSecAttrAccount : @"default"
    };
}

+ (NSString *)accessToken {
    NSMutableDictionary *query = [[self tokenQuery] mutableCopy];
    query[(__bridge id)kSecReturnData] = @YES;
    LAContext *context = LAContext.new;
    context.interactionNotAllowed = YES;
    query[(__bridge id)kSecUseAuthenticationContext] = context;
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess)
        return @"";
    NSData *data = CFBridgingRelease(result);
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

+ (BOOL)saveAccessToken:(NSString *)token error:(NSError **)error {
    if (!token.length)
        return YES; // Empty input keeps the existing saved token.
    NSData *data = [token dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *updates = @{(__bridge id)kSecValueData : data};
    OSStatus status =
        SecItemUpdate((__bridge CFDictionaryRef)[self tokenQuery], (__bridge CFDictionaryRef)updates);
    if (status == errSecItemNotFound) {
        NSMutableDictionary *query = [[self tokenQuery] mutableCopy];
        [query addEntriesFromDictionary:updates];
        status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }
    if (status != errSecSuccess && error)
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    return status == errSecSuccess;
}

+ (NSDate *)dateFromISO:(NSString *)value {
    if (![value isKindOfClass:NSString.class])
        return nil;
    NSISO8601DateFormatter *formatter = NSISO8601DateFormatter.new;
    formatter.formatOptions =
        NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSDate *date = [formatter dateFromString:value];
    if (!date) {
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        date = [formatter dateFromString:value];
    }
    return date;
}

+ (NSDictionary *)cachedSnapshotForAirport:(NSString *)airport {
    NSData *data = [NSData dataWithContentsOfURL:[self cacheURLForAirport:airport]];
    id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    return [json isKindOfClass:NSDictionary.class] ? json : nil;
}

+ (NSArray<NSDictionary *> *)rowsForLocation:(NSDictionary *)location now:(NSDate *)now {
    NSDictionary *snapshot = [self cachedSnapshotForAirport:location[@"code"]];
    NSDate *fetched = [self dateFromISO:snapshot[@"fetchedAt"]];
    if (!fetched || [now timeIntervalSinceDate:fetched] > 86400)
        return @[];
    NSDictionary *statusKeys = @{
        @"Unknown" : @"unknown",
        @"Expected" : @"scheduled",
        @"CheckIn" : @"checkin",
        @"Boarding" : @"boarding",
        @"GateClosed" : @"closed",
        @"Departed" : @"departed",
        @"EnRoute" : @"departed",
        @"Delayed" : @"delayed",
        @"Canceled" : @"cancelled",
        @"CanceledUncertain" : @"unknown",
        @"Diverted" : @"diverted"
    };
    NSDictionary *cityAliases = @{
        @"NRT" : @"TYO",
        @"HND" : @"TYO",
        @"ICN" : @"SEL",
        @"GMP" : @"SEL",
        @"CDG" : @"PAR",
        @"ORY" : @"PAR",
        @"LHR" : @"LON",
        @"LGW" : @"LON",
        @"JFK" : @"NYC",
        @"EWR" : @"NYC",
        @"KIX" : @"OSA",
        @"ITM" : @"OSA",
        @"PEK" : @"BJS",
        @"PKX" : @"BJS",
        @"PVG" : @"SHA",
        @"MXP" : @"MIL",
        @"FCO" : @"ROM"
    };
    NSMutableArray *rows = NSMutableArray.new;
    for (id value in snapshot[@"flights"]) {
        if (![value isKindOfClass:NSDictionary.class])
            continue;
        NSDictionary *flight = value;
        NSDate *scheduled = [self dateFromISO:flight[@"scheduledUtc"]];
        if (!scheduled || [scheduled timeIntervalSinceDate:now] < -1800)
            continue;
        NSDate *revised = [self dateFromISO:flight[@"revisedUtc"]];
        NSString *destinationCode = flight[@"destinationCode"] ?: @"";
        NSString *cityKey =
            [@"city." stringByAppendingString:cityAliases[destinationCode] ?: destinationCode];
        BOOL hasTranslation = ![DBBoardString(cityKey, @"en") isEqual:cityKey];
        NSDictionary *destination =
            hasTranslation ? @{@"key" : cityKey} : @{@"en" : flight[@"destinationName"] ?: destinationCode};
        NSString *number = flight[@"number"] ?: @"";
        [rows addObject:@{
            @"time" : DBTime(scheduled, location, @"HH:mm"),
            @"expected" : revised ? DBTime(revised, location, @"HH:mm") : @"",
            @"destination" : destination,
            @"flight" : number,
            @"gate" : flight[@"gate"] ?: @"",
            @"terminal" : flight[@"terminal"] ?: @"",
            @"counter" : flight[@"checkIn"] ?: @"",
            @"state" : statusKeys[flight[@"status"]] ?: @"unknown",
            @"color" : @"345d82",
            @"airline" : flight[@"airlineName"] ?: @"",
            @"minutes" : @((NSInteger)ceil([(revised ?: scheduled) timeIntervalSinceDate:now] / 60)),
            @"identity" : @((NSInteger)scheduled.timeIntervalSince1970)
        }];
    }
    return rows;
}

+ (BOOL)refreshWithError:(NSError **)error {
    NSDictionary *settings = [NSUserDefaults.standardUserDefaults persistentDomainForName:DBDefaultsDomain];
    NSString *airport = settings[@"location"] ?: @"ICN";
    if (![DBLocation(airport)[@"kind"] isEqual:@"airport"])
        return YES;
    NSString *base = settings[@"gatewayURL"] ?: @"";
    NSURLComponents *components = [NSURLComponents componentsWithString:base];
    if (![components.scheme isEqual:@"https"] || !components.host.length) {
        if (error)
            *error = [NSError
                errorWithDomain:DBDefaultsDomain
                           code:1
                       userInfo:@{NSLocalizedDescriptionKey : @"Set the HTTPS gateway URL in Settings."}];
        return NO;
    }
    NSString *token = [self accessToken];
    if (!token.length) {
        if (error)
            *error = [NSError
                errorWithDomain:DBDefaultsDomain
                           code:2
                       userInfo:@{NSLocalizedDescriptionKey : @"Set the gateway access token in Settings."}];
        return NO;
    }
    components.path = [NSString stringWithFormat:@"/v1/departures/%@", airport];
    components.query = nil;
    components.fragment = nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:components.URL];
    request.timeoutInterval = 25;
    [request setValue:[@"Bearer " stringByAppendingString:token] forHTTPHeaderField:@"Authorization"];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSData *bytes;
    __block NSURLResponse *response;
    __block NSError *failure;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
                                     completionHandler:^(NSData *data, NSURLResponse *reply, NSError *err) {
                                         bytes = data;
                                         response = reply;
                                         failure = err;
                                         dispatch_semaphore_signal(done);
                                     }] resume];
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) != 0)
        return NO;
    NSInteger status = [(NSHTTPURLResponse *)response statusCode];
    if (failure || status != 200) {
        if (error)
            *error =
                failure
                    ?: [NSError
                           errorWithDomain:DBDefaultsDomain
                                      code:status
                                  userInfo:@{
                                      NSLocalizedDescriptionKey : [NSString
                                          stringWithFormat:@"The gateway returned HTTP %ld.", (long)status]
                                  }];
        return NO;
    }
    id body = [NSJSONSerialization JSONObjectWithData:bytes options:0 error:&failure];
    if (![body isKindOfClass:NSDictionary.class] || ![body[@"airport"] isEqual:airport] ||
        ![body[@"flights"] isKindOfClass:NSArray.class])
        return NO;
    return [bytes writeToURL:[self cacheURLForAirport:airport] options:NSDataWritingAtomic error:error];
}

+ (void)refreshInBackground {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [self refreshWithError:NULL];
    });
}

+ (void)configureBackgroundRefresh {
    NSString *folder = [[self userHome] stringByAppendingPathComponent:@"Library/LaunchAgents"];
    [NSFileManager.defaultManager createDirectoryAtPath:folder
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:NULL];
    NSString *path = [folder stringByAppendingPathComponent:@"io.skyline.departureboard.refresh.plist"];
    NSString *executable = NSBundle.mainBundle.executablePath;
    for (NSString *application in @[
             [[self userHome] stringByAppendingPathComponent:@"Applications/Departure Board.app"],
             @"/Applications/Departure Board.app"
         ]) {
        NSBundle *bundle = [NSBundle bundleWithPath:application];
        if ([bundle.bundleIdentifier isEqual:@"io.skyline.departureboard.preview"]) {
            executable = [application stringByAppendingPathComponent:@"Contents/MacOS/DepartureBoard"];
            break;
        }
    }
    NSDictionary *job = @{
        @"Label" : @"io.skyline.departureboard.refresh",
        @"ProgramArguments" : @[ executable, @"--refresh-data" ],
        @"StartInterval" : @900,
        @"RunAtLoad" : @YES,
        @"ProcessType" : @"Background"
    };
    [job writeToFile:path atomically:YES];
    NSTask *task = NSTask.new;
    task.executableURL = [NSURL fileURLWithPath:@"/bin/launchctl"];
    task.arguments = @[ @"bootstrap", [NSString stringWithFormat:@"gui/%u", getuid()], path ];
    [task launchAndReturnError:NULL];
}
@end
