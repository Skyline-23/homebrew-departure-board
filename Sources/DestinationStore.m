#import "DestinationStore.h"
#import "DepartureBoardView.h"
#import "LiveFlightStore.h"

static NSSet *DestinationWords(NSString *name) {

    NSString *folded = [name ?: @""
        stringByFoldingWithOptions:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch
                            locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    NSArray *words = [folded.lowercaseString
        componentsSeparatedByCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet];
    NSMutableSet *result = [NSMutableSet setWithArray:words];
    [result removeObject:@""];
    return result;
}

@implementation DBDestinationStore

+ (NSDictionary *)namesFromBindings:(NSArray *)rows providerNames:(NSDictionary *)providers {

    NSMutableDictionary *groups = NSMutableDictionary.new;

    for (NSDictionary *row in rows) {
        NSString *code = row[@"iata"][@"value"], *city = row[@"city"][@"value"];
        NSString *language = row[@"lang"][@"value"], *name = row[@"label"][@"value"];

        if (!code.length || !city.length || !language.length || !name.length) {
            continue;
        }
        NSMutableDictionary *cities = groups[code];

        if (!cities) {
            groups[code] = cities = NSMutableDictionary.new;
        }
        NSMutableDictionary *entry = cities[city];

        if (!entry) {
            cities[city] = entry =
                [@{@"labels" : NSMutableDictionary.new, @"links" : row[@"links"][@"value"] ?: @"0"}
                    mutableCopy];
        }
        entry[@"labels"][language] = name;
    }
    NSMutableDictionary *result = NSMutableDictionary.new;

    for (NSString *code in groups) {
        NSSet *sourceWords = DestinationWords(providers[code]);
        double best = -1;

        for (NSDictionary *entry in [groups[code] allValues]) {
            NSDictionary *labels = entry[@"labels"];
            NSSet *words = DestinationWords(labels[@"en"]);
            NSMutableSet *shared = [sourceWords mutableCopy];
            [shared intersectSet:words];
            double score = shared.count * 100.0 / MAX(1, sourceWords.count) +
                           shared.count * 10.0 / MAX(1, words.count) +
                           [entry[@"links"] doubleValue] / 100000.0;

            if (score > best) {
                best = score;
                result[code] = labels;
            }
        }
    }
    return result;
}

+ (NSURL *)cacheURL {

    return [NSURL fileURLWithPath:
                      [[LiveFlightStore userHome]
                          stringByAppendingPathComponent:
                              @"Library/Application Support/DepartureBoard/DestinationNames.json"]];
}

+ (NSDictionary *)names {

    static NSDictionary *seed;
    static NSDictionary *names;
    static NSDate *modified;
    static NSTimeInterval nextCheck;
    @synchronized(self) {
        NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;

        if (names && now < nextCheck) {
            return names;
        }
        nextCheck = now + 2;
        NSURL *url = self.cacheURL;
        NSDate *current =
            [NSFileManager.defaultManager attributesOfItemAtPath:url.path
                                                           error:NULL][NSFileModificationDate];

        if (names && ((current == nil && modified == nil) || [current isEqual:modified])) {
            return names;
        }

        if (!seed) {
            NSURL *bundled =
                [[NSBundle bundleForClass:DBBoardView.class] URLForResource:@"DestinationNames"
                                                              withExtension:@"json"];
            NSData *data = [NSData dataWithContentsOfURL:bundled];
            NSDictionary *body =
                data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
            seed = body[@"destinations"] ?: @{};
        }
        NSMutableDictionary *merged = [seed mutableCopy];
        NSData *data = [NSData dataWithContentsOfURL:url];
        NSDictionary *saved =
            data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
        [merged addEntriesFromDictionary:saved ?: @{}];
        names = [merged copy];
        modified = current;
        return names;
    }
}

+ (NSString *)nameForAirport:(NSString *)airport
                    language:(NSString *)language
                    fallback:(NSString *)fallback {

    NSDictionary *entry = self.names[airport];
    NSString *locale = language.lowercaseString;

    if ([locale isEqual:@"fil"]) {
        locale = @"tl";
    }
    NSString *name = entry[locale];

    if (!name && [locale hasPrefix:@"zh"]) {
        name = entry[@"zh"];
    }
    return name ?: entry[@"en"] ?: fallback ?: airport;
}

+ (void)refreshNamesForFlights:(NSArray<NSDictionary *> *)flights {

    NSMutableSet *missing = NSMutableSet.new;
    NSMutableDictionary *providers = NSMutableDictionary.new;
    NSDictionary *known = self.names;

    for (NSDictionary *flight in flights) {
        NSString *code = flight[@"destinationCode"];

        if (code.length) {
            providers[code] = flight[@"destinationName"] ?: @"";
        }

        if (code.length == 3 && !known[code]) {
            [missing addObject:code];
        }
    }

    if (!missing.count) {
        return;
    }
    // Destination metadata is independent of the paid flight feed. One batch
    // supplies every language; display ticks never perform network requests.
    NSMutableArray *values = NSMutableArray.new;

    for (NSString *code in missing) {
        if ([code rangeOfCharacterFromSet:NSCharacterSet.uppercaseLetterCharacterSet.invertedSet]
                .location == NSNotFound) {
            [values addObject:[NSString stringWithFormat:@"\"%@\"", code]];
        }
    }

    if (!values.count) {
        return;
    }
    NSString *query = [NSString
        stringWithFormat:@"SELECT ?iata ?city ?lang ?label ?links WHERE { VALUES ?iata { %@ } "
                          "?airport wdt:P238 ?iata; wdt:P931 ?city. ?city rdfs:label ?label; "
                          "wikibase:sitelinks ?links. "
                          "BIND(LANG(?label) AS ?lang) "
                          "FILTER(?lang IN "
                          "(\"en\",\"ja\",\"ko\",\"zh\",\"zh-hans\",\"zh-hant\",\"ar\",\"da\","
                          "\"de\",\"es\",\"fi\",\"tl\","
                          "\"fr\",\"hi\",\"id\",\"it\",\"ms\",\"nb\",\"nl\",\"pt\",\"sv\",\"th\","
                          "\"tr\")) } ORDER BY "
                          "DESC(?links)",
                         [values componentsJoinedByString:@" "]];
    NSURLComponents *url =
        [NSURLComponents componentsWithString:@"https://query.wikidata.org/sparql"];
    url.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"query" value:query],
        [NSURLQueryItem queryItemWithName:@"format" value:@"json"]
    ];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url.URL];
    request.timeoutInterval = 20;
    [request setValue:@"DepartureBoard/0.3 (https://github.com/Skyline-23/homebrew-departure-board)"
        forHTTPHeaderField:@"User-Agent"];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSData *bytes;
    [[[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              if (!error && [(NSHTTPURLResponse *)response statusCode] == 200) {
                  bytes = data;
              }
              dispatch_semaphore_signal(done);
          }] resume];

    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC)) != 0 ||
        !bytes) {
        return;
    }
    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:bytes options:0 error:NULL];
    NSArray *rows = body[@"results"][@"bindings"];

    if (![rows isKindOfClass:NSArray.class]) {
        return;
    }
    NSMutableDictionary *updated = [known mutableCopy];

    for (NSString *code in missing) {
        updated[code] = @{}; // Cache missing metadata too, avoiding a request per frame/refresh.
    }
    [updated addEntriesFromDictionary:[self namesFromBindings:rows providerNames:providers]];
    NSData *data = [NSJSONSerialization dataWithJSONObject:updated options:0 error:NULL];
    [data writeToURL:self.cacheURL options:NSDataWritingAtomic error:NULL];
}

@end
