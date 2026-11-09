#import "LiveFlightStore.h"
#import "DepartureBoardView.h"
#import "DestinationStore.h"
#import "SettingsStore.h"
#import <CoreGraphics/CoreGraphics.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <Security/Security.h>
#import <fcntl.h>
#import <pwd.h>
#import <sys/file.h>
#import <unistd.h>

static NSString *const APIKeyService = @"com.skyline23.departureboard.aerodatabox";

static NSDictionary *ObjectDictionary(id value) {

    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static BOOL MovementsCompatible(NSDictionary *first, NSDictionary *second,
                                BOOL requirePhysicalMatch) {

    if (![first[@"scheduledUtc"] isEqual:second[@"scheduledUtc"]] ||
        ![first[@"destinationCode"] length] ||
        ![first[@"destinationCode"] isEqual:second[@"destinationCode"]]) {
        return NO;
    }
    BOOL physicalMatch = NO;

    for (NSString *key in @[ @"gate", @"terminal", @"aircraft", @"callSign" ]) {
        NSString *a = first[key], *b = second[key];

        if (!a.length || !b.length) {
            continue;
        }

        if (![a isEqual:b]) {
            return NO;
        }

        if (![key isEqual:@"terminal"]) {
            physicalMatch = YES;
        }
    }
    return !requirePhysicalMatch || physicalMatch;
}

static void MergeFlightVariants(NSMutableDictionary *flight, NSDictionary *alias) {

    NSMutableArray *variants = [flight[@"variants"] mutableCopy] ?: NSMutableArray.new;
    NSMutableSet *numbers = [NSMutableSet setWithArray:[variants valueForKey:@"number"]];

    for (NSDictionary *variant in alias[@"variants"]) {
        if (![numbers containsObject:variant[@"number"]]) {
            [variants addObject:variant];
            [numbers addObject:variant[@"number"]];
        }
    }
    flight[@"variants"] = variants;

    for (NSString *key in @[ @"gate", @"terminal", @"checkIn", @"aircraft", @"callSign" ]) {
        if (![flight[key] length] && [alias[key] length]) {
            flight[key] = alias[key];
        }
    }
}

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
    return [NSURL fileURLWithPath:[path stringByAppendingPathComponent:
                                            [airport stringByAppendingPathExtension:@"json"]]];
}

+ (NSDictionary *)APIKeyQuery {

    return @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : APIKeyService,
        (__bridge id)kSecAttrAccount : @"default"
    };
}

+ (NSString *)APIKey {

    NSMutableDictionary *query = [[self APIKeyQuery] mutableCopy];
    query[(__bridge id)kSecReturnData] = @YES;
    LAContext *context = LAContext.new;
    context.interactionNotAllowed = YES;
    query[(__bridge id)kSecUseAuthenticationContext] = context;
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    BOOL legacy = NO;

    if (status == errSecItemNotFound) {
        query[(__bridge id)kSecAttrService] = @"io.skyline.departureboard.aerodatabox";
        status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
        legacy = status == errSecSuccess;
    }

    if (status != errSecSuccess) {
        return @"";
    }
    NSData *data = CFBridgingRelease(result);
    NSString *key = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";

    if (legacy && key.length) {
        [self saveAPIKey:key error:NULL];
    }
    return key;
}

+ (BOOL)saveAPIKey:(NSString *)apiKey error:(NSError **)error {

    if (!apiKey.length) {
        return YES; // Empty input keeps the existing saved apiKey.
    }
    NSData *data = [apiKey dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *updates = @{(__bridge id)kSecValueData : data};
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)[self APIKeyQuery],
                                    (__bridge CFDictionaryRef)updates);

    if (status == errSecItemNotFound) {
        NSMutableDictionary *query = [[self APIKeyQuery] mutableCopy];
        [query addEntriesFromDictionary:updates];
        status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }

    if (status != errSecSuccess && error) {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }

    if (status == errSecSuccess) {
        NSString *folder = [self cacheURLForAirport:@"ICN"].path.stringByDeletingLastPathComponent;

        for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:folder
                                                                                 error:NULL]) {
            if ([name hasSuffix:@".retry.plist"]) {
                [NSFileManager.defaultManager
                    removeItemAtPath:[folder stringByAppendingPathComponent:name]
                               error:NULL];
            }
        }
    }
    return status == errSecSuccess;
}

