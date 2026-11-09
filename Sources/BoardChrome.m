#import "BoardViewInternal.h"
#import "DrawingSupport.h"
#import "LiveFlightStore.h"

@implementation DBBoardView (BoardChrome)

- (void)planeAt:(NSPoint)point size:(CGFloat)size color:(NSColor *)color {
    DBDrawDepartureIcon(point, size, color);
}

- (void)header:(NSRect)area compact:(BOOL)compact {
    NSColor *white = DBColor(@"f6f7f4");
    BOOL light = [self.location[@"headerStyle"] isEqual:@"light"];
    NSColor *ink = light ? DBColor(@"111a20") : white;
    CGFloat height = compact ? 112 : 144;
    DBFillRect(NSMakeRect(0, 0, area.size.width, height), DBColor(self.location[@"header"]));
    [self.airportAdapter
        drawCompactHeaderDecorationInRect:NSMakeRect(0, 0, area.size.width, height)];
    [self planeAt:NSMakePoint(34, compact ? 30 : 42) size:52 color:ink];
    NSString *title =
        DBBoardString(self.location[@"titleKey"],
                      self.airportAdapter.compactTitleLanguage ?: self.currentLanguage);
    DBDrawText(title, NSMakeRect(106, compact ? 14 : 25, 990, 62), compact ? 42 : 48, ink, YES,
               NSTextAlignmentLeft, NO);
    NSString *sub = [NSString
        stringWithFormat:@"%@  /  %@", self.location[@"code"], self.location[@"subtitle"]];
    DBDrawText(sub, NSMakeRect(108, compact ? 72 : 94, 1070, 25), 17,
               [ink colorWithAlphaComponent:.78], NO, NSTextAlignmentLeft, NO);
    DBDrawText(DBTime(self.boardDate, self.location, @"HH:mm"),
               NSMakeRect(area.size.width - 306, compact ? 10 : 22, 270, 65), 57, ink, YES,
               NSTextAlignmentRight, YES);
    DBDrawText(DBTime(self.boardDate, self.location, @"EEE, dd MMM yyyy"),
               NSMakeRect(area.size.width - 325, compact ? 78 : 96, 289, 24), 17,
               [ink colorWithAlphaComponent:.8], NO, NSTextAlignmentRight, NO);
}

- (void)footer:(NSRect)area text:(NSString *)message {
    if (self.airportAdapter) {
        [self.airportAdapter drawFooterInBounds:area context:[self airportRenderContext]];
        return;
    }
    CGFloat height = 40;
    CGFloat y = area.size.height - height;
    DBFillRect(NSMakeRect(0, y, area.size.width, height), DBColor(@"080d13"));
    if (message.length) {
        DBDrawText(message, NSMakeRect(24, y + 2, 1450, height - 3), height * .57,
                   NSColor.whiteColor, NO, NSTextAlignmentLeft, NO);
    }
}

@end
