#import <Cocoa/Cocoa.h>

@interface DBAirlineLogoStore : NSObject
+ (NSImage *)imageForCarrier:(NSString *)iata icao:(NSString *)icao name:(NSString *)name;
@end
