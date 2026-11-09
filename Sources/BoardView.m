#import "BoardViewInternal.h"
#import "DrawingSupport.h"
#import "LiveFlightStore.h"
#import "SettingsStore.h"
#import <CoreText/CoreText.h>

@implementation DBBoardView

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)isOpaque {
    return YES;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.startTime = NSProcessInfo.processInfo.systemUptime;
        self.lastRenderedSecond = -1;
        self.languageCycle = -1;
        self.flapStates = NSMutableDictionary.new;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSURL *font = [[NSBundle bundleForClass:self.class] URLForResource:@"texgyreheroscn-bold"
                                                                 withExtension:@"otf"];
            if (font)
                CTFontManagerRegisterFontsForURL((__bridge CFURLRef)font, kCTFontManagerScopeProcess, NULL);
        });
        [self reloadSettings];
    }
    return self;
}

- (void)reloadSettings {
    NSDictionary *prefs = DBSettingsStore.settings;
    self.loadedSettings = prefs;
    self.locationCode = prefs[@"location"] ?: @"ICN";
    self.displayStyle = prefs[@"style"] ?: @"auto";
    self.languageMode = prefs[@"language"] ?: @"alternate";
    self.reducedMotion = [prefs[@"reduceMotion"] boolValue];
    self.density = prefs[@"density"] ? [prefs[@"density"] integerValue] : 0;
    self.brightness = prefs[@"brightness"] ? [prefs[@"brightness"] doubleValue] : 1.0;
    self.useSampleData = [prefs[@"sampleData"] boolValue];
    self.lastRenderedSecond = -1;
    self.languageCycle = -1;
    self.startTime = NSProcessInfo.processInfo.systemUptime;
    [self.flapStates removeAllObjects];
    [self tick];
}

- (void)saveSettings {
    NSMutableDictionary *settings = [DBSettingsStore.settings mutableCopy];
    [settings addEntriesFromDictionary:@{
        @"location" : self.locationCode ?: @"ICN",
        @"style" : self.displayStyle ?: @"auto",
        @"language" : self.languageMode ?: @"alternate",
        @"reduceMotion" : @(self.reducedMotion),
        @"density" : @(self.density),
        @"brightness" : @(self.brightness),
        @"sampleData" : @(self.useSampleData)
    }];
    [DBSettingsStore saveSettings:settings replacementAPIKey:nil error:NULL];
    self.loadedSettings = settings;
}

- (void)setLocationCode:(NSString *)locationCode {
    _locationCode = [locationCode copy];
    self.location = DBLocation(locationCode);
    self.startTime = NSProcessInfo.processInfo.systemUptime;
    self.lastRenderedSecond = -1;
    self.languageCycle = -1;
    [self.flapStates removeAllObjects];
}

- (NSString *)effectiveStyle {
    if ([self.location[@"kind"] isEqual:@"rail"])
        return self.location[@"preset"];
    if ([self.displayStyle isEqual:@"flap"])
        return @"flap";
    if ([self.displayStyle isEqual:@"lcd"])
        return self.location[@"preset"];
    return self.location[@"preset"];
}

- (void)tick {
    NSDate *now = self.referenceDate ?: NSDate.date;
    NSTimeInterval second = floor(now.timeIntervalSince1970);
    BOOL flap = [[self effectiveStyle] isEqual:@"flap"];
    BOOL animating = NO;
    if (flap && !self.reducedMotion) {
        double uptime = NSProcessInfo.processInfo.systemUptime;
        for (NSDictionary *cell in self.flapStates.allValues)
            if (uptime - [cell[@"start"] doubleValue] < 1.7) {
                animating = YES;
                break;
            }
    }
    if (second != self.lastRenderedSecond || animating || self.referenceDate) {
        if (!self.referenceDate && second != self.lastRenderedSecond &&
            ![DBSettingsStore.settings isEqual:self.loadedSettings]) {
            [self reloadSettings];
            return;
        }
        self.lastRenderedSecond = second;
        self.boardDate = now;
        NSString *native = self.location[@"lang"] ?: @"en";
        NSInteger cycle = (NSInteger)floor((NSProcessInfo.processInfo.systemUptime - self.startTime) / 12.0);
        self.currentLanguage = [self.languageMode isEqual:@"english"]  ? @"en"
                               : [self.languageMode isEqual:@"native"] ? native
                               : cycle % 2                             ? native
                                                                       : @"en";
        self.rows = self.referenceDate || self.useSampleData
                        ? DBDepartures(self.location, now, 128)
                        : [LiveFlightStore rowsForLocation:self.location now:now];
        self.languageCycle = cycle;
        self.needsDisplay = YES;
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    if (!self.boardDate)
        [self tick];
    DBFillRect(self.bounds, DBColor(@"030508"));
    if (self.bounds.size.width < 1 || self.bounds.size.height < 1)
        return;
    NSString *style = [self effectiveStyle];
    CGFloat w = 1600, h = w * self.bounds.size.height / self.bounds.size.width;
    {
        CGFloat scale = self.bounds.size.width / w;
        [NSGraphicsContext saveGraphicsState];
        NSRectClip(self.bounds);
        NSAffineTransform *transform = NSAffineTransform.transform;
        [transform scaleBy:scale];
        [transform concat];
        NSRect area = NSMakeRect(0, 0, w, h);
        DBFillRect(area, DBColor(self.location[@"bg"]));
        if ([style isEqual:@"flap"])
            [self drawFlapBoard:area];
        else if ([style isEqual:@"victoria"] || [style isEqual:@"sydney"])
            [self drawRailCards:area];
        else if ([self.location[@"kind"] isEqual:@"rail"])
            [self drawRailTable:area];
        else
            [self drawAirport:area];
        CGFloat darkness = 1 - MAX(.35, MIN(1, self.brightness));
        if (darkness > 0)
            DBFillRect(area, [NSColor colorWithWhite:0 alpha:darkness]);
        [NSGraphicsContext restoreGraphicsState];
    }
}

- (BOOL)writeSnapshot:(NSString *)path size:(NSSize)size {
    NSRect originalFrame = self.frame;
    [self setFrameSize:size];
    [self tick];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                    pixelsWide:(NSInteger)size.width
                                                                    pixelsHigh:(NSInteger)size.height
                                                                 bitsPerSample:8
                                                               samplesPerPixel:4
                                                                      hasAlpha:YES
                                                                      isPlanar:NO
                                                                colorSpaceName:NSDeviceRGBColorSpace
                                                                   bytesPerRow:0
                                                                  bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext *bitmapContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:bitmapContext.CGContext
                                                                               flipped:YES];
    NSAffineTransform *flip = NSAffineTransform.transform;
    [flip translateXBy:0 yBy:size.height];
    [flip scaleXBy:1 yBy:-1];
    [flip concat];
    [self drawRect:self.bounds];
    [NSGraphicsContext restoreGraphicsState];
    BOOL saved = [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path
                                                                                         atomically:YES];
    self.frame = originalFrame;
    self.needsDisplay = YES;
    return saved;
}

@end