// Empty revised times are common. Cache failed parses too, so every board tick
// does not construct three formatters for the same missing provider value.
+ (NSDate *)dateFromISO:(NSString *)value {

    if (![value isKindOfClass:NSString.class] || !value.length) {
        return nil;
    }
    static NSCache *dates;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dates = NSCache.new;
        dates.countLimit = 4000;
    });
    id cached = [dates objectForKey:value];

    if (cached) {
        return cached == NSNull.null ? nil : cached;
    }
    NSMutableDictionary *thread = NSThread.currentThread.threadDictionary;
    NSArray *parsers = thread[@"DepartureBoard.dateParsers"];

    if (!parsers) {
        NSISO8601DateFormatter *fractional = NSISO8601DateFormatter.new;
        fractional.formatOptions =
            NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        NSISO8601DateFormatter *standard = NSISO8601DateFormatter.new;
        standard.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        NSDateFormatter *provider = NSDateFormatter.new;
        provider.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        provider.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        provider.dateFormat = @"yyyy-MM-dd HH:mmX";
        parsers = @[ fractional, standard, provider ];
        thread[@"DepartureBoard.dateParsers"] = parsers;
    }
    NSDate *date = nil;

    for (id parser in parsers) {
        date = [parser dateFromString:value];

        if (date) {
            break;
        }
    }
    [dates setObject:date ?: NSNull.null forKey:value];
    return date;
}

+ (NSArray *)groupCodeshares:(NSArray *)records {

    NSArray *ordered =
        [records sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            NSInteger aQuality = ([a[@"aircraft"] length] > 0) + ([a[@"callSign"] length] > 0);
            NSInteger bQuality = ([b[@"aircraft"] length] > 0) + ([b[@"callSign"] length] > 0);

            if (aQuality != bQuality) {
                return aQuality > bQuality ? NSOrderedAscending : NSOrderedDescending;
            }
            return [a[@"number"] compare:b[@"number"] options:NSNumericSearch];
        }];
    NSMutableArray *flights = NSMutableArray.new, *aliases = NSMutableArray.new;

    for (NSDictionary *record in ordered) {
        if ([record[@"codeshareStatus"] isEqual:@"IsCodeshared"]) {
            [aliases addObject:record];
            continue;
        }
        NSMutableDictionary *match = nil;

        for (NSMutableDictionary *flight in flights) {
            if (MovementsCompatible(flight, record, YES)) {
                match = flight;
                break;
            }
        }

        if (match) {
            MergeFlightVariants(match, record);
        } else {
            [flights addObject:[record mutableCopy]];
        }
    }

    for (NSDictionary *alias in aliases) {
        NSMutableArray *matches = NSMutableArray.new;

        for (NSMutableDictionary *flight in flights) {
            if (MovementsCompatible(flight, alias, NO)) {
                [matches addObject:flight];
            }
        }

        if (matches.count == 1) {
            MergeFlightVariants(matches.firstObject, alias);
        }
        // An ambiguous marketing number must not become a second physical flight.
        // Keep displaying the known operating flights until the next feed resolves it.
    }
    return [flights sortedArrayUsingDescriptors:@[
        [NSSortDescriptor sortDescriptorWithKey:@"scheduledUtc" ascending:YES],
        [NSSortDescriptor sortDescriptorWithKey:@"number" ascending:YES]
    ]];
}

