#import "BoardViewInternal.h"
#import "DrawingSupport.h"

@implementation DBBoardView (RailwayRenderer)

- (void)drawRailTable:(NSRect)area {

    BOOL seoul = [self.location[@"preset"] isEqual:@"seoul"];
    CGFloat horizontal = area.size.width / 1600;
    NSColor *accent = seoul ? DBColor(@"69b9ff") : DBColor(@"f3d74c");
    DBFillRect(NSMakeRect(0, 0, area.size.width, 140), DBColor(self.location[@"header"]));
    DBDrawText(DBBoardString(@"heading.train", self.currentLanguage),
               NSMakeRect(35 * horizontal, 23, 1060 * horizontal, 63), 48, NSColor.whiteColor, YES,
               NSTextAlignmentLeft, NO);
    DBDrawText(self.location[@"subtitle"], NSMakeRect(37 * horizontal, 90, 1050 * horizontal, 27),
               19, accent, YES, NSTextAlignmentLeft, NO);
    DBDrawText(DBTime(self.boardDate, self.location, @"HH:mm"),
               NSMakeRect(1240 * horizontal, 29, 318 * horizontal, 63), 58, NSColor.whiteColor, YES,
               NSTextAlignmentRight, YES);
    NSArray *names = @[
        DBBoardString(@"column.train", self.currentLanguage),
        DBBoardString(@"column.number", self.currentLanguage),
        DBBoardString(@"column.destination", self.currentLanguage),
        DBBoardString(@"column.time", self.currentLanguage),
        DBBoardString(@"column.platform", self.currentLanguage),
        DBBoardString(@"column.state", self.currentLanguage)
    ];
    CGFloat x[] = {34, 280, 386, 942, 1111, 1260};
    CGFloat widths[] = {230, 94, 540, 151, 131, 302};
    for (NSInteger index = 0; index < 6; index++) {

        x[index] *= horizontal;
        widths[index] *= horizontal;
    }
    for (int j = 0; j < 6; j++) {

        DBDrawText(names[j], NSMakeRect(x[j], 153, widths[j], 32), 20, accent, YES,
                   NSTextAlignmentLeft, NO);
    }
    NSInteger count =
        self.density > 0 ? MAX(5, MIN(10, self.density - 3)) : (NSInteger)ceil(9 / self.boardScale);
    CGFloat rowH = (area.size.height - 246) / count;
    for (NSInteger i = 0; i < count; i++) {

        if ((NSUInteger)i >= self.rows.count) {

            break;
        }
        NSDictionary *row = self.rows[i];
        CGFloat y = 198 + i * rowH;
        DBFillRect(NSMakeRect(28 * horizontal, y, area.size.width - 62 * horizontal, rowH - 4),
                   seoul ? DBColor(i % 2 ? @"152d53" : @"102443")
                         : DBColor(i % 2 ? @"171f22" : @"10171b"));
        DBFillRect(NSMakeRect(x[0] + 5, y + 12, widths[0] - 14, rowH - 30), DBColor(row[@"color"]));
        DBDrawText(DBLocalized(row[@"service"], self.currentLanguage),
                   NSMakeRect(x[0] + 10, y + 8, widths[0] - 25, rowH - 22), MIN(26, rowH * .35),
                   NSColor.whiteColor, YES, NSTextAlignmentCenter, NO);
        DBDrawText(row[@"flight"], NSMakeRect(x[1], y + 6, widths[1], rowH - 15), 28,
                   DBColor(@"d8e0e8"), YES, NSTextAlignmentLeft, YES);
        DBDrawText(DBLocalized(row[@"destination"], self.currentLanguage),
                   NSMakeRect(x[2], y + 3, widths[2] - 6, rowH * .55), MIN(35, rowH * .43),
                   seoul ? NSColor.whiteColor : DBColor(@"8deb9f"), YES, NSTextAlignmentLeft, NO);
        NSString *stops = DBLocalized(row[@"stops"], self.currentLanguage);
        DBDrawText(stops, NSMakeRect(x[2] + 1, y + rowH * .57, widths[2] - 14, rowH * .28),
                   MIN(16, rowH * .23), DBColor(@"93a8bb"), NO, NSTextAlignmentLeft, NO);
        DBDrawText(row[@"time"], NSMakeRect(x[3], y, widths[3], rowH - 8), 34, DBColor(@"ffdf56"),
                   YES, NSTextAlignmentLeft, YES);
        DBDrawText(row[@"gate"], NSMakeRect(x[4], y, widths[4] - 15, rowH - 8), 38,
                   NSColor.whiteColor, YES, NSTextAlignmentCenter, YES);
        NSString *state = DBStatusText(row[@"state"], self.currentLanguage);
        DBDrawText(state, NSMakeRect(x[5], y, widths[5] - 8, rowH - 8), 25,
                   DBStatusColor(row[@"state"]), YES, NSTextAlignmentLeft, NO);
    }
    [self footer:area text:DBBoardString(@"footer.rail", self.currentLanguage)];
}

