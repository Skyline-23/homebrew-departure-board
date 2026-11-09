#import <Cocoa/Cocoa.h>

FOUNDATION_EXPORT NSString *const DBDefaultsDomain;
FOUNDATION_EXPORT NSArray<NSDictionary *> *DBLocations(void);
FOUNDATION_EXPORT NSDictionary *DBLocation(NSString *code);
FOUNDATION_EXPORT NSArray<NSDictionary *> *DBDepartures(NSDictionary *location, NSDate *now,
                                                        NSUInteger count);
FOUNDATION_EXPORT NSString *DBTime(NSDate *date, NSDictionary *location, NSString *format);
FOUNDATION_EXPORT NSString *DBLocalized(NSDictionary *record, NSString *language);
FOUNDATION_EXPORT NSString *DBBoardString(NSString *key, NSString *language);
FOUNDATION_EXPORT NSString *DBUIString(NSString *key);

@interface DBBoardView : NSView
@property(nonatomic, copy) NSString *locationCode;
@property(nonatomic, copy) NSString *displayStyle;
@property(nonatomic, copy) NSString *languageMode;
@property(nonatomic) BOOL reducedMotion;
@property(nonatomic) NSInteger density;
@property(nonatomic) double brightness;
@property(nonatomic) BOOL useSampleData;
@property(nonatomic, strong) NSDate *referenceDate;
- (void)tick;
- (NSTimeInterval)preferredAnimationInterval;
- (void)reloadSettings;
- (void)saveSettings;
- (NSDictionary *)snapshotConfiguration;
- (void)applySnapshotConfiguration:(NSDictionary *)configuration;
- (BOOL)writeSnapshot:(NSString *)path size:(NSSize)size;
@end

@interface DBBoardView (SettingsController)
- (NSWindow *)settingsWindowWithTarget:(id)target action:(SEL)action;
- (void)applySettingsFromWindow:(NSWindow *)window completion:(void (^)(BOOL saved))completion;
@end
