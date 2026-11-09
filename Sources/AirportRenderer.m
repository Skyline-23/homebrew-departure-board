#import "BoardViewInternal.h"
#import "DrawingSupport.h"
#import "AirlineLogoStore.h"

static void DrawAirlineLogo(NSImage *logo, NSRect bounds) {
    CGFloat scale = MIN(bounds.size.width / logo.size.width, bounds.size.height / logo.size.height);
    NSRect rect = NSMakeRect(NSMidX(bounds) - logo.size.width * scale / 2,
                             NSMidY(bounds) - logo.size.height * scale / 2,
                             logo.size.width * scale, logo.size.height * scale);
    [logo drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver
           fraction:1 respectFlipped:YES hints:nil];
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
        @"airline" : @.14,
        @"terminal" : @.07,
        @"counter" : @.10,
        @"gate" : @.08,
        @"state" : @.22
    };
    return [defaults[column] doubleValue];
}

- (NSString *)columnLabel:(NSString *)column {
    NSString *key = self.location[@"display"][@"columnLabels"][column]
                    ?: [@"column." stringByAppendingString:column];
    return DBBoardString(key, self.currentLanguage);
}
- (CGFloat)airportHeaderHeight:(NSRect)area {
    CGFloat fraction = [self.location[@"display"][@"headerFraction"] doubleValue];
    CGFloat height = fraction > 0 ? area.size.height * fraction * self.boardScale
                                 : [self.location[@"display"][@"headerHeight"] doubleValue];
    if ([self.locationCode isEqual:@"HND"] && area.size.width > area.size.height)
        height = MIN(210, area.size.height * .19);
    return MAX(height, [self.location[@"display"][@"minimumHeaderHeight"] doubleValue]);
}

- (CGFloat)airportColumnHeaderHeight {
    return [self.location[@"display"][@"columnHeaderLanguages"] count] > 1 ? 46 : 30;
}

