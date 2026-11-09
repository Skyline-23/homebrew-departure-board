#import "Airports/AirportAdapter.h"
#import "DepartureBoardView.h"

static const NSTimeInterval DBFlapTransitionDuration = .66;

// Shared private state for the board's rendering categories.
// Timetable generation stays in DepartureSchedule; renderers only draw rows.
@interface DBBoardView ()
@property(nonatomic, strong) NSDictionary *location;
@property(nonatomic, strong) id<DBAirportAdapter> airportAdapter;
@property(nonatomic, strong) NSDictionary *loadedSettings;
@property(nonatomic) NSInteger currentPage;
@property(nonatomic, strong) NSArray *rows;
@property(nonatomic, copy) NSString *currentLanguage;
@property(nonatomic, copy) NSString *emptyMessageKey;
@property(nonatomic) NSTimeInterval startTime;
@property(nonatomic) NSTimeInterval lastRenderedSecond;
@property(nonatomic) NSInteger pageCycle;
@property(nonatomic) BOOL flapWasAnimating;
@property(nonatomic, strong) NSMutableDictionary *flapStates;
@property(nonatomic, strong) NSWindow *optionsWindow;
@property(nonatomic, strong) NSDate *boardDate;
- (NSString *)effectiveStyle;
- (BOOL)updateAtDate:(NSDate *)date uptime:(NSTimeInterval)uptime;
- (void)drawBoardInRect:(NSRect)bounds;
@end

@interface DBBoardView (BoardChrome)
- (void)planeAt:(NSPoint)point size:(CGFloat)size color:(NSColor *)color;
- (void)header:(NSRect)area compact:(BOOL)compact;
- (void)footer:(NSRect)area text:(NSString *)message;
@end

@interface DBBoardView (AirportRenderer)
- (DBAirportRenderContext *)airportRenderContext;
- (CGFloat)airportHeaderHeight:(NSRect)area;
- (NSInteger)airportRowCountForArea:(NSRect)area;
- (void)drawAirport:(NSRect)area;
@end

@interface DBBoardView (SplitFlapRenderer)
- (void)flapText:(NSString *)text
             key:(NSString *)key
            rect:(NSRect)rect
           cells:(NSInteger)cells
           color:(NSColor *)ink;
- (void)drawFlapBoard:(NSRect)area;
@end

@interface DBBoardView (RailwayRenderer)
- (void)drawRailTable:(NSRect)area;
- (void)drawRailCards:(NSRect)area;
@end
