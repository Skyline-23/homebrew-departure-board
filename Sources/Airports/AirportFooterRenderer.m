#import "AirportComponents.h"
#import "DepartureBoardView.h"
#import "DrawingSupport.h"

static BOOL DrawStyledFooter(NSRect area, id<DBAirportAdapter> adapter,
                             DBAirportRenderContext *context) {

    NSDictionary *profile = adapter.location[@"display"];
    NSString *style = profile[@"footerStyle"];

    if (!style.length) {
        return NO;
    }
    CGFloat height = MAX(26, [profile[@"footerHeight"] doubleValue]);
    NSRect footer = NSMakeRect(0, area.size.height - height, area.size.width, height);
    NSColor *ink = DBColor(profile[@"footerInk"] ?: @"ffffff");
    DBFillRect(footer, DBColor(profile[@"footerColor"] ?: adapter.location[@"header"]));
    CGFloat size = MIN(23, height * .60);

    if ([style isEqual:@"date-clock"]) {
        DBDrawText(DBTime(context.date, adapter.location, @"dd MMM yyyy"),
                   NSMakeRect(22, footer.origin.y + 2, 370, height - 4), size, ink, NO,
                   NSTextAlignmentLeft, NO);
    }
    NSString *notice = profile[@"footerNoticeKey"];
    NSString *center = notice ? DBBoardString(notice, context.language) : profile[@"footerBrand"];

    if (center.length) {
        DBDrawText(
            center,
            NSMakeRect(400, footer.origin.y + 2, MAX(100, area.size.width - 800), height - 4), size,
            ink, NO, NSTextAlignmentCenter, NO);
    }

    if ([style isEqual:@"pages"]) {
        NSInteger count = [adapter rowCountForBounds:area
                                               scale:context.scale
                                             density:context.density];
        NSString *page =
            [NSString stringWithFormat:@"%ld / %ld", (long)context.page + 1,
                                       (long)MAX(1, (context.rows.count + count - 1) / count)];
        DBDrawText(page, NSMakeRect(22, footer.origin.y + 2, 160, height - 4), size, ink, NO,
                   NSTextAlignmentLeft, YES);
    }

    if (![style isEqual:@"brand-only"]) {
        DBDrawText(DBTime(context.date, adapter.location, @"HH:mm"),
                   NSMakeRect(area.size.width - 180, footer.origin.y + 2, 158, height - 4), size,
                   ink, YES, NSTextAlignmentRight, YES);
    }
    return YES;
}

void DBDrawProfileAirportFooter(NSRect area, id<DBAirportAdapter> adapter,
                                DBAirportRenderContext *context) {

    if (DrawStyledFooter(area, adapter, context)) {
        return;
    }
    CGFloat height = MAX(26, [adapter.display[@"footerHeight"] doubleValue]);
    CGFloat y = area.size.height - height;
    DBFillRect(NSMakeRect(0, y, area.size.width, height), DBColor(@"080d13"));
    NSString *key = adapter.display[@"footerNoticeKey"];

    if (key.length) {
        DBDrawText(DBBoardString(key, context.language), NSMakeRect(24, y + 2, 1450, height - 3),
                   height * .57, NSColor.whiteColor, NO, NSTextAlignmentLeft, NO);
    }
}