- (void)drawAirportHeader:(NSRect)area {
    NSDictionary *profile = self.location[@"display"];
    CGFloat height = [self airportHeaderHeight:area];
    NSColor *ink = DBColor(profile[@"headerInk"]);
    DBFillRect(NSMakeRect(0, 0, area.size.width, height), DBColor(self.location[@"header"]));
    BOOL haneda = [self.locationCode isEqual:@"HND"];
    if ([self.locationCode isEqual:@"ICN"]) {
        CGFloat unit = height / 230;
        NSBezierPath *box = [NSBezierPath bezierPathWithRoundedRect:
            NSMakeRect(65 * unit, 28 * unit, 174 * unit, 178 * unit)
            xRadius:8 * unit yRadius:8 * unit];
        [ink setStroke];
        box.lineWidth = 5 * unit;
        [box stroke];
        [self planeAt:NSMakePoint(90 * unit, 52 * unit) size:124 * unit color:ink];
        DBFillRect(NSMakeRect(99 * unit, 182 * unit, 105 * unit, 5 * unit), ink);
        DBDrawTextWithFont(DBBoardString(@"heading.departures", @"ko"),
                           NSMakeRect(290 * unit, 20 * unit, 230 * unit, height - 36 * unit),
                           DBNamedFont(@"AppleSDGothicNeo-Bold", height * .47), ink, NSTextAlignmentLeft);
        NSString *asian = [NSString stringWithFormat:@"%@  %@", DBBoardString(@"heading.departures", @"ja"),
                                                     DBBoardString(@"heading.departures", @"zh-Hans")];
        DBDrawTextWithFont(asian, NSMakeRect(550 * unit, 16 * unit, 760 * unit, height * .43),
                           DBNamedFont(@"Arial-BoldMT", height * .27), ink, NSTextAlignmentLeft);
        DBFillRect(NSMakeRect(550 * unit, height * .46, 490 * unit, 5 * unit), ink);
        DBDrawTextWithFont(DBBoardString(@"heading.departures", @"en"),
                           NSMakeRect(550 * unit, height * .48, 820 * unit, height * .37),
                           DBNamedFont(@"Arial-BoldMT", height * .29), ink, NSTextAlignmentLeft);
        return;
    }
    if (haneda) {
        CGFloat unit = MIN(1.6, height / 230);
        if (height >= 140) {
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
    [self drawProfileHeader:area];
}

- (void)drawHanedaCounters:(NSRect)area {
    DBFillRect(area, DBColor(@"233957"));
    NSArray *counters =
        @[ @"N", @"M", @"L", @"K", @"J", @"I", @"H", @"G", @"F", @"", @"E", @"D", @"C", @"B", @"A" ];
    CGFloat width = (area.size.width - 24) / counters.count;
    CGFloat unit = MIN(1.25, area.size.height / 120);
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
            NSImage *logo = [DBAirlineLogoStore imageForCarrier:carrier icao:nil name:nil];
            if (!logo || logoIndex >= 2)
                continue;
            CGFloat size = MIN(width - 14, (cardHeight - 32 * unit) / 2);
            NSRect rect = NSMakeRect(x + (width - size) / 2 - 3, top + 4 + logoIndex * size, size, size);
            DrawAirlineLogo(logo, rect);
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

- (NSInteger)airportRowCountForArea:(NSRect)area {
    if (self.density > 0)
        return MAX(8, MIN(64, self.density));
    NSDictionary *profile = self.location[@"display"];
    CGFloat tableTop = [self airportHeaderHeight:area] + [self airportColumnHeaderHeight] + 4;
    CGFloat tableBottom = area.size.height - MAX(29, [profile[@"footerHeight"] doubleValue] + 3);
    CGFloat minimum = [profile[@"stackedDestination"] boolValue] ? 49 : 34;
    NSInteger readableRows = (NSInteger)floor(MAX(0, tableBottom - tableTop) / minimum);
    NSInteger preferredRows = (NSInteger)ceil([profile[@"rowCount"] doubleValue] / self.boardScale);
    // Preserve each airport's density without enlarging a tall reference panel
    // to the full width of a landscape desktop.
    return MAX(8, MIN(64, MIN(preferredRows, readableRows)));
}

- (void)drawAirport:(NSRect)area {
    NSDictionary *profile = self.location[@"display"];
    [self drawAirportHeader:area];
    // A physical display gets one panel. Long reference walls are cropped to
    // that panel instead of being shrunk or repeated across the desktop.
    NSInteger panels = 1;
    NSInteger rowCount = [self airportRowCountForArea:area];
    NSInteger pages = MAX(1, (self.rows.count + rowCount * panels - 1) / (rowCount * panels));
    self.currentPage = (NSInteger)((NSProcessInfo.processInfo.systemUptime - self.startTime) / 15) % pages;
    self.currentPanelCount = panels;
    CGFloat panelGap = panels > 1 ? 12 : 0;
    CGFloat margin = 20;
    CGFloat panelWidth = (area.size.width - 2 * margin - panelGap * (panels - 1)) / panels;
    CGFloat headingY = [self airportHeaderHeight:area] + 4;
    CGFloat headingHeight = [self airportColumnHeaderHeight];
    CGFloat tableY = headingY + headingHeight;
    CGFloat tableBottom = area.size.height - MAX(29, [profile[@"footerHeight"] doubleValue] + 3);
    CGFloat rowHeight = (tableBottom - tableY) / rowCount;
    CGFloat fontSize = MIN(36, MIN(rowHeight * .78, panelWidth / 34));
    if (profile[@"rowFontScale"])
        fontSize *= [profile[@"rowFontScale"] doubleValue];
    NSArray *columns = [self airportColumns];
    CGFloat totalWeight = 0;
    for (NSString *column in columns)
        totalWeight += [self weightFor:column];

    for (NSInteger panel = 0; panel < panels; panel++) {
        CGFloat left = margin + panel * (panelWidth + panelGap);
        DBFillRect(NSMakeRect(left, headingY, panelWidth, headingHeight - 2), DBColor(profile[@"columnBand"]));
        CGFloat columnX = left;
        for (NSString *column in columns) {
            CGFloat width = panelWidth * [self weightFor:column] / totalWeight;
            NSArray *languages = profile[@"columnHeaderLanguages"];
            NSUInteger lines = MAX(1, languages.count);
            NSString *key = profile[@"columnLabels"][column] ?: [@"column." stringByAppendingString:column];
            for (NSUInteger line = 0; line < lines; line++) {
                NSString *label = languages.count ? DBBoardString(key, languages[line]) : [self columnLabel:column];
                DBDrawTextWithFont(label,
                    NSMakeRect(columnX + 5, headingY + line * headingHeight / lines, width - 8, headingHeight / lines - 2),
                    DBNamedFont(profile[@"bodyFont"], lines > 1 ? 18 : MIN(24, panelWidth / 37)),
                    DBColor(line ? profile[@"headerSecondaryInk"] ?: profile[@"columnInk"] : profile[@"columnInk"]),
                    NSTextAlignmentLeft);
            }
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
                NSString *columnFill = profile[@"columnFills"][column];
                if (columnFill)
                    DBFillRect(NSMakeRect(columnX, top, width - 1, rowHeight - 1), DBColor(columnFill));
                if (profile[@"verticalRules"])
                    DBFillRect(NSMakeRect(columnX + width - 1, top, 1, rowHeight), DBColor(profile[@"verticalRules"]));
                [self drawAirportCell:row column:column rect:cell fontSize:fontSize];
                columnX += width;
            }
        }
    }
    if (!self.rows.count) {
        DBDrawText(DBBoardString(self.emptyMessageKey ?: @"data.loading", self.currentLanguage),
                   NSMakeRect(100, tableY + 70, area.size.width - 200, 80),
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
        ink = DBColor(profile[@"destinationColor"] ?: profile[@"textColor"]);
        if ([profile[@"stackedDestination"] boolValue]) {
            DBDrawTextWithFont(value, NSMakeRect(cell.origin.x, cell.origin.y, cell.size.width, cell.size.height * .57),
                               DBNamedFont(profile[@"bodyFont"], size * .9), ink, NSTextAlignmentLeft);
            DBDrawTextWithFont(row[@"flight"], NSMakeRect(cell.origin.x, cell.origin.y + cell.size.height * .57,
                               cell.size.width, cell.size.height * .43),
                               DBNamedFont(profile[@"bodyFont"], size * .62),
                               DBColor(profile[@"textColor"]), NSTextAlignmentLeft);
            return;
        }
    } else if ([column isEqual:@"state"]) {
        value = DBStatusText(row[@"state"], self.currentLanguage);
        if ([profile[@"hideScheduledStatus"] boolValue] && [row[@"state"] isEqual:@"scheduled"])
            value = @"";
        if (![@[ @"scheduled", @"departed" ] containsObject:row[@"state"]])
            ink = DBStatusColor(row[@"state"]);
        if (profile[@"statusColors"][row[@"state"]])
            ink = DBColor(profile[@"statusColors"][row[@"state"]]);
        NSString *fill = profile[@"statusFills"][row[@"state"]];
        if (fill && value.length) {
            DBFillRect(NSInsetRect(cell, -3, -1), DBColor(fill));
            ink = DBColor(profile[@"statusFillInk"] ?: @"ffffff");
        }
        if ([profile[@"statusMarker"] boolValue] && value.length) {
            CGFloat radius = MIN(10, cell.size.height * .24);
            [ink setStroke];
            NSBezierPath *marker = [NSBezierPath bezierPathWithOvalInRect:
                NSMakeRect(cell.origin.x, NSMidY(cell) - radius, radius * 2, radius * 2)];
            marker.lineWidth = 1.5;
            [marker stroke];
            cell.origin.x += radius * 2 + 6;
            cell.size.width -= radius * 2 + 6;
        }
        size *= .88;
    } else if ([column isEqual:@"time"]) {
        ink = DBColor(profile[@"timeColor"]);
    } else if ([column isEqual:@"expected"]) {
        ink = DBColor(@"ffd653");
    }
    if ([column isEqual:@"gate"] && [profile[@"gateIncludesTerminal"] boolValue]) {
        NSString *terminal = row[@"terminal"] ?: @"";
        if (terminal.length)
            value = value.length ? [NSString stringWithFormat:@"%@ · %@", terminal, value] : terminal;
    }

    if (!value.length)
        value = profile[@"emptyFields"][column] ?: @"";
    if ([column isEqual:@"airline"]) {
        NSString *carrier = [row[@"flight"] componentsSeparatedByString:@" "].firstObject;
        NSImage *logo = [DBAirlineLogoStore imageForCarrier:carrier icao:row[@"airlineICAO"] name:row[@"airline"]];
        if (logo)
            DrawAirlineLogo(logo, NSInsetRect(cell, 4, 2));
        else
            DBDrawTextWithFont(row[@"airline"] ?: carrier, cell, DBNamedFont(profile[@"bodyFont"], size * .70),
                               ink, NSTextAlignmentLeft);
        return;
    }

    if ([column isEqual:@"flight"] && [profile[@"airlineBadge"] boolValue]) {
        CGFloat badgeWidth = MIN(74, cell.size.width * .32);
        NSRect badge = NSMakeRect(cell.origin.x, cell.origin.y + 2, badgeWidth, cell.size.height - 4);
        NSString *carrier = [row[@"flight"] componentsSeparatedByString:@" "].firstObject;
        NSImage *logo = [DBAirlineLogoStore imageForCarrier:carrier
                                                     icao:row[@"airlineICAO"] name:row[@"airline"]];
        if (logo) {
            DrawAirlineLogo(logo, badge);
        } else {
            DBDrawText(carrier, badge, size * .54, NSColor.whiteColor, YES, NSTextAlignmentCenter, NO);
        }
        cell.origin.x += badgeWidth + 5;
        cell.size.width -= badgeWidth + 5;
    }
    if ([column isEqual:@"gate"] && [profile[@"gateHighlight"] boolValue]) {
        DBFillRect(NSInsetRect(cell, 1, 1), DBColor(@"f4ec7b"));
        ink = DBColor(@"17221a");
    }
    if (profile[@"columnInkColors"][column])
        ink = DBColor(profile[@"columnInkColors"][column]);
    // Numeric fields must stay complete: a truncated boarding time is misleading.
    if (numbers)
        size = MIN(size, cell.size.width / MAX(2.6, value.length * .60));
    DBDrawTextWithFont(value, cell, DBNamedFont(profile[@"bodyFont"], size), ink, NSTextAlignmentLeft);
}

@end
