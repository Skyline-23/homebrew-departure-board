#import "Airports/AirportAdapters.h"
#import "DepartureBoardView.h"
#import "DrawingSupport.h"

@implementation DBIncheonAirportAdapter

- (void)drawHeaderInBounds:(NSRect)area context:(DBAirportRenderContext *)context {
    CGFloat height = [self headerHeightForBounds:area scale:context.scale];
    NSColor *ink = DBColor(self.display[@"headerInk"]);
    DBFillRect(NSMakeRect(0, 0, area.size.width, height), DBColor(self.location[@"header"]));
    CGFloat unit = height / 230;
    NSBezierPath *box = [NSBezierPath
        bezierPathWithRoundedRect:NSMakeRect(65 * unit, 28 * unit, 174 * unit, 178 * unit)
                          xRadius:8 * unit
                          yRadius:8 * unit];
    [ink setStroke];
    box.lineWidth = 5 * unit;
    [box stroke];
    DBDrawDepartureIcon(NSMakePoint(90 * unit, 52 * unit), 124 * unit, ink);
    DBDrawTextWithFont(DBBoardString(@"heading.departures", @"ko"),
                       NSMakeRect(290 * unit, 20 * unit, 230 * unit, height - 36 * unit),
                       DBNamedFont(@"AppleSDGothicNeo-Bold", height * .47), ink,
                       NSTextAlignmentLeft);
    NSString *asian =
        [NSString stringWithFormat:@"%@  %@", DBBoardString(@"heading.departures", @"ja"),
                                   DBBoardString(@"heading.departures", @"zh-Hans")];
    DBDrawTextWithFont(asian, NSMakeRect(550 * unit, 16 * unit, 760 * unit, height * .43),
                       DBNamedFont(@"Arial-BoldMT", height * .27), ink, NSTextAlignmentLeft);
    DBFillRect(NSMakeRect(550 * unit, height * .46, 490 * unit, 5 * unit), ink);
    DBDrawTextWithFont(DBBoardString(@"heading.departures", @"en"),
                       NSMakeRect(550 * unit, height * .48, 820 * unit, height * .37),
                       DBNamedFont(@"Arial-BoldMT", height * .29), ink, NSTextAlignmentLeft);
}

- (void)drawFooterInBounds:(NSRect)area context:(DBAirportRenderContext *)context {
    [super drawFooterInBounds:area context:context];
    CGFloat height = MAX(26, [self.display[@"footerHeight"] doubleValue]);
    CGFloat y = area.size.height - height;
    DBDrawText(DBTime(context.date, self.location, @"yyyy. MM. dd."),
               NSMakeRect(24, y + 2, 280, height - 4), height * .60, NSColor.whiteColor, YES,
               NSTextAlignmentLeft, YES);
    DBDrawText([NSString stringWithFormat:@"%ld", (long)(context.page + 1)],
               NSMakeRect(area.size.width / 2 - 20, y + 2, 40, height - 4), height * .60,
               NSColor.whiteColor, YES, NSTextAlignmentCenter, YES);
    DBDrawText(DBTime(context.date, self.location, @"HH:mm"),
               NSMakeRect(area.size.width - 140, y + 2, 115, height - 4), height * .60,
               DBColor(@"ffea83"), YES, NSTextAlignmentRight, YES);
}

@end
