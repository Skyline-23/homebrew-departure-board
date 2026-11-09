#import "DepartureBoardView.h"
#import "DestinationStore.h"

NSString *const DBDefaultsDomain = @"com.skyline23.departureboard";

static NSDictionary *DBData(void) {

    static NSDictionary *data;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSBundle *bundle = [NSBundle bundleForClass:DBBoardView.class];
        id (^readJSON)(NSString *, NSString *) = ^id(NSString *name, NSString *directory) {
            NSURL *url = [bundle URLForResource:name withExtension:@"json" subdirectory:directory];
            NSData *bytes = url ? [NSData dataWithContentsOfURL:url] : nil;
            return bytes ? [NSJSONSerialization JSONObjectWithData:bytes options:0 error:NULL]
                         : nil;
        };
        NSMutableArray *locations = NSMutableArray.new;

        for (NSString *code in readJSON(@"LocationOrder", nil)) {
            NSDictionary *location = readJSON(code, @"Locations");

            if (location) {
                [locations addObject:location];
            }
        }
        data = @{
            @"locations" : locations,
            @"cities" : readJSON(@"Cities", nil) ?: @{},
            @"airlines" : readJSON(@"Airlines", nil) ?: @{}
        };
    });
    return data;
}

NSArray<NSDictionary *> *DBLocations(void) {

    return DBData()[@"locations"] ?: @[];
}

NSDictionary *DBLocation(NSString *code) {

    for (NSDictionary *location in DBLocations()) {
        if ([location[@"code"] isEqual:code]) {
            return location;
        }
    }
    return DBLocations().firstObject ?: @{};
}

NSString *DBTime(NSDate *date, NSDictionary *location, NSString *format) {

    static NSMutableDictionary *formatters;

    if (!formatters) {
        formatters = NSMutableDictionary.new;
    }
    NSString *key = [NSString stringWithFormat:@"%@/%@", location[@"zone"], format];
    NSDateFormatter *formatter = formatters[key];

    if (!formatter) {
        formatter = NSDateFormatter.new;
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone =
            [NSTimeZone timeZoneWithName:location[@"zone"]] ?: NSTimeZone.localTimeZone;
        formatter.dateFormat = format;
        formatters[key] = formatter;
    }
    return [formatter stringFromDate:date];
}

NSString *DBLocalized(NSDictionary *record, NSString *language) {

    if (record[@"airport"]) {
        return [DBDestinationStore nameForAirport:record[@"airport"]
                                         language:language
                                         fallback:record[@"en"]];
    }

    if (record[@"key"]) {
        return DBBoardString(record[@"key"], language);
    }
    return record[language] ?: record[@"en"] ?: @"";
}

NSArray<NSDictionary *> *DBDepartures(NSDictionary *location, NSDate *now, NSUInteger count) {

    NSArray *routes = location[@"routes"];

    if (!routes.count) {
        return @[];
    }
    BOOL rail = [location[@"kind"] isEqual:@"rail"];
    NSInteger step = rail ? 240 : 300;
    NSInteger slot = (NSInteger)floor(now.timeIntervalSince1970 / step) - 1;
    NSMutableArray *rows = NSMutableArray.new;

    for (NSUInteger i = 0; i < count; i++) {
        NSInteger ident = slot + (NSInteger)i;
        NSUInteger routeIndex =
            (NSUInteger)((ident % (NSInteger)routes.count + (NSInteger)routes.count) %
                         (NSInteger)routes.count);
        NSDictionary *route = routes[routeIndex];
        NSMutableDictionary *row = [route mutableCopy];
        NSDate *departure = [NSDate dateWithTimeIntervalSince1970:ident * step];
        NSInteger seed = labs(ident * 31 + (NSInteger)routeIndex * 17);
        NSInteger delay = (seed % 23 == 0) ? 15 : 0;
        NSInteger minutes = (NSInteger)ceil([departure timeIntervalSinceDate:now] / 60.0) + delay;
        BOOL cancelled = (seed % 149 == 0);
        NSString *state = cancelled                    ? @"cancelled"
                          : delay                      ? @"delayed"
                          : minutes < 0                ? @"departed"
                          : minutes <= (rail ? 2 : 8)  ? @"closing"
                          : minutes <= (rail ? 5 : 25) ? @"boarding"
                          : minutes <= 45              ? @"gate"
                                                       : @"scheduled";
        row[@"state"] = state;
        row[@"time"] = DBTime(departure, location, @"HH:mm");
        row[@"expected"] =
            delay ? DBTime([departure dateByAddingTimeInterval:delay * 60], location, @"HH:mm")
                  : @"";
        row[@"minutes"] = @(MAX(0, minutes));
        row[@"identity"] = @(ident);

        if (!rail) {
            NSDictionary *airline = DBData()[@"airlines"][route[@"carrier"]];
            row[@"airline"] = airline[@"name"] ?: route[@"carrier"];
            row[@"color"] = airline[@"color"] ?: @"4985a9";
            row[@"destination"] = DBData()[@"cities"][route[@"city"]] ?: @{@"en" : route[@"city"]};
            row[@"flight"] = [NSString stringWithFormat:@"%@ %03ld", route[@"carrier"],
                                                        (long)[route[@"number"] integerValue]];
            NSArray *gates = location[@"gates"];
            row[@"gate"] = gates[(NSUInteger)seed % gates.count];
        } else {
            row[@"gate"] = route[@"platform"] ?: @"1";
            row[@"flight"] = [NSString stringWithFormat:@"%ld", (long)(seed % 400 + 1)];
            row[@"airline"] = DBLocalized(route[@"service"], @"en");
        }
        [rows addObject:row];
    }
    return rows;
}
