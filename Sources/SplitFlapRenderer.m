#import "BoardViewInternal.h"
#import "DrawingSupport.h"

@implementation DBBoardView (SplitFlapRenderer)

- (void)flapText:(NSString *)text
             key:(NSString *)key
            rect:(NSRect)rect
           cells:(NSInteger)cells
           color:(NSColor *)ink {

    CGFloat cw = rect.size.width / cells, gap = MAX(1, cw * .065), fh = rect.size.height - 3;
    NSMutableArray *letters = NSMutableArray.new;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *s, NSRange r, NSRange e, BOOL *stop) {
                              [letters addObject:s];
                          }];
    double now = NSProcessInfo.processInfo.systemUptime;

    for (NSInteger i = 0; i < cells; i++) {
        NSString *glyph = i < (NSInteger)letters.count ? letters[i] : @" ";
        NSString *cellKey = [NSString stringWithFormat:@"%@-%ld", key, (long)i];
        NSDictionary *state = self.flapStates[cellKey];

        if (![state[@"target"] isEqual:glyph]) {
            state = @{
                @"old" : state[@"target"] ?: @" ",
                @"target" : glyph,
                @"start" : @(now + i * .008)
            };
            self.flapStates[cellKey] = state;
            // Keep the final clean frame even if the next timer fires late.

            if (!self.referenceDate && !self.reducedMotion) {
                self.flapWasAnimating = YES;
            }
        }
        NSRect c = NSMakeRect(rect.origin.x + i * cw, rect.origin.y, cw - gap, fh);
        NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:DBColor(@"33373b")
                                                             endingColor:DBColor(@"202428")];
        [gradient drawInRect:c angle:90];
        BOOL moving = !self.referenceDate && !self.reducedMotion &&
                      now - [state[@"start"] doubleValue] < DBFlapTransitionDuration &&
                      now >= [state[@"start"] doubleValue];
        NSString *shown = glyph;
        double progress = now - [state[@"start"] doubleValue];

        if (moving && progress < .42 && [glyph canBeConvertedToEncoding:NSASCIIStringEncoding]) {
            NSString *alphabet = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
            shown = [alphabet
                substringWithRange:NSMakeRange(
                                       ((NSInteger)(progress * 65) + i * 3) % alphabet.length, 1)];
        }
        NSRect gr = NSInsetRect(c, 1, -1);
        CGFloat size = MIN(cw * 1.10, fh * .79);
        DBDrawText(shown, gr, size, ink, YES, NSTextAlignmentCenter, NO);

        if (moving) {
            double phase = fmod(progress * 10, 1.0);
            CGFloat strip = fh * .48 * sin(phase * M_PI);
            DBFillRect(NSMakeRect(c.origin.x, c.origin.y + fh / 2 - strip, c.size.width, strip),
                       [NSColor colorWithWhite:0 alpha:.22]);
        }
        DBFillRect(NSMakeRect(c.origin.x, c.origin.y + floor(fh / 2), c.size.width, 1.6),
                   DBColor(@"090b0d"));
        DBFillRect(NSMakeRect(c.origin.x, c.origin.y + 1, c.size.width, 1),
                   [NSColor colorWithWhite:1 alpha:.05]);
    }
}

- (void)drawFlapBoard:(NSRect)area {

    DBFillRect(area, DBColor(@"111416"));
    [self drawFlapHeader:area];
    NSArray *labels = @[ @"TIME", @"DESTINATION", @"AIRLINE / FLIGHT", @"GATE", @"REMARKS" ];
    CGFloat xs[] = {34, 196, 760, 1085, 1208};
    CGFloat widths[] = {142, 541, 304, 100, 356};
    CGFloat horizontal = area.size.width / 1600;

    for (NSInteger index = 0; index < 5; index++) {
        xs[index] *= horizontal;
        widths[index] *= horizontal;
    }

    for (int j = 0; j < 5; j++) {
        DBDrawText(labels[j], NSMakeRect(xs[j], 126, widths[j], 26), 16, DBColor(@"9da8aa"), YES,
                   NSTextAlignmentLeft, NO);
    }
    NSInteger count = self.density > 0 ? MAX(6, MIN(32, self.density))
                                       : MIN(32, (NSInteger)ceil(16 / self.boardScale));
    CGFloat rowH = (area.size.height - 218) / count;

    for (NSInteger i = 0; i < count; i++) {
        if ((NSUInteger)i >= self.rows.count) {
            break;
        }
        NSDictionary *row = self.rows[i];
        CGFloat y = 167 + i * rowH;
        NSArray *texts = @[
            row[@"time"], [DBLocalized(row[@"destination"], self.currentLanguage) uppercaseString],
            row[@"flight"], row[@"gate"],
            [DBStatusText(row[@"state"], self.currentLanguage) uppercaseString]
        ];
        NSInteger cells[] = {5, 20, 10, 3, 15};

        for (int j = 0; j < 5; j++) {
            NSColor *ink = j == 0   ? DBColor(@"ffdc64")
                           : j == 4 ? DBStatusColor(row[@"state"])
                                    : DBColor(@"e8e7df");
            [self flapText:texts[j]
                       key:[NSString stringWithFormat:@"%ld/%d", (long)i, j]
                      rect:NSMakeRect(xs[j], y, widths[j], rowH - 9)
                     cells:cells[j]
                     color:ink];
        }
    }
    [self drawAirportFooter:area];
}

@end
