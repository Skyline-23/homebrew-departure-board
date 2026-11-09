#import "AirportComponents.h"
#import "DepartureBoardView.h"
#import "DrawingSupport.h"

static void DrawClock(NSRect rect, NSString *style, NSColor *ink, id<DBAirportAdapter> adapter,
                      DBAirportRenderContext *context) {
    if ([style isEqual:@"analog"]) {
        CGFloat diameter = MIN(rect.size.width, rect.size.height);
        NSRect face = NSMakeRect(NSMidX(rect) - diameter / 2, NSMidY(rect) - diameter / 2, diameter,
                                 diameter);
        [NSColor.whiteColor setFill];
        [[NSBezierPath bezierPathWithOvalInRect:face] fill];
        NSPoint center = NSMakePoint(NSMidX(face), NSMidY(face));
        [DBColor(@"354044") setStroke];
        for (NSInteger tick = 0; tick < 12; tick++) {
            CGFloat angle = tick * M_PI / 6 - M_PI_2;
            CGFloat outer = diameter * .44, inner = diameter * (tick % 3 ? .39 : .34);
            NSBezierPath *mark = NSBezierPath.bezierPath;
            mark.lineWidth = MAX(1, diameter / 90);
            [mark moveToPoint:NSMakePoint(center.x + cos(angle) * inner,
                                          center.y + sin(angle) * inner)];
            [mark lineToPoint:NSMakePoint(center.x + cos(angle) * outer,
                                          center.y + sin(angle) * outer)];
            [mark stroke];
        }
        NSCalendar *calendar =
            [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        calendar.timeZone = [NSTimeZone timeZoneWithName:adapter.location[@"zone"]];
        NSDateComponents *time = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute
                                             fromDate:context.date];
        CGFloat angles[] = {(time.hour % 12 + time.minute / 60.0) * M_PI / 6 - M_PI_2,
                            time.minute * M_PI / 30 - M_PI_2};
        for (NSInteger hand = 0; hand < 2; hand++) {
            CGFloat length = diameter * (hand ? .36 : .25);
            NSBezierPath *path = NSBezierPath.bezierPath;
            path.lineWidth = MAX(2, diameter / (hand ? 40 : 28));
            path.lineCapStyle = NSLineCapStyleRound;
            [path moveToPoint:center];
            [path lineToPoint:NSMakePoint(center.x + cos(angles[hand]) * length,
                                          center.y + sin(angles[hand]) * length)];
            [path stroke];
        }
        return;
    }
    if ([style isEqual:@"digital"]) {
        DBFillRect(rect, DBColor(@"11171b"));
        rect = NSInsetRect(rect, 10, 4);
    }
    DBDrawText(DBTime(context.date, adapter.location, @"HH:mm"), rect,
               MIN(56, rect.size.height * .78), ink, YES, NSTextAlignmentRight, YES);
}

