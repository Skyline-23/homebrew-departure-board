#import "DrawingSupport.h"
#import "DepartureBoardView.h"

NSColor *DBColor(NSString *hex) {

    unsigned value = 0;
    [[NSScanner scannerWithString:hex ?: @"ffffff"] scanHexInt:&value];
    return [NSColor colorWithSRGBRed:((value >> 16) & 255) / 255.0
                               green:((value >> 8) & 255) / 255.0
                                blue:(value & 255) / 255.0
                               alpha:1];
}

void DBFillRect(NSRect rect, NSColor *color) {

    [color setFill];
    NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
}

NSFont *DBFont(CGFloat size, BOOL bold, BOOL mono) {

    if (mono) {
        return [NSFont
            monospacedDigitSystemFontOfSize:size
                                     weight:bold ? NSFontWeightSemibold : NSFontWeightRegular];
    }
    return [NSFont systemFontOfSize:size weight:bold ? NSFontWeightSemibold : NSFontWeightRegular];
}

void DBDrawText(NSString *text, NSRect rect, CGFloat size, NSColor *color, BOOL bold,
                NSTextAlignment align, BOOL mono) {

    DBDrawTextWithFont(text, rect, DBFont(size, bold, mono), color, align);
}

NSFont *DBNamedFont(NSString *name, CGFloat size) {

    return [NSFont fontWithName:name ?: @"HelveticaNeue-Medium" size:size] ?: DBFont(size, YES, NO);
}

void DBDrawTextWithFont(NSString *text, NSRect rect, NSFont *font, NSColor *color,
                        NSTextAlignment align) {

    if (!text.length || rect.size.width <= 0) {
        return;
    }
    NSMutableParagraphStyle *paragraph = NSMutableParagraphStyle.new;
    paragraph.alignment = align;
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    CGFloat size = font.pointSize;
    NSMutableDictionary *attrs = [@{
        NSFontAttributeName : font,
        NSForegroundColorAttributeName : color,
        NSParagraphStyleAttributeName : paragraph
    } mutableCopy];
    // Keep one type size across a row. Long labels use an ellipsis instead of
    // making each destination or flight number a different visual size.
    CGFloat lineHeight = ceil(font.ascender - font.descender + font.leading);

    if (lineHeight > rect.size.height) {
        // Private system font names cannot be resolved with fontWithName:.
        // Reuse the descriptor so clocks retain their font when scaled down.
        font = [NSFont fontWithDescriptor:font.fontDescriptor
                                     size:size * rect.size.height / lineHeight]
                   ?: font;
        attrs[NSFontAttributeName] = font;
    }
    CGFloat h = ceil(font.ascender - font.descender + font.leading);
    NSRect box = NSMakeRect(rect.origin.x, rect.origin.y + MAX(0, (rect.size.height - h) / 2),
                            rect.size.width, h + 3);
    [text drawInRect:box withAttributes:attrs];
}

NSString *DBStatusText(NSString *key, NSString *language) {

    // A missing operational status must not be presented as an on-time flight.
    return DBBoardString([@"status." stringByAppendingString:key.length ? key : @"unknown"],
                         language);
}

NSColor *DBStatusColor(NSString *status) {

    if ([status isEqual:@"cancelled"]) {
        return DBColor(@"ff7880");
    }

    if ([status isEqual:@"delayed"] || [status isEqual:@"closing"]) {
        return DBColor(@"ffc65b");
    }

    if ([status isEqual:@"boarding"] || [status isEqual:@"gate"]) {
        return DBColor(@"88e4bd");
    }

    if ([status isEqual:@"departed"]) {
        return DBColor(@"7891a5");
    }
    return DBColor(@"e5edf2");
}

void DBDrawDepartureIcon(NSPoint point, CGFloat size, NSColor *color) {

    static NSCache *icons;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        icons = NSCache.new;
        icons.countLimit = 32;
        icons.totalCostLimit = 2 * 1024 * 1024;
    });
    NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    NSString *key =
        [NSString stringWithFormat:@"%.3f/%.3f/%.3f/%.3f", rgb.redComponent, rgb.greenComponent,
                                   rgb.blueComponent, rgb.alphaComponent];
    NSImage *icon = [icons objectForKey:key];

    if (!icon) {
        NSImage *symbol = [[NSImage imageWithSystemSymbolName:@"airplane.departure"
                                     accessibilityDescription:nil]
            imageWithSymbolConfiguration:[NSImageSymbolConfiguration
                                             configurationWithPointSize:128
                                                                 weight:NSFontWeightRegular]];

        if (!symbol) {
            return;
        }
        NSSize resolution = NSMakeSize(ceil(symbol.size.width), ceil(symbol.size.height));
        NSBitmapImageRep *bitmap =
            [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
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
        NSGraphicsContext.currentContext =
            [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
        NSRect rect = NSMakeRect(0, 0, resolution.width, resolution.height);
        [NSColor.clearColor setFill];
        NSRectFillUsingOperation(rect, NSCompositingOperationCopy);
        [symbol drawInRect:rect];
        [color setFill];
        NSRectFillUsingOperation(rect, NSCompositingOperationSourceIn);
        [NSGraphicsContext restoreGraphicsState];
        icon = [[NSImage alloc] initWithSize:resolution];
        [icon addRepresentation:bitmap];
        [icons setObject:icon
                  forKey:key
                    cost:(NSUInteger)(resolution.width * resolution.height * 4)];
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

void DBDrawAirlineLogo(NSImage *logo, NSRect bounds) {

    CGFloat scale = MIN(bounds.size.width / logo.size.width, bounds.size.height / logo.size.height);
    NSRect rect = NSMakeRect(NSMidX(bounds) - logo.size.width * scale / 2,
                             NSMidY(bounds) - logo.size.height * scale / 2, logo.size.width * scale,
                             logo.size.height * scale);
    [logo drawInRect:rect
              fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver
              fraction:1
        respectFlipped:YES
                 hints:nil];
}
