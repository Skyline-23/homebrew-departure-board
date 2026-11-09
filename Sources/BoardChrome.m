#import "BoardViewInternal.h"
#import "DrawingSupport.h"
#import "LiveFlightStore.h"

@implementation DBBoardView (BoardChrome)

- (void)planeAt:(NSPoint)point size:(CGFloat)size color:(NSColor *)color {
    static NSCache *icons;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        icons = NSCache.new;
        icons.countLimit = 32;
        icons.totalCostLimit = 2 * 1024 * 1024;
    });
    NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    NSString *key = [NSString stringWithFormat:@"%.3f/%.3f/%.3f/%.3f", rgb.redComponent, rgb.greenComponent,
                                               rgb.blueComponent, rgb.alphaComponent];
    NSImage *icon = [icons objectForKey:key];
    if (!icon) {
        NSImage *symbol = [[NSImage imageWithSystemSymbolName:@"airplane.departure"
                                     accessibilityDescription:nil]
            imageWithSymbolConfiguration:[NSImageSymbolConfiguration
                                             configurationWithPointSize:128
                                                                 weight:NSFontWeightRegular]];
        if (!symbol)
            return;
        NSSize resolution = NSMakeSize(ceil(symbol.size.width), ceil(symbol.size.height));
        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                           pixelsWide:resolution.width
                                                                           pixelsHigh:resolution.height
                                                                        bitsPerSample:8
                                                                      samplesPerPixel:4
                                                                             hasAlpha:YES
                                                                             isPlanar:NO
                                                                       colorSpaceName:NSDeviceRGBColorSpace
                                                                          bytesPerRow:0
                                                                         bitsPerPixel:0];
        [NSGraphicsContext saveGraphicsState];
        NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
        NSRect rect = NSMakeRect(0, 0, resolution.width, resolution.height);
        [NSColor.clearColor setFill];
        NSRectFillUsingOperation(rect, NSCompositingOperationCopy);
        [symbol drawInRect:rect];
        [color setFill];
        NSRectFillUsingOperation(rect, NSCompositingOperationSourceIn);
        [NSGraphicsContext restoreGraphicsState];
        icon = [[NSImage alloc] initWithSize:resolution];
        [icon addRepresentation:bitmap];
        [icons setObject:icon forKey:key cost:(NSUInteger)(resolution.width * resolution.height * 4)];
    }
    CGFloat factor = size / MAX(icon.size.width, icon.size.height);
    NSRect destination = NSMakeRect(point.x + (size - icon.size.width * factor) / 2,
                                    point.y + (size - icon.size.height * factor) / 2,
                                    icon.size.width * factor, icon.size.height * factor);
    [icon drawInRect:destination
              fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver
              fraction:1
        respectFlipped:YES
                 hints:nil];
}

- (void)header:(NSRect)area compact:(BOOL)compact {
    NSString *preset = self.location[@"preset"];
    NSColor *white = DBColor(@"f6f7f4");
    BOOL light = [self.location[@"headerStyle"] isEqual:@"light"];
    NSColor *ink = light ? DBColor(@"111a20") : white;
    CGFloat height = compact ? 112 : 144;
    DBFillRect(NSMakeRect(0, 0, area.size.width, height), DBColor(self.location[@"header"]));
    if ([preset isEqual:@"icn"])
        DBFillRect(NSMakeRect(0, height - 4, area.size.width, 4), DBColor(@"4883ba"));
    if ([preset isEqual:@"narita"])
        DBFillRect(NSMakeRect(0, 0, 12, height), DBColor(@"60a77d"));
    if ([preset isEqual:@"haneda"])
        DBFillRect(NSMakeRect(0, height - 6, area.size.width, 6), DBColor(@"68d6e5"));
    [self planeAt:NSMakePoint(34, compact ? 30 : 42) size:52 color:ink];
    NSString *title = DBBoardString(self.location[@"titleKey"], self.currentLanguage);
    if ([preset isEqual:@"heathrow"])
        title = @"Departures";
    DBDrawText(title, NSMakeRect(106, compact ? 14 : 25, 990, 62), compact ? 42 : 48, ink, YES,
               NSTextAlignmentLeft, NO);
    NSString *sub =
        [NSString stringWithFormat:@"%@  /  %@", self.location[@"code"], self.location[@"subtitle"]];
    DBDrawText(sub, NSMakeRect(108, compact ? 72 : 94, 1070, 25), 17, [ink colorWithAlphaComponent:.78], NO,
               NSTextAlignmentLeft, NO);
    DBDrawText(DBTime(self.boardDate, self.location, @"HH:mm"),
               NSMakeRect(area.size.width - 306, compact ? 10 : 22, 270, 65), 57, ink, YES,
               NSTextAlignmentRight, YES);
    DBDrawText(DBTime(self.boardDate, self.location, @"EEE, dd MMM yyyy"),
               NSMakeRect(area.size.width - 325, compact ? 78 : 96, 289, 24), 17,
               [ink colorWithAlphaComponent:.8], NO, NSTextAlignmentRight, NO);
}

- (void)footer:(NSRect)area text:(NSString *)message {
    BOOL airport = [self.location[@"kind"] isEqual:@"airport"];
    if (airport && [self drawProfileFooter:area])
        return;
    CGFloat height = airport ? MAX(26, [self.location[@"display"][@"footerHeight"] doubleValue]) : 40;
    CGFloat y = area.size.height - height;
    DBFillRect(NSMakeRect(0, y, area.size.width, height), DBColor(@"080d13"));
    if (airport) {
        // Only show footer content present in this airport's reference display.
        NSString *notice = self.location[@"display"][@"footerNoticeKey"];
        message = notice ? DBBoardString(notice, self.currentLanguage) : @"";
        if ([self.locationCode isEqual:@"ICN"]) {
            DBDrawText(DBTime(self.boardDate, self.location, @"yyyy. MM. dd."),
                       NSMakeRect(24, y + 2, 280, height - 4), height * .60, NSColor.whiteColor, YES,
                       NSTextAlignmentLeft, YES);
            DBDrawText([NSString stringWithFormat:@"%ld", (long)(self.currentPage + 1)],
                       NSMakeRect(area.size.width / 2 - 20, y + 2, 40, height - 4), height * .60,
                       NSColor.whiteColor, YES, NSTextAlignmentCenter, YES);
            DBDrawText(DBTime(self.boardDate, self.location, @"HH:mm"),
                       NSMakeRect(area.size.width - 140, y + 2, 115, height - 4), height * .60,
                       DBColor(@"ffea83"), YES, NSTextAlignmentRight, YES);
        }
    }
    if (message.length)
        DBDrawText(message, NSMakeRect(24, y + 2, 1450, height - 3), height * .57, NSColor.whiteColor, NO,
                   NSTextAlignmentLeft, NO);
}

@end
