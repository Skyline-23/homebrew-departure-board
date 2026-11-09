#import "BoardViewInternal.h"
#import "DrawingSupport.h"

@implementation DBBoardView (AirportRenderer)

- (NSArray *)airportColumns {
    return self.location[@"columns"] ?: @[ @"time", @"flight", @"destination", @"gate", @"state" ];
}

- (CGFloat)weightFor:(NSString *)column {
    NSDictionary *weights = self.location[@"display"][@"columnWeights"];
    if (weights[column])
        return [weights[column] doubleValue];
    NSDictionary *defaults = @{
        @"time" : @.13,
        @"flight" : @.21,
        @"destination" : @.30,
        @"expected" : @.12,
        @"gate" : @.08,
        @"state" : @.22
    };
    return [defaults[column] doubleValue];
}

- (NSString *)columnLabel:(NSString *)column {
    return DBBoardString([@"column." stringByAppendingString:column], self.currentLanguage);
}

- (void)drawAirportHeader:(NSRect)area {
    NSDictionary *profile = self.location[@"display"];
    CGFloat height = [profile[@"headerHeight"] doubleValue];
    NSColor *ink = DBColor(profile[@"headerInk"]);
    DBFillRect(NSMakeRect(0, 0, area.size.width, height), DBColor(self.location[@"header"]));
    BOOL haneda = [self.locationCode isEqual:@"HND"];
    CGFloat titleHeight = haneda ? 76 : height;
    CGFloat fontSize = MIN(44, titleHeight * .42);
    [self planeAt:NSMakePoint(26, titleHeight * .22) size:40 color:ink];
    DBDrawText(DBBoardString(self.location[@"titleKey"], self.currentLanguage),
               NSMakeRect(86, 7, 710, titleHeight * .59), fontSize, ink, YES, NSTextAlignmentLeft, NO);
    DBDrawText(self.location[@"subtitle"], NSMakeRect(88, titleHeight * .64, 920, 24), 15,
               [ink colorWithAlphaComponent:.84], NO, NSTextAlignmentLeft, NO);
    DBDrawText(DBTime(self.boardDate, self.location, @"HH:mm"),
               NSMakeRect(area.size.width - 265, 5, 233, titleHeight * .63), fontSize, ink, YES,
               NSTextAlignmentRight, YES);
    DBDrawText(DBTime(self.boardDate, self.location, @"dd MMM yyyy"),
               NSMakeRect(area.size.width - 255, titleHeight * .65, 223, 22), 15, ink, NO,
               NSTextAlignmentRight, NO);
    if (haneda)
        [self drawHanedaCounters:NSMakeRect(25, 87, area.size.width - 50, height - 98)];
}

- (void)drawHanedaCounters:(NSRect)area {
    // Terminal 3 has a check-in-area diagram above the flight list.
    // It is a separate layout element, not an airport-colour override.
    DBFillRect(area, DBColor(@"17334d"));
    DBDrawText(DBBoardString(@"column.counter", self.currentLanguage),
               NSMakeRect(area.origin.x + 14, area.origin.y + 4, 320, 28), 19, NSColor.whiteColor, YES,
               NSTextAlignmentLeft, NO);
    NSString *letters = @"ABCDEFGHIJKLMNOP";
    CGFloat columnWidth = (area.size.width - 36) / letters.length;
    for (NSUInteger index = 0; index < letters.length; index++) {
        NSRect counter =
            NSMakeRect(area.origin.x + 18 + index * columnWidth, area.origin.y + 43, columnWidth - 9, 65);
        DBFillRect(counter, DBColor(@"dce6ee"));
        DBDrawText([letters substringWithRange:NSMakeRange(index, 1)], counter, 26, DBColor(@"17334d"), YES,
                   NSTextAlignmentCenter, NO);
    }
}

