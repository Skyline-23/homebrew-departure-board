#import <Cocoa/Cocoa.h>

NSColor *DBColor(NSString *hex);
void DBFillRect(NSRect rect, NSColor *color);
NSFont *DBFont(CGFloat size, BOOL bold, BOOL mono);
void DBDrawText(NSString *text, NSRect rect, CGFloat size, NSColor *color, BOOL bold, NSTextAlignment align,
                BOOL mono);
NSString *DBStatusText(NSString *key, NSString *language);
NSColor *DBStatusColor(NSString *status);
