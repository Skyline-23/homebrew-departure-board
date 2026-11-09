#import "DrawingSupport.h"
#import "DepartureBoardView.h"
#import <CoreText/CoreText.h>

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
    if (mono)
        return [NSFont monospacedDigitSystemFontOfSize:size
                                                weight:bold ? NSFontWeightSemibold : NSFontWeightRegular];
    return [NSFont systemFontOfSize:size weight:bold ? NSFontWeightSemibold : NSFontWeightRegular];
}
void DBDrawText(NSString *text, NSRect rect, CGFloat size, NSColor *color, BOOL bold, NSTextAlignment align,
                BOOL mono) {
    DBDrawTextWithFont(text, rect, DBFont(size, bold, mono), color, align);
}
NSFont *DBNamedFont(NSString *name, CGFloat size) {
    return [NSFont fontWithName:name ?: @"ArialNarrow-Bold" size:size] ?: DBFont(size, YES, NO);
}
void DBDrawTextWithFont(NSString *text, NSRect rect, NSFont *font, NSColor *color, NSTextAlignment align) {
    if (!text.length || rect.size.width <= 0)
        return;
    NSMutableParagraphStyle *paragraph = NSMutableParagraphStyle.new;
    paragraph.alignment = align;
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    CGFloat size = font.pointSize;
    NSMutableDictionary *attrs = [@{
        NSFontAttributeName : font,
        NSForegroundColorAttributeName : color,
        NSParagraphStyleAttributeName : paragraph
    } mutableCopy];
    CGFloat measured = [text sizeWithAttributes:attrs].width;
    if (measured > rect.size.width) {
        font = [NSFont fontWithName:font.fontName size:MAX(size * .65, size * rect.size.width / measured)];
        attrs[NSFontAttributeName] = font;
    }
    CGFloat h = ceil(font.ascender - font.descender + font.leading);
    NSRect box =
        NSMakeRect(rect.origin.x, rect.origin.y + MAX(0, (rect.size.height - h) / 2), rect.size.width, h + 3);
    [text drawInRect:box withAttributes:attrs];
}
NSString *DBStatusText(NSString *key, NSString *language) {
    return DBBoardString([@"status." stringByAppendingString:key], language);
}
NSColor *DBStatusColor(NSString *status) {
    if ([status isEqual:@"cancelled"])
        return DBColor(@"ff7880");
    if ([status isEqual:@"delayed"] || [status isEqual:@"closing"])
        return DBColor(@"ffc65b");
    if ([status isEqual:@"boarding"] || [status isEqual:@"gate"])
        return DBColor(@"88e4bd");
    if ([status isEqual:@"departed"])
        return DBColor(@"7891a5");
    return DBColor(@"e5edf2");
}
