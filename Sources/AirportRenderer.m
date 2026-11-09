#import "BoardViewInternal.h"
#import "DrawingSupport.h"

static NSImage *AirportAirlineLogo(NSString *carrier) {
    static NSCache *logos;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        logos = NSCache.new;
    });
    id cached = [logos objectForKey:carrier];
    if (cached)
        return cached == NSNull.null ? nil : cached;
    NSImage *logo = nil;
    if (carrier.length) {
        NSURL *url = [[NSBundle bundleForClass:DBBoardView.class] URLForResource:carrier
                                                                   withExtension:@"png"
                                                                    subdirectory:@"AirlineLogos"];
        logo = url ? [[NSImage alloc] initWithContentsOfURL:url] : nil;
        [logos setObject:logo ?: NSNull.null forKey:carrier];
    }
    return logo;
}

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
- (CGFloat)airportHeaderHeight:(NSRect)area {
    CGFloat fraction = [self.location[@"display"][@"headerFraction"] doubleValue];
    if ([self.locationCode isEqual:@"HND"] && area.size.width > area.size.height)
        return 90;
    if (self.density == 0 && [self.locationCode isEqual:@"ICN"] && area.size.width > area.size.height)
        return MAX(230, area.size.height * fraction);
    return fraction > 0 ? area.size.height * fraction
                        : [self.location[@"display"][@"headerHeight"] doubleValue];
}

- (void)drawAirportHeader:(NSRect)area {
    NSDictionary *profile = self.location[@"display"];
    CGFloat height = [self airportHeaderHeight:area];
    NSColor *ink = DBColor(profile[@"headerInk"]);
    DBFillRect(NSMakeRect(0, 0, area.size.width, height), DBColor(self.location[@"header"]));
    BOOL haneda = [self.locationCode isEqual:@"HND"];
    if ([self.locationCode isEqual:@"ICN"]) {
        NSBezierPath *box = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(65, 28, 174, 178)
                                                            xRadius:8
                                                            yRadius:8];
        [ink setStroke];
        box.lineWidth = 5;
        [box stroke];
        [self planeAt:NSMakePoint(90, 52) size:124 color:ink];
        DBFillRect(NSMakeRect(99, 182, 105, 5), ink);
        DBDrawTextWithFont(DBBoardString(@"heading.departures", @"ko"), NSMakeRect(290, 20, 230, height - 36),
                           DBNamedFont(@"AppleSDGothicNeo-Bold", height * .47), ink, NSTextAlignmentLeft);
        NSString *asian = [NSString stringWithFormat:@"%@  %@", DBBoardString(@"heading.departures", @"ja"),
                                                     DBBoardString(@"heading.departures", @"zh-Hans")];
        DBDrawTextWithFont(asian, NSMakeRect(550, 16, 760, height * .43),
                           DBNamedFont(@"Arial-BoldMT", height * .27), ink, NSTextAlignmentLeft);
        DBFillRect(NSMakeRect(550, height * .46, 490, 5), ink);
        DBDrawTextWithFont(DBBoardString(@"heading.departures", @"en"),
                           NSMakeRect(550, height * .48, 820, height * .37),
                           DBNamedFont(@"Arial-BoldMT", height * .29), ink, NSTextAlignmentLeft);
        return;
    }
    if (haneda) {
        CGFloat unit = area.size.width / 800;
        if (area.size.height > area.size.width) {
            DBDrawText(DBBoardString(@"heading.checkinInformation", self.currentLanguage),
                       NSMakeRect(26, 3, 1400, 30 * unit), 23 * unit, ink, YES, NSTextAlignmentLeft, NO);
            [self drawHanedaCounters:NSMakeRect(24, 38 * unit, area.size.width - 48, height - 93 * unit)];
        }
        DBFillRect(NSMakeRect(0, height - 45 * unit, area.size.width, 45 * unit), NSColor.blackColor);
        DBFillRect(NSMakeRect(0, height - 3, area.size.width, 3), DBColor(@"8dd856"));
        [self planeAt:NSMakePoint(25, height - 38 * unit) size:30 * unit color:DBColor(@"a9e482")];
        DBDrawText(DBBoardString(@"heading.departures", self.currentLanguage),
                   NSMakeRect(68 * unit, height - 42 * unit, 1000, 37 * unit), 28 * unit, ink, YES,
                   NSTextAlignmentLeft, NO);
        DBDrawText(DBTime(self.boardDate, self.location, @"HH:mm"),
                   NSMakeRect(area.size.width - 190 * unit, height - 42 * unit, 164 * unit, 37 * unit),
                   28 * unit, DBColor(@"a9e482"), YES, NSTextAlignmentRight, YES);
        return;
    }
    CGFloat titleHeight = haneda ? 76 : height;
    CGFloat fontSize = MIN(88, titleHeight * .56);
    [self planeAt:NSMakePoint(26, titleHeight * .22) size:40 color:ink];
    NSString *title = DBBoardString(self.location[@"titleKey"], self.currentLanguage);
    BOOL bilingual =
        [profile[@"headerVariant"] isEqual:@"bilingual"] && ![self.location[@"lang"] isEqual:@"en"];
    BOOL centered = [profile[@"headerVariant"] isEqual:@"centered"];
    DBDrawTextWithFont(title, NSMakeRect(86, 4, area.size.width - 375, titleHeight * (bilingual ? .58 : .90)),
                       DBNamedFont(profile[@"headerFont"], fontSize), ink,
                       centered ? NSTextAlignmentCenter : NSTextAlignmentLeft);
    if (bilingual) {
        NSString *secondary =
            DBBoardString(self.location[@"titleKey"],
                          [self.currentLanguage isEqual:@"en"] ? self.location[@"lang"] : @"en");
        DBDrawTextWithFont(secondary,
                           NSMakeRect(88, titleHeight * .58, area.size.width - 375, titleHeight * .36),
                           DBNamedFont(profile[@"headerFont"], fontSize * .6), ink, NSTextAlignmentLeft);
    }
    if (![self.locationCode isEqual:@"ICN"])
        DBDrawText(DBTime(self.boardDate, self.location, @"HH:mm"),
                   NSMakeRect(area.size.width - 265, 5, 233, titleHeight * .63), fontSize, ink, YES,
                   NSTextAlignmentRight, YES);
}

