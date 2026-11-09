#import <Cocoa/Cocoa.h>

NSColor *DBColor(NSString *hex);
void DBFillRect(NSRect rect, NSColor *color);
NSFont *DBFont(CGFloat size, BOOL bold, BOOL mono);
NSFont *DBNamedFont(NSString *name, CGFloat size);
void DBDrawTextWithFont(NSString *text, NSRect rect, NSFont *font, NSColor *color, NSTextAlignment align);
void DBDrawText(NSString *text, NSRect rect, CGFloat size, NSColor *color, BOOL bold, NSTextAlignment align,
                BOOL mono);
NSString *DBStatusText(NSString *key, NSString *language);
NSColor *DBStatusColor(NSString *status);
