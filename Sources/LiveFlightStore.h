#import <Foundation/Foundation.h>

// Only the companion app contacts the gateway. The screen saver reads a cache
// and never opens a Keychain prompt over the user's lock screen.
@interface LiveFlightStore : NSObject
+ (NSArray<NSDictionary *> *)rowsForLocation:(NSDictionary *)location now:(NSDate *)now;
+ (NSDictionary *)cachedSnapshotForAirport:(NSString *)airport;
+ (BOOL)refreshWithError:(NSError **)error;
+ (void)refreshInBackground;
+ (BOOL)saveAccessToken:(NSString *)token error:(NSError **)error;
+ (NSString *)accessToken;
+ (void)configureBackgroundRefresh;
@end
