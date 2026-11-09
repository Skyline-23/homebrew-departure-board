#import "BoardViewInternal.h"
#import "DrawingSupport.h"

@implementation DBBoardView (BoardChrome)

- (void)drawFlapHeader:(NSRect)area {

    NSColor *white = DBColor(@"f6f7f4");
    BOOL light = [self.location[@"headerStyle"] isEqual:@"light"];
    NSColor *ink = light ? DBColor(@"111a20") : white;
    CGFloat height = 112;
    DBFillRect(NSMakeRect(0, 0, area.size.width, height), DBColor(self.location[@"header"]));
    [self.airportAdapter
        drawCompactHeaderDecorationInRect:NSMakeRect(0, 0, area.size.width, height)];
    DBDrawDepartureIcon(NSMakePoint(34, 30), 52, ink);
    NSString *title =
        DBBoardString(self.location[@"titleKey"],
                      self.airportAdapter.compactTitleLanguage ?: self.currentLanguage);
    DBDrawText(title, NSMakeRect(106, 14, 990, 62), 42, ink, YES, NSTextAlignmentLeft, NO);
    NSString *sub = [NSString
        stringWithFormat:@"%@  /  %@", self.location[@"code"], self.location[@"subtitle"]];
    DBDrawText(sub, NSMakeRect(108, 72, 1070, 25), 17, [ink colorWithAlphaComponent:.78], NO,
               NSTextAlignmentLeft, NO);
    DBDrawText(DBTime(self.boardDate, self.location, @"HH:mm"),
               NSMakeRect(area.size.width - 306, 10, 270, 65), 57, ink, YES, NSTextAlignmentRight,
               YES);
    DBDrawText(DBTime(self.boardDate, self.location, @"EEE, dd MMM yyyy"),
               NSMakeRect(area.size.width - 325, 78, 289, 24), 17, [ink colorWithAlphaComponent:.8],
               NO, NSTextAlignmentRight, NO);
}

- (void)drawAirportFooter:(NSRect)area {

    [self.airportAdapter drawFooterInBounds:area context:[self airportRenderContext]];
}

@end
