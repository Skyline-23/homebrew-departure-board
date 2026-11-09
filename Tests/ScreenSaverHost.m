#import "../Sources/DepartureBoardView.h"
#import "../Sources/LiveFlightStore.h"
#import "../Sources/AirlineLogoStore.h"
#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <fcntl.h>
#import <sys/file.h>
#import <unistd.h>

@interface DBBoardView (RenderingTests)
@property(nonatomic) NSTimeInterval startTime;
- (BOOL)updateAtDate:(NSDate *)date uptime:(NSTimeInterval)uptime;
- (NSInteger)airportRowCountForArea:(NSRect)area;
- (CGFloat)airportHeaderHeight:(NSRect)area;
@end

static BOOL VerifyContentDrivenRendering(DBBoardView *board, Class store) {
    board.locationCode = @"HND";
    board.languageMode = @"english";
    board.displayStyle = @"auto";
    board.useSampleData = NO;
    board.startTime = 0;
    board.reducedMotion = YES;
    Method method = class_getClassMethod(store, @selector(rowsForLocation:now:));
    IMP original = method_getImplementation(method);
    IMP mock = imp_implementationWithBlock(^NSArray *(id receiver, NSDictionary *location, NSDate *date) {
        return @[ @{ @"flight" : @((NSInteger)date.timeIntervalSince1970 / 4) } ];
    });
    method_setImplementation(method, mock);
    [board updateAtDate:[NSDate dateWithTimeIntervalSince1970:1800000005] uptime:40];
    BOOL unchanged = ![board updateAtDate:[NSDate dateWithTimeIntervalSince1970:1800000006] uptime:41] &&
                     board.preferredAnimationInterval == 1;
    BOOL codeshare = [board updateAtDate:[NSDate dateWithTimeIntervalSince1970:1800000008] uptime:43];
    BOOL pageChanged = [board updateAtDate:[NSDate dateWithTimeIntervalSince1970:1800000009] uptime:45];
    method_setImplementation(method, original);
    imp_removeBlock(mock);
    [board reloadSettings];
    if (!unchanged || !codeshare || !pageChanged)
        fprintf(stderr, "Content redraw check: unchanged=%d codeshare=%d page=%d\n",
                unchanged, codeshare, pageChanged);
    return unchanged && codeshare && pageChanged;
}

static BOOL VerifySharedRowsCache(Class store) {
    NSDictionary *flight = @{
        @"number" : @"NH 100", @"status" : @"Expected", @"scheduledUtc" : @"2026-11-09T06:00:00Z",
        @"destinationCode" : @"HKG", @"destinationName" : @"Hong Kong", @"gate" : @"101",
        @"variants" : @[
            @{ @"number" : @"NH 100", @"airline" : @"ANA" },
            @{ @"number" : @"UA 7000", @"airline" : @"United" }
        ]
    };
    __block NSDictionary *snapshot = @{
        @"fetchedAt" : @"2026-11-09T05:00:00Z", @"flights" : @[ flight ]
    };
    Method method = class_getClassMethod(store, @selector(cachedSnapshotForAirport:));
    IMP original = method_getImplementation(method);
    IMP mock = imp_implementationWithBlock(^NSDictionary *(id receiver, NSString *airport) {
        return snapshot;
    });
    method_setImplementation(method, mock);
    NSDictionary *location = @{ @"code" : @"HND", @"zone" : @"Asia/Tokyo" };
    NSDate *now = [NSISO8601DateFormatter.new dateFromString:@"2026-11-09T05:00:05Z"];
    NSArray *first = [store rowsForLocation:location now:now];
    NSArray *same = [store rowsForLocation:location now:[now dateByAddingTimeInterval:.5]];
    NSArray *rotated = [store rowsForLocation:location now:[now dateByAddingTimeInterval:4]];
    BOOL shared = first == same && first.count == 1;
    BOOL cycles = ![first[0][@"flight"] isEqual:rotated[0][@"flight"]];
    NSMutableDictionary *updated = [flight mutableCopy];
    updated[@"gate"] = @"102";
    snapshot = @{ @"fetchedAt" : @"2026-11-09T05:00:00Z", @"flights" : @[ updated ] };
    NSArray *fresh = [store rowsForLocation:location now:now];
    BOOL invalidated = [fresh[0][@"gate"] isEqual:@"102"];
    method_setImplementation(method, original);
    imp_removeBlock(mock);
    return shared && cycles && invalidated;
}