- (void)drawHanedaCounters:(NSRect)area {
    DBFillRect(area, DBColor(@"233957"));
    NSArray *counters =
        @[ @"N", @"M", @"L", @"K", @"J", @"I", @"H", @"G", @"F", @"", @"E", @"D", @"C", @"B", @"A" ];
    CGFloat width = (area.size.width - 24) / counters.count;
    CGFloat unit = area.size.width / 800;
    for (NSUInteger index = 0; index < counters.count; index++) {
        NSString *letter = counters[index];
        if (!letter.length)
            continue;
        CGFloat x = area.origin.x + 12 + index * width;
        CGFloat top = area.origin.y + area.size.height * .25;
        CGFloat cardHeight = area.size.height * .57;
        DBFillRect(NSMakeRect(x, top, width - 6, cardHeight), DBColor(@"d8e5eb"));
        DBFillRect(NSMakeRect(x, top + cardHeight * .43, width - 6, 2), DBColor(@"386495"));
        NSMutableOrderedSet *carriers = NSMutableOrderedSet.new;
        for (NSDictionary *row in self.rows) {
            NSString *counter = row[@"counter"];
            if (!counter.length || [counter rangeOfString:letter].location == NSNotFound)
                continue;
            NSString *number = row[@"operatorFlight"] ?: row[@"flight"];
            if (number.length >= 2)
                [carriers addObject:[number substringToIndex:2]];
        }
        NSInteger logoIndex = 0;
        for (NSString *carrier in carriers) {
            NSImage *logo = AirportAirlineLogo(carrier);
            if (!logo || logoIndex >= 2)
                continue;
            CGFloat size = MIN(width - 14, (cardHeight - 32 * unit) / 2);
            NSRect rect = NSMakeRect(x + (width - size) / 2 - 3, top + 4 + logoIndex * size, size, size);
            [logo drawInRect:rect
                      fromRect:NSZeroRect
                     operation:NSCompositingOperationSourceOver
                      fraction:1
                respectFlipped:YES
                         hints:nil];
            logoIndex++;
        }
        DBFillRect(NSMakeRect(x, top + cardHeight - 28 * unit, width - 6, 28 * unit), DBColor(@"bcd3e2"));
        DBDrawText(letter, NSMakeRect(x, top + cardHeight - 27 * unit, width - 6, 27 * unit), 23 * unit,
                   DBColor(@"101d2d"), YES, NSTextAlignmentCenter, NO);
    }
    DBDrawText(DBBoardString(@"heading.securityNorth", self.currentLanguage),
               NSMakeRect(area.origin.x + width * 2, area.origin.y + 2, width * 4, 27 * unit), 17 * unit,
               NSColor.whiteColor, YES, NSTextAlignmentCenter, NO);
    DBDrawText(DBBoardString(@"heading.securityCentral", self.currentLanguage),
               NSMakeRect(area.origin.x + width * 8, area.origin.y + 2, width * 5, 27 * unit), 17 * unit,
               NSColor.whiteColor, YES, NSTextAlignmentCenter, NO);
}

