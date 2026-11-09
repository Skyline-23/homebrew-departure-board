#import "BoardViewInternal.h"
#import "DrawingSupport.h"
#import "LiveFlightStore.h"
#import <CoreText/CoreText.h>

@implementation DBBoardView (BoardChrome)

- (void)planeAt:(NSPoint)p size:(CGFloat)s color:(NSColor *)color {
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *t = NSAffineTransform.transform;
    [t translateXBy:p.x yBy:p.y];
    [t scaleBy:s / 44];
    [t concat];
    NSBezierPath *path = NSBezierPath.bezierPath;
    [path moveToPoint:NSMakePoint(1, 24)];
    [path lineToPoint:NSMakePoint(4, 20)];
    [path lineToPoint:NSMakePoint(19, 23)];
    [path lineToPoint:NSMakePoint(31, 5)];
    [path lineToPoint:NSMakePoint(37, 4)];
    [path lineToPoint:NSMakePoint(30, 25)];
    [path lineToPoint:NSMakePoint(42, 27)];
    [path curveToPoint:NSMakePoint(39, 33)
         controlPoint1:NSMakePoint(47, 28)
         controlPoint2:NSMakePoint(45, 32)];
    [path lineToPoint:NSMakePoint(24, 31)];
    [path lineToPoint:NSMakePoint(16, 42)];
    [path lineToPoint:NSMakePoint(10, 42)];
    [path lineToPoint:NSMakePoint(15, 29)];
    [path closePath];
    [color setFill];
    [path fill];
    [NSGraphicsContext restoreGraphicsState];
}

- (void)header:(NSRect)area compact:(BOOL)compact {
    NSString *preset = self.location[@"preset"];
    NSColor *accent = DBColor(self.location[@"accent"]), *white = DBColor(@"f6f7f4");
    BOOL light = [self.location[@"headerStyle"] isEqual:@"light"];
    NSColor *ink = light ? DBColor(@"111a20") : white;
    CGFloat height = compact ? 112 : 144;
    DBFillRect(NSMakeRect(0, 0, area.size.width, height), DBColor(self.location[@"header"]));
    if ([preset isEqual:@"icn"])
        DBFillRect(NSMakeRect(0, height - 4, area.size.width, 4), DBColor(@"4883ba"));
    if ([preset isEqual:@"narita"])
        DBFillRect(NSMakeRect(0, 0, 12, height), DBColor(@"60a77d"));
    if ([preset isEqual:@"haneda"])
        DBFillRect(NSMakeRect(0, height - 6, area.size.width, 6), DBColor(@"68d6e5"));
    [self planeAt:NSMakePoint(34, compact ? 30 : 42) size:52 color:ink];
    NSString *title = DBBoardString(self.location[@"titleKey"], self.currentLanguage);
    if ([preset isEqual:@"heathrow"])
        title = @"Departures";
    DBDrawText(title, NSMakeRect(106, compact ? 14 : 25, 990, 62), compact ? 42 : 48, ink, YES,
               NSTextAlignmentLeft, NO);
    NSString *sub =
        [NSString stringWithFormat:@"%@  /  %@", self.location[@"code"], self.location[@"subtitle"]];
    DBDrawText(sub, NSMakeRect(108, compact ? 72 : 94, 1070, 25), 17, [ink colorWithAlphaComponent:.78], NO,
               NSTextAlignmentLeft, NO);
    DBDrawText(DBTime(self.boardDate, self.location, @"HH:mm"),
               NSMakeRect(area.size.width - 306, compact ? 10 : 22, 270, 65), 57, ink, YES,
               NSTextAlignmentRight, YES);
    DBDrawText(DBTime(self.boardDate, self.location, @"EEE, dd MMM yyyy"),
               NSMakeRect(area.size.width - 325, compact ? 78 : 96, 289, 24), 17,
               [ink colorWithAlphaComponent:.8], NO, NSTextAlignmentRight, NO);
    (void)accent;
}

- (void)footer:(NSRect)area text:(NSString *)message {
    CGFloat y = area.size.height - 40;
    DBFillRect(NSMakeRect(0, y, area.size.width, 40), DBColor(@"080d13"));
    DBDrawText(message, NSMakeRect(32, y + 3, 1130, 34), 15, DBColor(@"aabcc9"), NO, NSTextAlignmentLeft, NO);
    NSString *dataLabel = DBUIString(@"footer.simulated");
    if (!self.referenceDate && !self.useSampleData) {
        NSDictionary *snapshot = [LiveFlightStore cachedSnapshotForAirport:self.locationCode];
        dataLabel =
            snapshot && self.rows.count
                ? [NSString stringWithFormat:@"AeroDataBox · %@ · %@",
                                             [snapshot[@"stale"] boolValue] ? DBUIString(@"data.cached")
                                                                            : DBUIString(@"data.retrieved"),
                                             snapshot[@"fetchedAt"] ?: @""]
                : DBUIString(@"data.unavailable");
    }
    DBDrawText(dataLabel, NSMakeRect(area.size.width - 433, y + 3, 400, 34), 13, DBColor(@"78909f"), YES,
               NSTextAlignmentRight, NO);
}

@end