static BOOL VerifySnapshotConfiguration(DBBoardView *board) {
    NSDictionary *configuration = board.snapshotConfiguration;
    DBBoardView *copy = [[board.class alloc] initWithFrame:NSMakeRect(0, 0, 640, 360)];
    [copy applySnapshotConfiguration:configuration];
    return [copy.snapshotConfiguration isEqual:configuration];
}

static BOOL VerifyCompactScale(DBBoardView *board) {
    NSDictionary *saved = board.snapshotConfiguration;
    board.locationCode = @"ICN";
    board.density = 0;
    board.boardScale = .75;
    NSRect compact = NSMakeRect(0, 0, 1600 / .75, 900 / .75);
    NSInteger compactRows = [board airportRowCountForArea:compact];
    BOOL readable = compactRows >= 24 && compactRows <= 40 &&
                    [board airportHeaderHeight:compact] < compact.size.height * .18;
    board.boardScale = 1;
    NSInteger standardRows = [board airportRowCountForArea:NSMakeRect(0, 0, 1600, 900)];
    board.density = 16;
    BOOL manualRows = [board airportRowCountForArea:compact] == 16;
    [board applySnapshotConfiguration:saved];
    return readable && compactRows > standardRows && manualRows;
}

static BOOL VerifyAirlineLogos(void) {
    Class store = NSClassFromString(@"DBAirlineLogoStore");
    NSImage *tway = [store imageForCarrier:@"TW" icao:nil name:@"T'way Air"];
    NSImage *seoul = [store imageForCarrier:@"RS" icao:@"ASV" name:@"Air Seoul"];
    NSImage *premia = [store imageForCarrier:@"YP" icao:@"APZ" name:@"Air Premia"];
    NSImage *perimeter = [store imageForCarrier:@"YP" icao:@"PAG" name:@"Perimeter Aviation"];
    return tway && seoul && premia && perimeter && premia != perimeter &&
           tway.size.width > tway.size.height &&
           [store imageForCarrier:@"TW" icao:nil name:@"T'way Air"] == tway;
}

static BOOL VerifySystemFontScaling(void) {
    typedef void (*DrawText)(NSString *, NSRect, CGFloat, NSColor *, BOOL, NSTextAlignment, BOOL);
    NSBundle *bundle = [NSBundle bundleForClass:NSClassFromString(@"DBBoardView")];
    void *handle = dlopen(bundle.executablePath.fileSystemRepresentation, RTLD_NOW);
    DrawText draw = (DrawText)dlsym(handle, "DBDrawText");
    if (!draw)
        return NO;
    typedef NSString *(*StatusText)(NSString *, NSString *);
    StatusText statusText = (StatusText)dlsym(handle, "DBStatusText");
    if (!statusText || ![statusText(@"unknown", @"en") isEqual:@"Status unavailable"] ||
        !statusText(@"unknown", @"fr").length ||
        !statusText(@"boarding", @"en").length)
        return NO;
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:120
        pixelsHigh:24 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [NSColor.blackColor setFill];
    NSRectFill(NSMakeRect(0, 0, 120, 24));
    draw(@"12:34", NSMakeRect(0, 0, 120, 12), 40, NSColor.whiteColor, YES, NSTextAlignmentRight, YES);
    [NSGraphicsContext restoreGraphicsState];
    NSUInteger visible = 0;
    for (NSUInteger y = 0; y < 24; y++) {
        for (NSUInteger x = 0; x < 120; x++) {
            unsigned char *pixel = bitmap.bitmapData + y * bitmap.bytesPerRow + x * 4;
            visible += pixel[0] > 120 && pixel[1] > 120 && pixel[2] > 120;
        }
    }
    if (handle)
        dlclose(handle);
    return visible > 30;
}