- (void)drawAirport:(NSRect)area {
    NSDictionary *profile = self.location[@"display"];
    [self drawAirportHeader:area];
    // A physical display gets one panel. Long reference walls are cropped to
    // that panel instead of being shrunk or repeated across the desktop.
    NSInteger panels = self.density == 0 ? 1 : MAX(1, [profile[@"panelCount"] integerValue]);
    if (area.size.height > area.size.width)
        panels = 1;
    NSInteger rowCount = self.density > 0 ? self.density : [profile[@"rowCount"] integerValue];
    if (self.density == 0) {
        CGFloat referenceAspect = [profile[@"referenceAspect"] doubleValue];
        NSInteger referencePanels = MAX(1, [profile[@"panelCount"] integerValue]);
        if (referenceAspect > 0) {
            CGFloat visibleFraction =
                referenceAspect / referencePanels / (area.size.width / area.size.height);
            rowCount = MIN(rowCount, (NSInteger)ceil(rowCount * visibleFraction));
        }
    }
    rowCount = MAX(8, MIN(64, rowCount));
    NSInteger pages = MAX(1, (self.rows.count + rowCount * panels - 1) / (rowCount * panels));
    self.currentPage = (NSInteger)((NSProcessInfo.processInfo.systemUptime - self.startTime) / 15) % pages;
    self.currentPanelCount = panels;
    CGFloat panelGap = panels > 1 ? 12 : 0;
    CGFloat margin = 20;
    CGFloat panelWidth = (area.size.width - 2 * margin - panelGap * (panels - 1)) / panels;
    CGFloat headingY = [self airportHeaderHeight:area] + 4;
    CGFloat tableY = headingY + 29;
    CGFloat tableBottom = area.size.height - MAX(29, [profile[@"footerHeight"] doubleValue] + 3);
    CGFloat rowHeight = (tableBottom - tableY) / rowCount;
    CGFloat fontSize = MIN(48, MIN(rowHeight * .78, panelWidth / 34));
    if (profile[@"rowFontScale"])
        fontSize *= [profile[@"rowFontScale"] doubleValue];
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
            DBDrawTextWithFont([self columnLabel:column], NSMakeRect(columnX + 5, headingY, width - 8, 26),
                               DBNamedFont(profile[@"bodyFont"], MIN(24, panelWidth / 37)),
                               DBColor(profile[@"columnInk"]), NSTextAlignmentLeft);
            columnX += width;
        }
        for (NSInteger index = 0; index < rowCount; index++) {
            NSUInteger rowIndex =
                (NSUInteger)(self.currentPage * rowCount * panels + index + panel * rowCount);
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
        if ([profile[@"uppercaseDestinations"] boolValue])
            value = value.uppercaseString;
    } else if ([column isEqual:@"state"]) {
        value = DBStatusText(row[@"state"], self.currentLanguage);
        if ([profile[@"hideScheduledStatus"] boolValue] && [row[@"state"] isEqual:@"scheduled"])
            value = @"";
        if (![@[ @"scheduled", @"departed" ] containsObject:row[@"state"]])
            ink = DBStatusColor(row[@"state"]);
        size *= .88;
    } else if ([column isEqual:@"time"]) {
        ink = DBColor(profile[@"timeColor"]);
    } else if ([column isEqual:@"expected"]) {
        ink = DBColor(@"ffd653");
    }

    if ([column isEqual:@"flight"] && [profile[@"airlineBadge"] boolValue]) {
        CGFloat badgeWidth = MIN(54, cell.size.height - 4);
        NSRect badge = NSMakeRect(cell.origin.x, cell.origin.y + (cell.size.height - badgeWidth) / 2,
                                  badgeWidth, badgeWidth);
        NSString *carrier = [row[@"flight"] componentsSeparatedByString:@" "].firstObject;
        NSImage *logo = AirportAirlineLogo(carrier);
        if (logo) {
            DBFillRect(badge, NSColor.whiteColor);
            CGFloat scale = MIN(badge.size.width / logo.size.width, badge.size.height / logo.size.height);
            NSRect imageRect = NSMakeRect(NSMidX(badge) - logo.size.width * scale / 2,
                                          NSMidY(badge) - logo.size.height * scale / 2,
                                          logo.size.width * scale, logo.size.height * scale);
            [logo drawInRect:imageRect
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
    DBDrawTextWithFont(value, cell, DBNamedFont(profile[@"bodyFont"], size), ink, NSTextAlignmentLeft);
}

@end
