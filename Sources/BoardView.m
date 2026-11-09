#import "BoardViewInternal.h"
#import "DrawingSupport.h"
#import "LiveFlightStore.h"
#import "SettingsStore.h"
#import <QuartzCore/QuartzCore.h>

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
        self.pageCycle = -1;
        self.flapStates = NSMutableDictionary.new;
        [self reloadSettings];
    }
    return self;
}

- (void)viewDidMoveToWindow {

    [super viewDidMoveToWindow];

    if (self.window) {
        self.wantsLayer = YES;
        self.layer.contentsFormat = kCAContentsFormatRGBA8Uint;
        self.layer.opaque = YES;
    }
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
    self.boardScale = prefs[@"boardScale"] ? [prefs[@"boardScale"] doubleValue] : .75;
    self.useSampleData = [prefs[@"sampleData"] boolValue];
    self.lastRenderedSecond = -1;
    self.pageCycle = -1;
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
        @"boardScale" : @(self.boardScale),
        @"sampleData" : @(self.useSampleData)
    }];
    [DBSettingsStore saveSettings:settings replacementAPIKey:nil error:NULL];
    self.loadedSettings = settings;
}

- (void)setBoardScale:(double)scale {

    _boardScale = isfinite(scale) ? MAX(.5, MIN(1, scale)) : .75;
    self.lastRenderedSecond = -1;
    self.needsDisplay = YES;
}

- (void)setLocationCode:(NSString *)locationCode {

    _locationCode = [locationCode copy];
    self.location = DBLocation(locationCode);
    self.airportAdapter = DBAirportAdapterForLocation(self.location);
    self.startTime = NSProcessInfo.processInfo.systemUptime;
    self.lastRenderedSecond = -1;
    self.pageCycle = -1;
    [self.flapStates removeAllObjects];
}

- (NSString *)effectiveStyle {

    if ([self.location[@"kind"] isEqual:@"rail"]) {
        return self.location[@"preset"];
    }

    if ([self.displayStyle isEqual:@"flap"]) {
        return @"flap";
    }
    return self.location[@"preset"];
}

- (BOOL)hasActiveFlapAnimationAt:(NSTimeInterval)uptime {

    for (NSDictionary *cell in self.flapStates.objectEnumerator) {
        if (uptime - [cell[@"start"] doubleValue] < DBFlapTransitionDuration) {
            return YES;
        }
    }
    return NO;
}

- (NSTimeInterval)preferredAnimationInterval {

    BOOL flap = [[self effectiveStyle] isEqual:@"flap"] && !self.reducedMotion;

    if (!flap) {
        return 1;
    }
    BOOL moving =
        self.needsDisplay || [self hasActiveFlapAnimationAt:NSProcessInfo.processInfo.systemUptime];
    return moving ? 1.0 / 30.0 : 1.0;
}

- (void)tick {

    [self updateAtDate:self.referenceDate ?: NSDate.date
                uptime:NSProcessInfo.processInfo.systemUptime];
}

- (BOOL)updateAtDate:(NSDate *)now uptime:(NSTimeInterval)uptime {

    NSTimeInterval second = floor(now.timeIntervalSince1970);
    BOOL flap = [[self effectiveStyle] isEqual:@"flap"];
    BOOL animating = flap && !self.reducedMotion && [self hasActiveFlapAnimationAt:uptime];
    BOOL finishedAnimation = self.flapWasAnimating && !animating;
    self.flapWasAnimating = animating;

    if (second != self.lastRenderedSecond || animating || finishedAnimation || self.referenceDate) {
        if (!self.referenceDate && second != self.lastRenderedSecond &&
            ![DBSettingsStore.settings isEqual:self.loadedSettings]) {
            [self reloadSettings];
            return YES;
        }
        NSString *native = self.location[@"lang"] ?: @"en";
        NSInteger cycle = (NSInteger)floor((uptime - self.startTime) / 12.0);
        NSString *language = [self.languageMode isEqual:@"english"]  ? @"en"
                             : [self.languageMode isEqual:@"native"] ? native
                             : cycle % 2                             ? native
                                                                     : @"en";
        NSArray *rows = self.rows;

        if (second != self.lastRenderedSecond || self.referenceDate || !rows) {
            rows = self.referenceDate || self.useSampleData
                       ? DBDepartures(self.location, now, 128)
                       : [LiveFlightStore rowsForLocation:self.location now:now];
        }
        NSString *emptyMessage = @"data.noDepartures";

        if (!rows.count && !self.referenceDate && !self.useSampleData) {
            switch ([LiveFlightStore availabilityForAirport:self.locationCode]) {
            case DBFlightAvailabilityLoading:
                emptyMessage = @"data.loading";
                break;
            case DBFlightAvailabilityUnavailable:
                emptyMessage = @"data.unavailable";
                break;
            case DBFlightAvailabilityConfigurationRequired:
                emptyMessage = @"data.configure";
                break;
            case DBFlightAvailabilityEmpty:
                break;
            }
        }
        NSInteger page = (NSInteger)floor((uptime - self.startTime) / 15.0);
        NSString *style = [self effectiveStyle];
        BOOL secondsClock = [style isEqual:@"victoria"] || [style isEqual:@"sydney"];
        BOOL changed = self.lastRenderedSecond < 0 || self.referenceDate || animating ||
                       finishedAnimation || secondsClock ||
                       floor(second / 60) != floor(self.lastRenderedSecond / 60) ||
                       ![language isEqual:self.currentLanguage] || ![rows isEqual:self.rows] ||
                       ![emptyMessage isEqual:self.emptyMessageKey] ||
                       ([self.location[@"kind"] isEqual:@"airport"] && page != self.pageCycle);
        self.lastRenderedSecond = second;
        self.boardDate = now;
        self.currentLanguage = language;
        self.emptyMessageKey = emptyMessage;
        self.rows = rows;
        self.pageCycle = page;

        if (changed) {
            self.needsDisplay = YES;
        }
        return changed;
    }
    return NO;
}