static BOOL VerifyAvailabilityStates(Class store) {
    NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    NSURL *url = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"CDG.json"]];
    Method cache = class_getClassMethod(store, @selector(cachedSnapshotForAirport:));
    Method path = class_getClassMethod(store, NSSelectorFromString(@"cacheURLForAirport:"));
    IMP oldCache = method_getImplementation(cache), oldPath = method_getImplementation(path);
    __block NSDictionary *snapshot = @{@"fetchedAt":[NSISO8601DateFormatter.new stringFromDate:NSDate.date], @"flights":@[]};
    IMP mockCache = imp_implementationWithBlock(^id(id receiver, NSString *airport) { return snapshot; });
    IMP mockPath = imp_implementationWithBlock(^id(id receiver, NSString *airport) { return url; });
    method_setImplementation(cache, mockCache);
    method_setImplementation(path, mockPath);
    BOOL empty = [store availabilityForAirport:@"CDG"] == DBFlightAvailabilityEmpty;
    snapshot = @{@"fetchedAt":@"2020-01-01T00:00:00Z", @"flights":@[]};
    BOOL stale = [store availabilityForAirport:@"CDG"] == DBFlightAvailabilityUnavailable;
    int lock = open([url.path stringByAppendingString:@".lock"].fileSystemRepresentation, O_CREAT | O_RDWR, 0600);
    flock(lock, LOCK_EX);
    BOOL loading = [store availabilityForAirport:@"CDG"] == DBFlightAvailabilityLoading;
    flock(lock, LOCK_UN);
    close(lock);
    [@{@"status":@429, @"failures":@1} writeToFile:[url.path stringByAppendingString:@".retry.plist"] atomically:YES];
    BOOL limited = [store availabilityForAirport:@"CDG"] == DBFlightAvailabilityUnavailable &&
                   [store refreshFailureStatusForAirport:@"CDG"] == 429;
    method_setImplementation(cache, oldCache);
    method_setImplementation(path, oldPath);
    imp_removeBlock(mockCache);
    imp_removeBlock(mockPath);
    [NSFileManager.defaultManager removeItemAtPath:folder error:NULL];
    return empty && stale && loading && limited;
}