- (void)drawAirport:(NSRect)area {
    NSDictionary *profile = self.location[@"display"];
    [self drawAirportHeader:area];
    NSInteger panels = MAX(1, [profile[@"panelCount"] integerValue]);
    if (area.size.height > 1100)
        panels = MIN(2, panels);
    NSInteger rowCount = self.density > 0 ? self.density : [profile[@"rowCount"] integerValue];
    rowCount = MAX(8, MIN(32, rowCount));
    CGFloat panelGap = panels > 1 ? 12 : 0;
    CGFloat margin = 20;
    CGFloat panelWidth = (area.size.width - 2 * margin - panelGap * (panels - 1)) / panels;
    CGFloat headingY = [profile[@"headerHeight"] doubleValue] + 9;
    CGFloat tableY = headingY + 29;
    CGFloat tableBottom = area.size.height - 43;
    CGFloat rowHeight = (tableBottom - tableY) / rowCount;
    CGFloat fontSize = MIN(27, MIN(rowHeight * .69, panelWidth / 34));
    NSArray *columns = [self airportColumns];
    CGFloat totalWeight = 0;
    for (NSString *column in columns)
        totalWeight += [self weightFor:column];

    for (NSInteger panel = 0; panel < panels; panel++) {
        CGFloat left = margin + panel * (panelWidth + panelGap);
        DBFillRect(NSMakeRect(left, headingY, panelWidth, 26), DBColor(profile[@"columnBand"]));
        CGFloat columnX = left;
        for (NSString *column in columns) {
            CGFloat width = panelWidth * [self weightFor:column] / totalWeight;
            DBDrawText([self columnLabel:column], NSMakeRect(columnX + 5, headingY, width - 8, 26),
                       MIN(16, panelWidth / 37), DBColor(profile[@"columnInk"]), YES, NSTextAlignmentLeft,
                       NO);
            columnX += width;
        }
        for (NSInteger index = 0; index < rowCount; index++) {
            NSUInteger rowIndex = (NSUInteger)(index + panel * rowCount);
            if (rowIndex >= self.rows.count)
                break;
            NSDictionary *row = self.rows[rowIndex];
            CGFloat top = tableY + index * rowHeight;
            NSArray *rowColors = profile[@"rowColors"];
            DBFillRect(NSMakeRect(left, top, panelWidth, rowHeight - 1), DBColor(rowColors[index % 2]));
            columnX = left;
            for (NSString *column in columns) {
                CGFloat width = panelWidth * [self weightFor:column] / totalWeight;
                NSRect cell = NSMakeRect(columnX + 5, top + 1, width - 9, rowHeight - 3);
                [self drawAirportCell:row column:column rect:cell fontSize:fontSize];
                columnX += width;
            }
        }
    }
    if (!self.rows.count) {
        DBDrawText(DBUIString(@"data.unavailable"), NSMakeRect(100, tableY + 70, area.size.width - 200, 80),
                   26, DBColor(@"b9c9d4"), NO, NSTextAlignmentCenter, NO);
    }
    [self footer:area text:DBBoardString(@"footer.airport", self.currentLanguage)];
}

- (void)drawAirportCell:(NSDictionary *)row
                 column:(NSString *)column
                   rect:(NSRect)cell
               fontSize:(CGFloat)size {
    NSDictionary *profile = self.location[@"display"];
    NSString *value = row[column] ?: @"";
    NSColor *ink = DBColor(profile[@"textColor"]);
    BOOL numbers = [@[ @"time", @"expected", @"gate", @"flight" ] containsObject:column];
    if ([column isEqual:@"destination"]) {
        value = DBLocalized(row[@"destination"], self.currentLanguage);
    } else if ([column isEqual:@"state"]) {
        value = DBStatusText(row[@"state"], self.currentLanguage);
        if (![@[ @"scheduled", @"departed" ] containsObject:row[@"state"]])
            ink = DBStatusColor(row[@"state"]);
        size *= .88;
    } else if ([column isEqual:@"time"]) {
        ink = DBColor(profile[@"timeColor"]);
    } else if ([column isEqual:@"expected"]) {
        ink = DBColor(@"ffd653");
    }

    if ([column isEqual:@"flight"] && [profile[@"airlineBadge"] boolValue]) {
        CGFloat badgeWidth = MIN(29, cell.size.height * 1.15);
        NSRect badge = NSMakeRect(cell.origin.x, cell.origin.y + 2, badgeWidth, cell.size.height - 4);
        NSString *carrier = [row[@"flight"] componentsSeparatedByString:@" "].firstObject;
        static NSMutableDictionary *logos;
        if (!logos)
            logos = NSMutableDictionary.new;
        NSImage *logo = logos[carrier];
        if (!logo && carrier.length) {
            NSURL *asset = [[NSBundle bundleForClass:self.class] URLForResource:carrier
                                                                  withExtension:@"png"
                                                                   subdirectory:@"AirlineLogos"];
            logo = asset ? [[NSImage alloc] initWithContentsOfURL:asset] : nil;
            if (logo)
                logos[carrier] = logo;
        }
        if (logo) {
            DBFillRect(badge, NSColor.whiteColor);
            [logo drawInRect:badge
                      fromRect:NSZeroRect
                     operation:NSCompositingOperationSourceOver
                      fraction:1
                respectFlipped:YES
                         hints:nil];
        } else {
            DBFillRect(badge, DBColor(row[@"color"]));
            DBDrawText(carrier, badge, size * .54, NSColor.whiteColor, YES, NSTextAlignmentCenter, NO);
        }
        cell.origin.x += badgeWidth + 5;
        cell.size.width -= badgeWidth + 5;
    }
    if ([column isEqual:@"gate"] && [profile[@"gateHighlight"] boolValue]) {
        DBFillRect(NSInsetRect(cell, 1, 1), DBColor(@"f4ec7b"));
        ink = DBColor(@"17221a");
    }
    // Numeric fields must stay complete: a truncated boarding time is misleading.
    if (numbers)
        size = MIN(size, cell.size.width / MAX(2.6, value.length * .60));
    DBDrawText(value, cell, size, ink, YES, NSTextAlignmentLeft, numbers);
}

@end