+ (NSDictionary *)normalizeDepartures:(NSDictionary *)payload airport:(NSString *)airport {

    NSMutableDictionary *unique = NSMutableDictionary.new;
    NSISO8601DateFormatter *formatter = NSISO8601DateFormatter.new;

    for (NSDictionary *flight in payload[@"departures"]) {
        if (![flight isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSDictionary *departure = ObjectDictionary(flight[@"departure"]);

        if (!departure.count) {
            departure = ObjectDictionary(flight[@"movement"]);
        }
        NSDictionary *destination =
            ObjectDictionary(ObjectDictionary(flight[@"arrival"])[@"airport"]);

        if (!destination.count) {
            destination = ObjectDictionary(ObjectDictionary(flight[@"movement"])[@"airport"]);
        }
        NSDate *scheduled =
            [self dateFromISO:ObjectDictionary(departure[@"scheduledTime"])[@"utc"]];
        NSString *number = flight[@"number"];

        if (!scheduled || ![number isKindOfClass:NSString.class]) {
            continue;
        }
        NSDate *revised = [self dateFromISO:ObjectDictionary(departure[@"revisedTime"])[@"utc"]];
        NSMutableDictionary *row = NSMutableDictionary.new;
        NSDictionary *fields = @{
            @"number": number, @"scheduledUtc": [formatter stringFromDate:scheduled],
            @"revisedUtc": revised ? [formatter stringFromDate:revised] : @"",
            @"destinationCode": destination[@"iata"] ?: @"",
            @"destinationName": destination[@"municipalityName"] ?: destination[@"name"] ?: @"",
            @"status": flight[@"status"] ?: @"Unknown", @"gate": departure[@"gate"] ?: @"",
            @"terminal": departure[@"terminal"] ?: @"", @"checkIn": departure[@"checkInDesk"] ?: @"",
            @"airlineName": ObjectDictionary(flight[@"airline"])[@"name"] ?: @"",
            @"airlineICAO": ObjectDictionary(flight[@"airline"])[@"icao"] ?: @""
        };

        for (NSString *key in fields) {
            id value = fields[key];
            row[key] = [value isKindOfClass:NSString.class] ? value : @"";
        }
        row[@"codeshareStatus"] = flight[@"codeshareStatus"] ?: @"Unknown";
        row[@"aircraft"] = ObjectDictionary(flight[@"aircraft"])[@"reg"] ?: @"";
        row[@"callSign"] = flight[@"callSign"] ?: @"";
        row[@"variants"] = @[
            @{@"number" : number, @"airline" : row[@"airlineName"], @"icao" : row[@"airlineICAO"]}
        ];
        unique[[NSString stringWithFormat:@"%@/%@", number, row[@"scheduledUtc"]]] = row;
    }
    NSArray *flights = [self groupCodeshares:unique.allValues];
    return @{
        @"airport" : airport,
        @"source" : @"AeroDataBox",
        @"formatVersion" : @4,
        @"fetchedAt" : [formatter stringFromDate:NSDate.date],
        @"flights" : flights
    };
}

+ (NSDictionary *)cachedSnapshotForAirport:(NSString *)airport {

    static NSCache *snapshots;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        snapshots = NSCache.new;
        snapshots.countLimit = 4;
    });
    NSURL *url = [self cacheURLForAirport:airport];
    NSDate *modified =
        [NSFileManager.defaultManager attributesOfItemAtPath:url.path
                                                       error:NULL][NSFileModificationDate];
    NSDictionary *cached = [snapshots objectForKey:airport];

    if (modified && [cached[@"modified"] isEqual:modified]) {
        return cached[@"snapshot"];
    }
    NSData *data = [NSData dataWithContentsOfURL:url];
    id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;

    if ([json isKindOfClass:NSDictionary.class] && [json[@"formatVersion"] integerValue] < 4) {
        NSMutableDictionary *upgraded = [json mutableCopy];
        upgraded[@"flights"] = [self groupCodeshares:json[@"flights"] ?: @[]];
        upgraded[@"formatVersion"] = @4;
        json = upgraded;
    }

    if ([json isKindOfClass:NSDictionary.class] && modified) {
        [snapshots setObject:@{@"modified" : modified, @"snapshot" : json} forKey:airport];
    }
    return [json isKindOfClass:NSDictionary.class] ? json : nil;
}