void DBDrawProfileAirportHeader(NSRect area, id<DBAirportAdapter> adapter,
                                DBAirportRenderContext *context) {
    NSDictionary *profile = adapter.location[@"display"];
    CGFloat height = [adapter headerHeightForBounds:area scale:context.scale];
    DBFillRect(NSMakeRect(0, 0, area.size.width, height), DBColor(adapter.location[@"header"]));
    CGFloat unit = MIN(1.4, height / 100);
    CGFloat margin = 22;
    NSColor *ink = DBColor(profile[@"headerInk"]);
    NSColor *secondaryInk = DBColor(profile[@"headerSecondaryInk"] ?: profile[@"headerInk"]);
    NSString *layout = profile[@"headerLayout"] ?: @"stacked";
    NSString *clockStyle = profile[@"clockStyle"] ?: @"plain";
    BOOL footerClock = [profile[@"clockPosition"] isEqual:@"footer"];
    CGFloat clockWidth = footerClock ? 0 : ([clockStyle isEqual:@"analog"] ? height : 188 * unit);
    CGFloat clockX = area.size.width - clockWidth - margin;
    CGFloat left = margin;
    NSString *icon = profile[@"headerIcon"] ?: @"plane";
    if (![icon isEqual:@"none"]) {
        CGFloat size = MIN(60, height * .56);
        NSRect frame = NSMakeRect(left, (height - size) / 2, size, size);
        NSColor *iconInk = ink;
        if ([icon isEqual:@"boxed"] || [icon isEqual:@"circle"]) {
            NSBezierPath *outline = [icon isEqual:@"circle"]
                                        ? [NSBezierPath bezierPathWithOvalInRect:frame]
                                        : [NSBezierPath bezierPathWithRoundedRect:frame
                                                                          xRadius:2
                                                                          yRadius:2];
            if (profile[@"iconFill"]) {
                [DBColor(profile[@"iconFill"]) setFill];
                [outline fill];
                iconInk = DBColor(profile[@"iconInk"] ?: @"11151b");
            } else {
                [ink setStroke];
                outline.lineWidth = 2;
                [outline stroke];
            }
            frame = NSInsetRect(frame, size * .12, size * .12);
        }
        DBDrawDepartureIcon(frame.origin, frame.size.width, iconInk);
        left += size + 18;
    }
    NSString *brand = profile[@"brand"];
    if ([profile[@"terminalHeading"] boolValue]) {
        NSMutableSet *terminals = NSMutableSet.new;
        for (NSDictionary *row in context.rows) {
            if ([row[@"terminal"] length]) {
                [terminals addObject:row[@"terminal"]];
            }
        }
        if (terminals.count == 1) {
            brand = [NSString stringWithFormat:@"%@ %@",
                                               DBBoardString(@"column.terminal", context.language),
                                               terminals.anyObject];
        }
    }
    if (brand.length) {
        CGFloat width = [profile[@"brandWidth"] doubleValue] ?: 170;
        NSArray *lines = [brand componentsSeparatedByString:@"\n"];
        CGFloat lineHeight = (height - 16) / lines.count;
        for (NSUInteger line = 0; line < lines.count; line++) {
            DBDrawTextWithFont(lines[line],
                               NSMakeRect(left, 8 + line * lineHeight, width, lineHeight),
                               DBNamedFont(profile[@"headerFont"], MIN(30, height * .28)), ink,
                               NSTextAlignmentLeft);
        }
        left += width + 24;
    }
    NSArray *languages = profile[@"headerLanguages"];
    NSString *primaryLanguage = languages.count ? languages[0] : context.language;
    NSString *secondaryLanguage =
        languages.count > 1
            ? languages[1]
            : ([context.language isEqual:@"en"] ? adapter.location[@"lang"] : @"en");
    NSString *titleKey = profile[@"titleKey"] ?: adapter.location[@"titleKey"];
    NSString *primary = DBBoardString(titleKey, primaryLanguage);
    NSString *secondary = DBBoardString(titleKey, secondaryLanguage);
    BOOL bilingual = ![primary isEqual:secondary] && ![layout isEqual:@"single"];
    CGFloat available = MAX(100, clockX - left - 24);
    CGFloat fontSize = MIN([profile[@"titleSize"] doubleValue] ?: 60,
                           height * (bilingual && [layout isEqual:@"stacked"] ? .40 : .57));
    NSTextAlignment alignment =
        [layout isEqual:@"centered"] ? NSTextAlignmentCenter : NSTextAlignmentLeft;
    if (bilingual && [layout isEqual:@"inline"]) {
        NSFont *font = DBNamedFont(profile[@"headerFont"], fontSize);
        CGFloat primaryWidth = MIN(
            available * .55, [primary sizeWithAttributes:@{NSFontAttributeName : font}].width + 20);
        DBDrawTextWithFont(primary, NSMakeRect(left, 6, primaryWidth, height - 12), font, ink,
                           alignment);
        DBDrawTextWithFont(
            secondary, NSMakeRect(left + primaryWidth, 6, available - primaryWidth, height - 12),
            font, secondaryInk, NSTextAlignmentLeft);
    } else if (bilingual && [layout isEqual:@"stacked"]) {
        DBDrawTextWithFont(primary, NSMakeRect(left, height * .08, available, height * .47),
                           DBNamedFont(profile[@"headerFont"], fontSize), ink, alignment);
        DBDrawTextWithFont(secondary, NSMakeRect(left, height * .54, available, height * .36),
                           DBNamedFont(profile[@"headerFont"], fontSize * .75), secondaryInk,
                           alignment);
    } else {
        DBDrawTextWithFont(primary, NSMakeRect(left, 5, available, height - 10),
                           DBNamedFont(profile[@"headerFont"], fontSize), ink, alignment);
    }
    if (!footerClock) {
        BOOL date = [profile[@"dateInHeader"] boolValue];
        NSRect frame = NSMakeRect(clockX, height * .10, clockWidth, height * (date ? .57 : .80));
        DrawClock(frame, clockStyle, DBColor(profile[@"clockColor"] ?: profile[@"headerInk"]),
                  adapter, context);
        if (date) {
            DBDrawText(DBTime(context.date, adapter.location, @"dd MMM yyyy"),
                       NSMakeRect(clockX - 80, height * .70, clockWidth + 80, height * .23),
                       MIN(20, height * .20), secondaryInk, NO, NSTextAlignmentRight, NO);
        }
    }
    if (profile[@"headerRule"]) {
        DBFillRect(NSMakeRect(0, height - 2, area.size.width, 2), DBColor(profile[@"headerRule"]));
    }
}