- (void)drawRailCards:(NSRect)area {

    BOOL sydney = [self.location[@"preset"] isEqual:@"sydney"];
    CGFloat horizontal = area.size.width / 1600;
    NSColor *amber = DBColor(@"ffcc49");
    DBFillRect(NSMakeRect(0, 0, area.size.width, 127), DBColor(@"11191c"));
    DBDrawText(sydney ? @"Central" : @"London Victoria",
               NSMakeRect(34 * horizontal, 24, 1100 * horizontal, 58), 46, NSColor.whiteColor, YES,
               NSTextAlignmentLeft, NO);
    DBDrawText(sydney ? @"Next services · Sydney Trains & Metro"
                      : @"Departures · Southern services",
               NSMakeRect(36 * horizontal, 88, 1070 * horizontal, 24), 20,
               sydney ? DBColor(@"ef9433") : amber, NO, NSTextAlignmentLeft, NO);
    DBDrawText(DBTime(self.boardDate, self.location, @"HH:mm:ss"),
               NSMakeRect(1220 * horizontal, 24, 338 * horizontal, 65), 45, NSColor.whiteColor, YES,
               NSTextAlignmentRight, YES);
    NSInteger n = 5;
    CGFloat margin = 34 * horizontal, gap = 12 * horizontal;
    CGFloat cw = (area.size.width - 2 * margin - gap * (n - 1)) / n, top = 146;
    for (NSInteger i = 0; i < n; i++) {

        if ((NSUInteger)(i + 1) >= self.rows.count) {

            break;
        }
        NSDictionary *row = self.rows[i + 1];
        CGFloat x = margin + i * (cw + gap), height = area.size.height - top - 58;
        NSRect card = NSMakeRect(x, top, cw, height);
        DBFillRect(card, DBColor(sydney ? @"151b20" : @"101516"));
        NSColor *ink = sydney ? NSColor.whiteColor : amber;
        if (sydney) {

            DBFillRect(NSMakeRect(x, top, cw, 52), DBColor(row[@"color"]));
            DBDrawText(DBLocalized(row[@"service"], @"en"),
                       NSMakeRect(x + 13, top + 6, cw - 26, 40), 26, NSColor.whiteColor, YES,
                       NSTextAlignmentLeft, NO);
            DBDrawText([NSString stringWithFormat:@"%ld min", (long)[row[@"minutes"] integerValue]],
                       NSMakeRect(x + 14, top + 70, cw - 28, 58), 42, NSColor.whiteColor, YES,
                       NSTextAlignmentLeft, YES);
        } else {

            DBFillRect(NSMakeRect(x, top, cw, 4), amber);
            DBDrawText(row[@"time"], NSMakeRect(x + 15, top + 18, cw - 30, 61), 48, amber, YES,
                       NSTextAlignmentLeft, YES);
        }
        CGFloat destY = top + (sydney ? 136 : 92);
        DBDrawText(DBLocalized(row[@"destination"], @"en"), NSMakeRect(x + 14, destY, cw - 28, 86),
                   32, ink, YES, NSTextAlignmentLeft, NO);
        CGFloat platformY = destY + 104;
        DBDrawText(sydney ? @"Platform"
                          : ([row[@"minutes"] integerValue] > 10 ? @"Please wait" : @"Platform"),
                   NSMakeRect(x + 15, platformY, cw - 30, 32), 22, ink, YES, NSTextAlignmentLeft,
                   NO);
        DBDrawText([row[@"minutes"] integerValue] > 10 && !sydney ? @"—" : row[@"gate"],
                   NSMakeRect(x + 15, platformY + 35, cw - 30, 68), 56, ink, YES,
                   NSTextAlignmentLeft, YES);
        DBFillRect(NSMakeRect(x + 14, platformY + 114, cw - 28, 1),
                   [ink colorWithAlphaComponent:.30]);
        DBDrawText(@"Calling at", NSMakeRect(x + 14, platformY + 129, cw - 28, 30), 17,
                   [ink colorWithAlphaComponent:.72], YES, NSTextAlignmentLeft, NO);
        NSArray *stops = [DBLocalized(row[@"stops"], @"en") componentsSeparatedByString:@" · "];
        CGFloat sy = platformY + 170;
        for (NSString *stop in stops) {

            if (sy + 29 > top + height - 48) {

                break;
            }
            DBDrawText(stop, NSMakeRect(x + 15, sy, cw - 29, 31), 21, ink, NO, NSTextAlignmentLeft,
                       NO);
            sy += 40;
        }
        DBDrawText(sydney ? @"All stops" : @"8 coaches",
                   NSMakeRect(x + 15, top + height - 39, cw - 30, 26), 17,
                   [ink colorWithAlphaComponent:.6], NO, NSTextAlignmentLeft, NO);
    }
    [self
        footer:area
          text:sydney ? @"Stand behind the yellow line. Let passengers leave the train first."
                      : @"Please keep your luggage and personal belongings with you at all times."];
}

@end