+ (NSArray<NSDictionary *> *)rowsForLocation:(NSDictionary *)location now:(NSDate *)now {

    static NSCache *renderedRows;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        renderedRows = NSCache.new;
        renderedRows.countLimit = 4;
    });
    NSDictionary *snapshot = [self cachedSnapshotForAirport:location[@"code"]];
    NSTimeInterval timestamp = now.timeIntervalSince1970;
    NSDictionary *previous = [renderedRows objectForKey:location[@"code"]];

    if (previous[@"snapshot"] == snapshot && [previous[@"location"] isEqual:location] &&
        timestamp >= [previous[@"createdAt"] doubleValue] &&
        timestamp < [previous[@"validUntil"] doubleValue]) {
        return previous[@"rows"];
    }
    // Marketing flights change every four seconds. Minute countdowns, flight
    // expiry and refreshed snapshots can invalidate the rows sooner.
    NSTimeInterval validUntil = (floor(timestamp / 4) + 1) * 4;
    NSDate *fetched = [self dateFromISO:snapshot[@"fetchedAt"]];

    if (!fetched || [now timeIntervalSinceDate:fetched] > 86400) {
        return @[];
    }
    validUntil = MIN(validUntil, fetched.timeIntervalSince1970 + 86400 + .000001);
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
    NSMutableArray *rows = NSMutableArray.new;

    for (id value in snapshot[@"flights"]) {
        if (![value isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSDictionary *flight = value;
        NSString *terminal = location[@"terminal"];

        if (terminal.length && [flight[@"terminal"] length] &&
            ![flight[@"terminal"] isEqual:terminal]) {
            continue;
        }
        NSDate *scheduled = [self dateFromISO:flight[@"scheduledUtc"]];

        if (!scheduled || [scheduled timeIntervalSinceDate:now] < -1800) {
            continue;
        }
        NSDate *revised = [self dateFromISO:flight[@"revisedUtc"]];
        NSTimeInterval departure = (revised ?: scheduled).timeIntervalSince1970;
        NSInteger minutes = (NSInteger)ceil((departure - timestamp) / 60);
        validUntil = MIN(validUntil, departure - (minutes - 1) * 60);
        validUntil = MIN(validUntil, scheduled.timeIntervalSince1970 + 1800 + .000001);
        NSString *destinationCode = flight[@"destinationCode"] ?: @"";
        NSDictionary *destination =
            @{@"airport" : destinationCode, @"en" : flight[@"destinationName"] ?: destinationCode};
        NSString *number = flight[@"number"] ?: @"";
        NSString *airline = flight[@"airlineName"] ?: @"";
        NSString *airlineICAO = flight[@"airlineICAO"] ?: @"";
        NSArray *variants = flight[@"variants"];

        if (variants.count) {
            NSUInteger index = (NSUInteger)floor(now.timeIntervalSince1970 / 4.0) % variants.count;
            number = variants[index][@"number"];
            airline = variants[index][@"airline"];
            airlineICAO = variants[index][@"icao"] ?: @"";
        }
        NSString *state = statusKeys[flight[@"status"]] ?: @"unknown";
        BOOL timeChanged = revised && fabs([revised timeIntervalSinceDate:scheduled]) >= 60;

        if ([state isEqual:@"scheduled"] && [revised timeIntervalSinceDate:scheduled] >= 900) {
            state = @"delayed";
        }
        [rows addObject:@{
            @"time" : DBTime(scheduled, location, @"HH:mm"),
            @"expected" : timeChanged ? DBTime(revised, location, @"HH:mm") : @"",
            @"destination" : destination,
            @"flight" : number,
            @"operatorFlight" : flight[@"number"] ?: number,
            @"gate" : flight[@"gate"] ?: @"",
            @"terminal" : flight[@"terminal"] ?: @"",
            @"counter" : flight[@"checkIn"] ?: @"",
            @"state" : state,
            @"color" : @"345d82",
            @"airline" : airline,
            @"airlineICAO" : airlineICAO,
            @"minutes" : @(minutes),
            @"identity" : @((NSInteger)scheduled.timeIntervalSince1970)
        }];
    }
    NSArray *result = [rows copy];
    [renderedRows setObject:@{
        @"snapshot" : snapshot,
        @"createdAt" : @(timestamp),
        @"validUntil" : @(validUntil),
        @"location" : location,
        @"rows" : result
    }
                     forKey:location[@"code"]];
    return result;
}

+ (NSInteger)refreshFailureStatusForAirport:(NSString *)airport {

    NSString *path =
        [[self cacheURLForAirport:airport].path stringByAppendingString:@".retry.plist"];
    return [[NSDictionary dictionaryWithContentsOfFile:path][@"status"] integerValue];
}

+ (DBFlightAvailability)availabilityForAirport:(NSString *)airport {

    NSString *path = [self cacheURLForAirport:airport].path;
    int lock = open([path stringByAppendingString:@".lock"].fileSystemRepresentation, O_RDONLY);

    if (lock >= 0) {
        BOOL refreshing = flock(lock, LOCK_EX | LOCK_NB) != 0;

        if (!refreshing) {
            flock(lock, LOCK_UN);
        }
        close(lock);

        if (refreshing) {
            return DBFlightAvailabilityLoading;
        }
    }
    NSDictionary *snapshot = [self cachedSnapshotForAirport:airport];

    if (!snapshot && ![DBSettingsStore.settings[@"hasAPIKey"] boolValue]) {
        return DBFlightAvailabilityConfigurationRequired;
    }
    NSDictionary *failure =
        [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingString:@".retry.plist"]];

    if (failure) {
        return DBFlightAvailabilityUnavailable;
    }

    if (snapshot) {
        NSDate *fetched = [self dateFromISO:snapshot[@"fetchedAt"]];
        return fetched && -fetched.timeIntervalSinceNow < 86400 ? DBFlightAvailabilityEmpty
                                                                : DBFlightAvailabilityUnavailable;
    }
    return [DBSettingsStore.settings[@"hasAPIKey"] boolValue]
               ? DBFlightAvailabilityLoading
               : DBFlightAvailabilityConfigurationRequired;
}