static BOOL VerifySharedRefreshLock(Class store) {
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [NSFileManager.defaultManager createDirectoryAtPath:directory
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:NULL];
    NSURL *cacheURL = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"flights.json"]];
    Method cacheMethod = class_getClassMethod(store, NSSelectorFromString(@"cacheURLForAirport:"));
    Method refreshMethod = class_getClassMethod(store, NSSelectorFromString(@"refreshLockedAirport:error:"));
    IMP cacheIMP = method_getImplementation(cacheMethod);
    IMP refreshIMP = method_getImplementation(refreshMethod);
    dispatch_semaphore_t entered = dispatch_semaphore_create(0);
    dispatch_semaphore_t release = dispatch_semaphore_create(0);
    dispatch_group_t requests = dispatch_group_create();
    __block NSInteger calls = 0;
    IMP mockCache = imp_implementationWithBlock(^NSURL *(id receiver, NSString *airport) {
        return cacheURL;
    });
    IMP mockRefresh = imp_implementationWithBlock(^BOOL(id receiver, NSString *airport, NSError **error) {
        @synchronized(store) {
            calls++;
        }
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(release, dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC));
        return YES;
    });
    method_setImplementation(cacheMethod, mockCache);
    method_setImplementation(refreshMethod, mockRefresh);
    dispatch_group_async(requests, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [store refreshAirport:@"ICN" error:NULL];
    });
    BOOL started = dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
    dispatch_semaphore_t secondDone = dispatch_semaphore_create(0);
    dispatch_group_async(requests, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [store refreshAirport:@"ICN" error:NULL];
        dispatch_semaphore_signal(secondDone);
    });
    BOOL reused = dispatch_semaphore_wait(secondDone, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)) == 0;
    dispatch_semaphore_signal(release);
    dispatch_semaphore_signal(release);
    dispatch_group_wait(requests, DISPATCH_TIME_FOREVER);
    method_setImplementation(cacheMethod, cacheIMP);
    method_setImplementation(refreshMethod, refreshIMP);
    imp_removeBlock(mockCache);
    imp_removeBlock(mockRefresh);
    [NSFileManager.defaultManager removeItemAtPath:directory error:NULL];
    return started && reused && calls == 1;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2)
            return 2;
        [NSApplication sharedApplication];
        NSBundle *bundle = [NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSError *error = nil;
        if (![bundle loadAndReturnError:&error]) {
            fprintf(stderr, "Could not load the screen saver bundle: %s\n",
                    error.localizedDescription.UTF8String);
            return 1;
        }
        Class principal = bundle.principalClass;
        if (![principal isSubclassOfClass:ScreenSaverView.class])
            return 1;
        ScreenSaverView *preview = [[principal alloc] initWithFrame:NSMakeRect(0, 0, 800, 450) isPreview:YES];
        [preview startAnimation];
        [preview animateOneFrame];
        NSWindow *sheet = preview.configureSheet;
        if (!preview.hasConfigureSheet || !sheet || preview.configureSheet != sheet ||
            preview.subviews.count != 1)
            return 1;
        if (![[sheet.contentView viewWithTag:301] isEnabled])
            return 1;
        DBBoardView *board = (DBBoardView *)preview.subviews.firstObject;
        NSWindow *editor = [board settingsWindowWithTarget:nil action:NULL];
        NSSecureTextField *token = [editor.contentView viewWithTag:202];
        if (!token.enabled || !token.editable || !token.selectable || !token.acceptsFirstResponder)
            return 1;
        if (![[editor.contentView viewWithTag:207] isEnabled])
            return 1;
        NSRect liveFrame = board.frame;
        NSString *snapshotPath = [NSTemporaryDirectory()
            stringByAppendingPathComponent:[NSString stringWithFormat:@"departure-snapshot-%@.png",
                                                                      NSUUID.UUID.UUIDString]];
        __block NSUInteger frameChanges = 0;
        board.postsFrameChangedNotifications = YES;
        id observer = [NSNotificationCenter.defaultCenter
            addObserverForName:NSViewFrameDidChangeNotification object:board queue:nil
            usingBlock:^(NSNotification *notification) { frameChanges++; }];
        BOOL snapshotSaved = [board writeSnapshot:snapshotPath size:NSMakeSize(1280, 720)];
        [NSNotificationCenter.defaultCenter removeObserver:observer];
        if (!snapshotSaved || !NSEqualRects(board.frame, liveFrame) || frameChanges != 0) {
            fprintf(stderr, "Snapshot check: saved=%d frame changes=%lu\n", snapshotSaved,
                    (unsigned long)frameChanges);
            return 1;
        }
        [NSFileManager.defaultManager removeItemAtPath:snapshotPath error:NULL];
        Class store = NSClassFromString(@"LiveFlightStore");
        NSDictionary *flight = @{
            @"number" : @"KE 703",
            @"status" : @"Boarding",
            @"departure" : @{@"scheduledTime" : @{@"utc" : @"2026-11-09 02:35Z"}, @"gate" : NSNull.null},
            @"arrival" : @{@"airport" : @{@"iata" : @"NRT", @"municipalityName" : @"Tokyo"}}
        };
        NSDictionary *snapshot = [store normalizeDepartures:@{
            @"departures" : @[ flight, flight ]
        }
                                                    airport:@"ICN"];
        if ([snapshot[@"flights"] count] != 1 ||
            ![snapshot[@"flights"][0][@"scheduledUtc"] isEqual:@"2026-11-09T02:35:00Z"] ||
            ![snapshot[@"flights"][0][@"gate"] isEqual:@""])
            return 1;
        NSMutableDictionary *shared = [flight mutableCopy];
        shared[@"number"] = @"DL 7951";
        shared[@"codeshareStatus"] = @"IsCodeshared";
        snapshot = [store normalizeDepartures:@{@"departures" : @[ flight, shared ]} airport:@"ICN"];
        if ([snapshot[@"flights"] count] != 1 || [snapshot[@"flights"][0][@"variants"] count] != 2)
            return 1;
        NSMutableDictionary *operating = [flight mutableCopy];
        operating[@"codeshareStatus"] = @"IsOperator";
        operating[@"departure"] = @{@"scheduledTime" : @{@"utc" : @"2026-11-09 02:35Z"}, @"gate" : @"21"};
        NSMutableDictionary *mislabelledAlias = [operating mutableCopy];
        mislabelledAlias[@"number"] = @"DL 7951";
        snapshot = [store normalizeDepartures:@{
            @"departures" : @[ operating, mislabelledAlias ]
        }
                                      airport:@"ICN"];
        if ([snapshot[@"flights"] count] != 1 || [snapshot[@"flights"][0][@"variants"] count] != 2)
            return 1;
        NSMutableDictionary *separateFlight = [operating mutableCopy];
        separateFlight[@"number"] = @"NH 100";
        separateFlight[@"departure"] =
            @{@"scheduledTime" : @{@"utc" : @"2026-11-09 02:35Z"},
              @"gate" : @"22"};
        snapshot = [store normalizeDepartures:@{
            @"departures" : @[ operating, separateFlight, shared ]
        }
                                      airport:@"ICN"];
        if ([snapshot[@"flights"] count] != 2)
            return 1;
        if (!VerifyCompactScale(board) || !VerifyAirlineLogos() || !VerifySystemFontScaling() ||
            !VerifyAvailabilityStates(store) ||
            !VerifySnapshotConfiguration(board) || !VerifySharedRowsCache(store) ||
            !VerifyContentDrivenRendering(board, store) || !VerifySharedRefreshLock(store))
            return 1;
        [preview stopAnimation];
        puts("The native screen saver loads, animates and creates its settings sheet.");
    }
    return 0;
}
