#import <Foundation/Foundation.h>

// Only the companion app calls AeroDataBox directly. The screen saver reads a cache
// and never opens a Keychain prompt over the user's lock screen.
@interface LiveFlightStore : NSObject
+ (NSString *)userHome;
+ (NSArray<NSDictionary *> *)rowsForLocation:(NSDictionary *)location now:(NSDate *)now;
+ (NSDictionary *)cachedSnapshotForAirport:(NSString *)airport;
+ (BOOL)refreshWithError:(NSError **)error;
+ (BOOL)refreshAirport:(NSString *)airport error:(NSError **)error;
+ (NSDictionary *)normalizeDepartures:(NSDictionary *)payload airport:(NSString *)airport;
+ (void)refreshInBackground;
+ (BOOL)saveAPIKey:(NSString *)apiKey error:(NSError **)error;
+ (NSString *)APIKey;
+ (void)configureBackgroundRefresh;
+ (BOOL)shouldRefreshInBackground;
+ (BOOL)screenSaverIsActive;
@end
