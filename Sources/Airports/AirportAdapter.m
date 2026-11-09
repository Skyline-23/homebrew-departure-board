#import "AirportAdapters.h"

@implementation DBAirportRenderContext

- (instancetype)initWithDate:(NSDate *)date
                    language:(NSString *)language
                        rows:(NSArray *)rows
                        page:(NSInteger)page
                       scale:(CGFloat)scale
                     density:(NSInteger)density
             emptyMessageKey:(NSString *)emptyMessageKey {

    if ((self = [super init])) {
        _date = date;
        _language = [language copy];
        _rows = [rows copy];
        _page = page;
        _scale = scale;
        _density = density;
        _emptyMessageKey = [emptyMessageKey copy];
    }
    return self;
}

@end

id<DBAirportAdapter> DBAirportAdapterForLocation(NSDictionary *location) {

    if (![location[@"kind"] isEqual:@"airport"]) {
        return nil;
    }
    static NSDictionary<NSString *, Class> *adapters;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        adapters = @{
            @"profile" : DBProfileAirportAdapter.class,
            @"incheon" : DBIncheonAirportAdapter.class,
            @"haneda" : DBHanedaAirportAdapter.class
        };
    });
    NSString *identifier = location[@"display"][@"adapter"] ?: @"profile";
    Class adapterClass = adapters[identifier];
    NSCAssert(adapterClass, @"Unknown airport adapter: %@", identifier);
    return [[adapterClass alloc] initWithLocation:location];
}