+ (BOOL)refreshWithError:(NSError **)error {

    NSDictionary *settings = DBSettingsStore.settings;

    if ([settings[@"sampleData"] boolValue]) {
        return YES;
    }
    NSString *airport = settings[@"location"] ?: @"ICN";
    return [self refreshAirport:airport error:error];
}

+ (BOOL)refreshAirport:(NSString *)airport error:(NSError **)error {

    if (![DBLocation(airport)[@"kind"] isEqual:@"airport"]) {
        return YES;
    }
    // The app, a wake-up refresh and every display share this lock and cache.
    // A simultaneous request reuses the refresh already in progress.
    NSString *lockPath = [[self cacheURLForAirport:airport].path stringByAppendingString:@".lock"];
    int lock = open(lockPath.fileSystemRepresentation, O_CREAT | O_RDWR, 0600);

    if (lock < 0) {
        return NO;
    }

    if (flock(lock, LOCK_EX | LOCK_NB) != 0) {
        close(lock);
        return YES;
    }
    @try {
        return [self refreshLockedAirport:airport error:error];
    } @finally {
        flock(lock, LOCK_UN);
        close(lock);
    }
}

+ (void)recordFailureForAirport:(NSString *)airport
                         status:(NSInteger)status
                     retryAfter:(NSString *)retryAfter {

    NSString *path =
        [[self cacheURLForAirport:airport].path stringByAppendingString:@".retry.plist"];
    NSDictionary *previous = [NSDictionary dictionaryWithContentsOfFile:path];
    NSInteger failures = MIN(8, [previous[@"failures"] integerValue] + 1);
    NSTimeInterval delay = MIN(900, 60 * pow(2, failures - 1));

    if (status == 401 || status == 403 || status == 429) {
        delay = 3600;
    }

    if (retryAfter.doubleValue > 0) {
        delay = MAX(delay, retryAfter.doubleValue);
    }
    [@{
        @"failures" : @(failures),
        @"status" : @(status),
        @"retryAt" : [NSDate dateWithTimeIntervalSinceNow:delay]
    } writeToFile:path
        atomically:YES];
}

