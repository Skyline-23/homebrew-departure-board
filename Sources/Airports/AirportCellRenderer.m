#import "AirlineLogoStore.h"
#import "AirportTableRenderer.h"
#import "DepartureBoardView.h"
#import "DrawingSupport.h"

void DBDrawAirportCell(NSDictionary *row, NSString *column, NSRect cell, CGFloat size,
                       NSInteger rowIndex, id<DBAirportAdapter> adapter,
                       DBAirportRenderContext *context) {
    NSDictionary *profile = adapter.display;
    NSString *value = row[column] ?: @"";
    NSArray *rowInks = profile[@"rowInkColors"];
    NSColor *baseInk =
        DBColor(rowInks.count ? rowInks[rowIndex % rowInks.count] : profile[@"textColor"]);
    NSColor *ink = baseInk;
    BOOL numbers = [@[ @"time", @"expected", @"gate", @"flight" ] containsObject:column];
    if ([column isEqual:@"destination"]) {
        value = DBLocalized(row[@"destination"], context.language);
        if ([profile[@"uppercaseDestinations"] boolValue]) {
            value = value.uppercaseString;
        }
        ink = profile[@"destinationColor"] ? DBColor(profile[@"destinationColor"]) : baseInk;
        if ([profile[@"stackedDestination"] boolValue]) {
            DBDrawTextWithFont(
                value,
                NSMakeRect(cell.origin.x, cell.origin.y, cell.size.width, cell.size.height * .57),
                DBNamedFont(profile[@"bodyFont"], size * .9), ink, NSTextAlignmentLeft);
            DBDrawTextWithFont(row[@"flight"],
                               NSMakeRect(cell.origin.x, cell.origin.y + cell.size.height * .57,
                                          cell.size.width, cell.size.height * .43),
                               DBNamedFont(profile[@"bodyFont"], size * .62),
                               DBColor(profile[@"textColor"]), NSTextAlignmentLeft);
            return;
        }
    } else if ([column isEqual:@"state"]) {
        value = DBStatusText(row[@"state"], context.language);
        if ([profile[@"hideScheduledStatus"] boolValue] && [row[@"state"] isEqual:@"scheduled"]) {
            value = @"";
        }
        if (![profile[@"statusUsesRowInk"] boolValue] &&
            ![@[ @"scheduled", @"departed", @"unknown" ] containsObject:row[@"state"]]) {
            ink = DBStatusColor(row[@"state"]);
        }
        if (profile[@"statusColors"][row[@"state"]]) {
            ink = DBColor(profile[@"statusColors"][row[@"state"]]);
        }
        NSString *fill = profile[@"statusFills"][row[@"state"]];
        if (fill && value.length) {
            DBFillRect(NSInsetRect(cell, -3, -1), DBColor(fill));
            ink = DBColor(profile[@"statusFillInk"] ?: @"ffffff");
        }
        if ([profile[@"statusMarker"] boolValue] && value.length) {
            CGFloat radius = MIN(10, cell.size.height * .24);
            [ink setStroke];
            NSBezierPath *marker = [NSBezierPath
                bezierPathWithOvalInRect:NSMakeRect(cell.origin.x, NSMidY(cell) - radius,
                                                    radius * 2, radius * 2)];
            marker.lineWidth = 1.5;
            [marker stroke];
            cell.origin.x += radius * 2 + 6;
            cell.size.width -= radius * 2 + 6;
        }
        size *= .88;
    } else if ([column isEqual:@"time"]) {
        ink = rowInks.count ? baseInk : DBColor(profile[@"timeColor"]);
    } else if ([column isEqual:@"expected"]) {
        ink = DBColor(@"ffd653");
    }
    if ([column isEqual:@"gate"] && [profile[@"gateIncludesTerminal"] boolValue]) {
        NSString *terminal = row[@"terminal"] ?: @"";
        if (terminal.length) {
            value =
                value.length ? [NSString stringWithFormat:@"%@ · %@", terminal, value] : terminal;
        }
    }

    if (!value.length) {
        value = profile[@"emptyFields"][column] ?: @"";
    }
    if ([column isEqual:@"airline"]) {
        NSString *carrier = [row[@"flight"] componentsSeparatedByString:@" "].firstObject;
        NSImage *logo = [DBAirlineLogoStore imageForCarrier:carrier
                                                       icao:row[@"airlineICAO"]
                                                       name:row[@"airline"]];
        if (logo) {
            DBDrawAirlineLogo(logo, NSInsetRect(cell, 4, 2));
        } else {
            DBDrawTextWithFont(row[@"airline"] ?: carrier, cell,
                               DBNamedFont(profile[@"bodyFont"], size * .70), ink,
                               NSTextAlignmentLeft);
        }
        return;
    }

    if ([column isEqual:@"flight"] && [profile[@"airlineBadge"] boolValue]) {
        CGFloat badgeWidth = MIN(74, cell.size.width * .32);
        NSRect badge =
            NSMakeRect(cell.origin.x, cell.origin.y + 2, badgeWidth, cell.size.height - 4);
        NSString *carrier = [row[@"flight"] componentsSeparatedByString:@" "].firstObject;
        NSImage *logo = [DBAirlineLogoStore imageForCarrier:carrier
                                                       icao:row[@"airlineICAO"]
                                                       name:row[@"airline"]];
        if (logo) {
            DBDrawAirlineLogo(logo, badge);
        } else {
            DBDrawText(carrier, badge, size * .54, NSColor.whiteColor, YES, NSTextAlignmentCenter,
                       NO);
        }
        cell.origin.x += badgeWidth + 5;
        cell.size.width -= badgeWidth + 5;
    }
    if ([column isEqual:@"gate"] && [profile[@"gateHighlight"] boolValue]) {
        DBFillRect(NSInsetRect(cell, 1, 1), DBColor(@"f4ec7b"));
        ink = DBColor(@"17221a");
    }
    if (profile[@"columnInkColors"][column]) {
        ink = DBColor(profile[@"columnInkColors"][column]);
    }
    // Numeric fields must stay complete: a truncated boarding time is misleading.
    if (numbers) {
        size = MIN(size, cell.size.width / MAX(2.6, value.length * .60));
    }
    DBDrawTextWithFont(value, cell, DBNamedFont(profile[@"bodyFont"], size), ink,
                       NSTextAlignmentLeft);
}
