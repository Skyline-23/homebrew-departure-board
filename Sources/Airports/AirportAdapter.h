#import <Cocoa/Cocoa.h>

@interface DBAirportRenderContext : NSObject
@property(nonatomic, strong, readonly) NSDate *date;
@property(nonatomic, copy, readonly) NSString *language;
@property(nonatomic, copy, readonly) NSArray<NSDictionary *> *rows;
@property(nonatomic, readonly) NSInteger page;
@property(nonatomic, readonly) CGFloat scale;
@property(nonatomic, readonly) NSInteger density;
@property(nonatomic, copy, readonly) NSString *emptyMessageKey;
- (instancetype)initWithDate:(NSDate *)date
                    language:(NSString *)language
                        rows:(NSArray *)rows
                        page:(NSInteger)page
                       scale:(CGFloat)scale
                     density:(NSInteger)density
             emptyMessageKey:(NSString *)emptyMessageKey;
@end

// Adapts one airport's configuration and custom signage to the shared table.
@protocol DBAirportAdapter <NSObject>
@property(nonatomic, copy, readonly) NSDictionary *location;
@property(nonatomic, copy, readonly) NSDictionary *display;
@property(nonatomic, copy, readonly) NSArray<NSString *> *columns;
@property(nonatomic, copy, readonly) NSString *compactTitleLanguage;
- (CGFloat)weightForColumn:(NSString *)column;
- (CGFloat)headerHeightForBounds:(NSRect)bounds scale:(CGFloat)scale;
- (CGFloat)columnHeaderHeight;
- (NSInteger)rowCountForBounds:(NSRect)bounds scale:(CGFloat)scale density:(NSInteger)density;
- (void)drawHeaderInBounds:(NSRect)bounds context:(DBAirportRenderContext *)context;
- (void)drawFooterInBounds:(NSRect)bounds context:(DBAirportRenderContext *)context;
- (void)drawCompactHeaderDecorationInRect:(NSRect)rect;
@end

FOUNDATION_EXPORT id<DBAirportAdapter> DBAirportAdapterForLocation(NSDictionary *location);