+ (BOOL)refreshLockedAirport:(NSString *)airport error:(NSError **)error {

    NSDictionary *cached = [self cachedSnapshotForAirport:airport];
    NSDate *fetched = [self dateFromISO:cached[@"fetchedAt"]];
    NSTimeInterval interval = MAX(60, [DBSettingsStore.settings[@"refreshInterval"] doubleValue]);

    if (fetched && [NSDate.date timeIntervalSinceDate:fetched] < interval &&
        [cached[@"formatVersion"] integerValue] >= 3) {
        return YES;
    }
    NSString *retryPath =
        [[self cacheURLForAirport:airport].path stringByAppendingString:@".retry.plist"];
    NSDictionary *retry = [NSDictionary dictionaryWithContentsOfFile:retryPath];

    if ([retry[@"retryAt"] timeIntervalSinceNow] > 0) {
        return YES;
    }
    NSString *key = [self APIKey];

    if (!key.length) {
        [self recordFailureForAirport:airport status:401 retryAfter:nil];

        if (error) {
            *error = [NSError errorWithDomain:DBDefaultsDomain
                                         code:2
                                     userInfo:@{
                                         NSLocalizedDescriptionKey :
                                             @"Enter your AeroDataBox RapidAPI key in Settings."
                                     }];
        }
        return NO;
    }
    NSString *address =
        [NSString stringWithFormat:
                      @"https://aerodatabox.p.rapidapi.com/flights/airports/iata/"
                      @"%@?offsetMinutes=-30&durationMinutes=720&direction=Departure&withLeg=true&"
                      @"withCancelled=true&"
                      @"withCodeshared=true&withCargo=false&withPrivate=false&withLocation=false",
                      airport];
    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:[NSURL URLWithString:address]];
    request.timeoutInterval = 25;
    [request setValue:key forHTTPHeaderField:@"X-RapidAPI-Key"];
    [request setValue:@"aerodatabox.p.rapidapi.com" forHTTPHeaderField:@"X-RapidAPI-Host"];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSData *bytes;
    __block NSURLResponse *response;
    __block NSError *failure;
    [[[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *reply, NSError *err) {
              bytes = data;
              response = reply;
              failure = err;
              dispatch_semaphore_signal(done);
          }] resume];

    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) != 0) {
        [self recordFailureForAirport:airport status:0 retryAfter:nil];
        return NO;
    }
    NSInteger status = [(NSHTTPURLResponse *)response statusCode];

    if (failure || status != 200) {
        [self recordFailureForAirport:airport
                               status:status
                           retryAfter:[(NSHTTPURLResponse *)response
                                          valueForHTTPHeaderField:@"Retry-After"]];

        if (error) {
            *error =
                failure
                    ?: [NSError errorWithDomain:DBDefaultsDomain
                                           code:status
                                       userInfo:@{
                                           NSLocalizedDescriptionKey : [NSString
                                               stringWithFormat:
                                                   @"AeroDataBox returned HTTP %ld. Check your "
                                                   @"API key, subscription and remaining quota.",
                                                   (long)status]
                                       }];
        }
        return NO;
    }
    id body = [NSJSONSerialization JSONObjectWithData:bytes options:0 error:&failure];

    if (![body isKindOfClass:NSDictionary.class] ||
        ![body[@"departures"] isKindOfClass:NSArray.class]) {
        [self recordFailureForAirport:airport status:status retryAfter:nil];
        return NO;
    }
    NSDictionary *snapshot = [self normalizeDepartures:body airport:airport];
    NSData *normalized = [NSJSONSerialization dataWithJSONObject:snapshot options:0 error:error];
    BOOL saved = [normalized writeToURL:[self cacheURLForAirport:airport]
                                options:NSDataWritingAtomic
                                  error:error];

    if (saved) {
        [NSFileManager.defaultManager removeItemAtPath:retryPath error:NULL];
        [DBDestinationStore refreshNamesForFlights:snapshot[@"flights"]];
    }
    return saved;
}

+ (void)refreshInBackground {

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [self refreshWithError:NULL];
    });
}

+ (BOOL)shouldRefreshInBackground {

    CGDirectDisplayID displays[16];
    uint32_t count = 0;

    if (CGGetOnlineDisplayList(16, displays, &count) == kCGErrorSuccess && count > 0) {
        BOOL allAsleep = YES;

        for (uint32_t index = 0; index < count; index++) {
            allAsleep &= CGDisplayIsAsleep(displays[index]);
        }

        if (allAsleep) {
            return NO;
        }
    }

    for (NSRunningApplication *app in [NSRunningApplication
             runningApplicationsWithBundleIdentifier:@"com.skyline23.departureboard"]) {
        if (app.processIdentifier != getpid() && !app.terminated) {
            return YES;
        }
    }
    return [self screenSaverIsActive];
}

+ (BOOL)screenSaverIsActive {

    for (NSString *container in @[
             @"com.apple.ScreenSaver.Engine.legacyScreenSaver",
             @"com.apple.ScreenSaver.Engine.legacyScreenSaver.x86-64"
         ]) {
        NSString *folder = [[self userHome]
            stringByAppendingPathComponent:
                [NSString
                    stringWithFormat:@"Library/Containers/%@/Data/Library/Caches/DepartureBoard",
                                     container]];

        for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:folder
                                                                                 error:NULL]) {
            if (![name hasPrefix:@"active-"]) {
                continue;
            }
            NSDate *modified = [NSFileManager.defaultManager
                attributesOfItemAtPath:[folder stringByAppendingPathComponent:name]
                                 error:NULL][NSFileModificationDate];

            if (modified && [NSDate.date timeIntervalSinceDate:modified] < 90) {
                return YES;
            }
        }
    }
    return NO;
}

@end
