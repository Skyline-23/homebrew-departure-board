#import <Foundation/Foundation.h>

@interface DBDestinationStore : NSObject
+ (NSString *)nameForAirport:(NSString *)airport
                    language:(NSString *)language
                    fallback:(NSString *)fallback;
+ (void)refreshNamesForFlights:(NSArray<NSDictionary *> *)flights;
@end