- (void)drawRect:(NSRect)dirtyRect {

    [self drawBoardInRect:self.bounds];
}

- (void)drawBoardInRect:(NSRect)bounds {

    if (!self.boardDate) {
        [self tick];
    }
    DBFillRect(bounds, DBColor(@"030508"));

    if (bounds.size.width < 1 || bounds.size.height < 1) {
        return;
    }
    NSString *style = [self effectiveStyle];
    CGFloat w = 1600 / self.boardScale;
    CGFloat h = w * bounds.size.height / bounds.size.width;
    {
        CGFloat scale = bounds.size.width / w;
        [NSGraphicsContext saveGraphicsState];
        NSRectClip(bounds);
        NSAffineTransform *transform = NSAffineTransform.transform;
        [transform scaleBy:scale];
        [transform concat];
        NSRect area = NSMakeRect(0, 0, w, h);
        DBFillRect(area, DBColor(self.location[@"bg"]));

        if ([style isEqual:@"flap"]) {
            [self drawFlapBoard:area];
        } else if ([style isEqual:@"victoria"] || [style isEqual:@"sydney"]) {
            [self drawRailCards:area];
        } else if ([self.location[@"kind"] isEqual:@"rail"]) {
            [self drawRailTable:area];
        } else {
            [self drawAirport:area];
        }
        CGFloat darkness = 1 - MAX(.35, MIN(1, self.brightness));

        if (darkness > 0) {
            DBFillRect(area, [NSColor colorWithWhite:0 alpha:darkness]);
        }
        [NSGraphicsContext restoreGraphicsState];
    }
}

- (NSDictionary *)snapshotConfiguration {

    return @{
        @"location" : self.locationCode ?: @"ICN",
        @"style" : self.displayStyle ?: @"auto",
        @"language" : self.languageMode ?: @"alternate",
        @"reduceMotion" : @(self.reducedMotion),
        @"density" : @(self.density),
        @"brightness" : @(self.brightness),
        @"boardScale" : @(self.boardScale),
        @"sampleData" : @(self.useSampleData),
        @"startTime" : @(self.startTime)
    };
}

- (void)applySnapshotConfiguration:(NSDictionary *)configuration {

    self.locationCode = configuration[@"location"] ?: self.locationCode;
    self.displayStyle = configuration[@"style"] ?: self.displayStyle;
    self.languageMode = configuration[@"language"] ?: self.languageMode;
    self.reducedMotion = [configuration[@"reduceMotion"] boolValue];
    self.density = [configuration[@"density"] integerValue];
    self.brightness = [configuration[@"brightness"] doubleValue];
    self.boardScale =
        configuration[@"boardScale"] ? [configuration[@"boardScale"] doubleValue] : .75;
    self.useSampleData = [configuration[@"sampleData"] boolValue];
    self.startTime = [configuration[@"startTime"] doubleValue];
    self.lastRenderedSecond = -1;
}

- (BOOL)writeSnapshot:(NSString *)path size:(NSSize)size {

    @autoreleasepool {
        [self tick];
        NSBitmapImageRep *rep =
            [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
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
        NSGraphicsContext *bitmapContext =
            [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
        NSGraphicsContext.currentContext =
            [NSGraphicsContext graphicsContextWithCGContext:bitmapContext.CGContext flipped:YES];
        NSAffineTransform *flip = NSAffineTransform.transform;
        [flip translateXBy:0 yBy:size.height];
        [flip scaleXBy:1 yBy:-1];
        [flip concat];
        // Render directly into the bitmap; resizing a live Retina view allocates
        // oversized backing surfaces in WindowServer.
        [self drawBoardInRect:NSMakeRect(0, 0, size.width, size.height)];
        [NSGraphicsContext restoreGraphicsState];
        BOOL saved = [[rep representationUsingType:NSBitmapImageFileTypePNG
                                        properties:@{}] writeToFile:path atomically:YES];
        return saved;
    }
}

@end
