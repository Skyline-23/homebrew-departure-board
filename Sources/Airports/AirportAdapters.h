#import "AirportAdapter.h"

// Default adapter reads the individual airport's JSON profile.
@interface DBProfileAirportAdapter : NSObject <DBAirportAdapter>
- (instancetype)initWithLocation:(NSDictionary *)location;
@end

@interface DBIncheonAirportAdapter : DBProfileAirportAdapter
@end

@interface DBHanedaAirportAdapter : DBProfileAirportAdapter
@end
