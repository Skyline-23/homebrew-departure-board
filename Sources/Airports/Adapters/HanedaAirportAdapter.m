#import "AirlineLogoStore.h"
#import "Airports/AirportAdapters.h"
#import "DepartureBoardView.h"
#import "DrawingSupport.h"

@implementation DBHanedaAirportAdapter

- (CGFloat)headerHeightForBounds:(NSRect)area scale:(CGFloat)scale {
    CGFloat height = [super headerHeightForBounds:area scale:scale];
    if (area.size.width > area.size.height) {
        height = MAX(MIN(210, area.size.height * .19),
                     [self.display[@"minimumHeaderHeight"] doubleValue]);
    }
    return height;
}

- (void)drawHeaderInBounds:(NSRect)area context:(DBAirportRenderContext *)context {
    CGFloat height = [self headerHeightForBounds:area scale:context.scale];
    NSColor *ink = DBColor(self.display[@"headerInk"]);
    DBFillRect(NSMakeRect(0, 0, area.size.width, height), DBColor(self.location[@"header"]));
    CGFloat unit = MIN(1.6, height / 230);
    if (height >= 140) {
        DBDrawText(DBBoardString(@"heading.checkinInformation", context.language),
                   NSMakeRect(26, 3, 1400, 30 * unit), 23 * unit, ink, YES, NSTextAlignmentLeft,
                   NO);
        [self drawCounters:NSMakeRect(24, 38 * unit, area.size.width - 48, height - 93 * unit)
                   context:context];
    }
    DBFillRect(NSMakeRect(0, height - 45 * unit, area.size.width, 45 * unit), NSColor.blackColor);
    DBFillRect(NSMakeRect(0, height - 3, area.size.width, 3), DBColor(@"8dd856"));
    DBDrawDepartureIcon(NSMakePoint(25, height - 38 * unit), 30 * unit, DBColor(@"a9e482"));
    DBDrawText(DBBoardString(@"heading.departures", context.language),
               NSMakeRect(68 * unit, height - 42 * unit, 1000, 37 * unit), 28 * unit, ink, YES,
               NSTextAlignmentLeft, NO);
    DBDrawText(DBTime(context.date, self.location, @"HH:mm"),
               NSMakeRect(area.size.width - 190 * unit, height - 42 * unit, 164 * unit, 37 * unit),
               28 * unit, DBColor(@"a9e482"), YES, NSTextAlignmentRight, YES);
}

- (void)drawCounters:(NSRect)area context:(DBAirportRenderContext *)context {
    DBFillRect(area, DBColor(@"233957"));
    NSArray *counters = @[
        @"N", @"M", @"L", @"K", @"J", @"I", @"H", @"G", @"F", @"", @"E", @"D", @"C", @"B", @"A"
    ];
    CGFloat width = (area.size.width - 24) / counters.count;
    CGFloat unit = MIN(1.25, area.size.height / 120);
    for (NSUInteger index = 0; index < counters.count; index++) {
        NSString *letter = counters[index];
        if (!letter.length) {
            continue;
        }
        CGFloat x = area.origin.x + 12 + index * width;
        CGFloat top = area.origin.y + area.size.height * .25;
        CGFloat cardHeight = area.size.height * .57;
        DBFillRect(NSMakeRect(x, top, width - 6, cardHeight), DBColor(@"d8e5eb"));
        NSMutableOrderedSet *carriers = NSMutableOrderedSet.new;
        for (NSDictionary *row in context.rows) {
            NSString *counter = row[@"counter"];
            if (!counter.length || [counter rangeOfString:letter].location == NSNotFound) {
                continue;
            }
            NSString *number = row[@"operatorFlight"] ?: row[@"flight"];
            if (number.length >= 2) {
                [carriers addObject:[number substringToIndex:2]];
            }
        }
        NSMutableArray<NSImage *> *logos = NSMutableArray.new;
        for (NSString *carrier in carriers) {
            NSImage *logo = [DBAirlineLogoStore imageForCarrier:carrier icao:nil name:nil];
            if (logo) {
                [logos addObject:logo];
            }
            if (logos.count == 2) {
                break;
            }
        }
        // Keep the artwork inside the counter's logo area. A single airline
        // sits on the same centerline; shared counters get two equal slots.
        CGFloat labelHeight = 28 * unit;
        NSRect logoArea =
            NSMakeRect(x + 5, top + 4, width - 16, MAX(0, cardHeight - labelHeight - 8));
        CGFloat slotHeight = logoArea.size.height / 2;
        CGFloat inset = logos.count == 1 ? slotHeight / 2 : 0;
        for (NSUInteger index = 0; index < logos.count; index++) {
            NSRect slot =
                NSMakeRect(logoArea.origin.x, logoArea.origin.y + inset + index * slotHeight,
                           logoArea.size.width, slotHeight);
            NSRect artwork = NSInsetRect(slot, 3 * unit, 2 * unit);
            [NSGraphicsContext saveGraphicsState];
            NSRectClip(slot);
            DBDrawAirlineLogo(logos[index], artwork);
            [NSGraphicsContext restoreGraphicsState];
        }
        DBFillRect(NSMakeRect(x, top + cardHeight - labelHeight - 1, width - 6, 1),
                   DBColor(@"386495"));
        DBFillRect(NSMakeRect(x, top + cardHeight - 28 * unit, width - 6, 28 * unit),
                   DBColor(@"bcd3e2"));
        DBDrawText(letter, NSMakeRect(x, top + cardHeight - 27 * unit, width - 6, 27 * unit),
                   23 * unit, DBColor(@"101d2d"), YES, NSTextAlignmentCenter, NO);
    }
    DBDrawText(DBBoardString(@"heading.securityNorth", context.language),
               NSMakeRect(area.origin.x + width * 2, area.origin.y + 2, width * 4, 27 * unit),
               17 * unit, NSColor.whiteColor, YES, NSTextAlignmentCenter, NO);
    DBDrawText(DBBoardString(@"heading.securityCentral", context.language),
               NSMakeRect(area.origin.x + width * 8, area.origin.y + 2, width * 5, 27 * unit),
               17 * unit, NSColor.whiteColor, YES, NSTextAlignmentCenter, NO);
}

@end
