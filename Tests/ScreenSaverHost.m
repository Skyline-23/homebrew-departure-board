#import "../Sources/DepartureBoardView.h"
#import "../Sources/LiveFlightStore.h"
#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>
#import <objc/runtime.h>

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
        if (![board writeSnapshot:snapshotPath size:NSMakeSize(1280, 720)] ||
            !NSEqualRects(board.frame, liveFrame))
            return 1;
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
        if (!VerifySharedRefreshLock(store))
            return 1;
        [preview stopAnimation];
        puts("The native screen saver loads, animates and creates its settings sheet.");
    }
    return 0;
}
