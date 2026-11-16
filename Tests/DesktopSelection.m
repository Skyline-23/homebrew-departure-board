#import "DepartureBoardView.h"
#import "DesktopController.h"
#import "LiveFlightStore.h"
#import "SettingsStore.h"
#import "WallpaperRenderer.h"
#import <objc/runtime.h>
#import <unistd.h>

@interface DBSettingsStore (DesktopSelectionTests)
+ (NSString *)identifierForScreen:(NSScreen *)screen;
+ (BOOL)desktopIncludesScreen:(NSScreen *)screen settings:(NSDictionary *)settings;
@end

static NSDictionary *testSettings;
static NSMutableDictionary *wallpapers;
static NSUInteger wallpaperWrites;

static void ReplaceClassMethod(Class cls, SEL selector, id block) {

    method_setImplementation(class_getClassMethod(cls, selector),
                             imp_implementationWithBlock(block));
}

@interface DBTestRunningApplication : NSObject
- (pid_t)processIdentifier;
- (BOOL)isTerminated;
@end

@implementation DBTestRunningApplication

- (pid_t)processIdentifier {

    return getpid() + 1;
}

- (BOOL)isTerminated {

    return NO;
}

@end

@interface DBTestDesktopController : DBDesktopController
@end

@implementation DBTestDesktopController

- (void)updateSystemWallpapersWithCompletion:(void (^)(BOOL))completion {

    if (completion) {
        completion(YES);
    }
}

@end

int main(int argc, const char *argv[]) {

    @autoreleasepool {
        assert(argc == 3);
        BOOL singleMonitor = strcmp(argv[2], "single") == 0;
        assert(singleMonitor || strcmp(argv[2], "connected") == 0);
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        NSString *testHome = [NSString stringWithUTF8String:argv[1]];
        testSettings = @{@"sampleData" : @YES, @"desktopEnabled" : @YES};
        ReplaceClassMethod(DBSettingsStore.class, @selector(settings), ^id(id cls) {
            return testSettings;
        });
        ReplaceClassMethod(
            DBSettingsStore.class, @selector(submitSettings:replacementAPIKey:completion:),
            ^(id cls, NSDictionary *settings, NSString *key, void (^completion)(NSError *)) {
                testSettings = [settings copy];
                completion(nil);
            });
        ReplaceClassMethod(LiveFlightStore.class, @selector(userHome), ^id(id cls) {
            return testHome;
        });
        ReplaceClassMethod(LiveFlightStore.class, @selector(APIKey), ^id(id cls) {
            return nil;
        });
        ReplaceClassMethod(LiveFlightStore.class, @selector(cachedSnapshotForAirport:),
                           ^id(id cls, NSString *airport) {
                               return nil;
                           });
        NSArray<NSScreen *> *available = NSScreen.screens;
        assert(available.count > 0);
        NSArray<NSScreen *> *screens = [available
            subarrayWithRange:NSMakeRange(0, singleMonitor ? 1 : MIN(2, available.count))];
        __block NSArray<NSScreen *> *connected = screens;
        ReplaceClassMethod(NSScreen.class, @selector(screens), ^id(id cls) {
            return connected;
        });
        assert(screens.count > 0);
        assert([DBSettingsStore respondsToSelector:@selector(desktopIncludesScreen:settings:)] &&
               "Per-display wallpaper selection is not implemented");
        NSScreen *first = screens.firstObject;
        NSString *identifier = [DBSettingsStore identifierForScreen:first];
        assert(identifier.length > 0);
        assert([identifier isEqual:[DBWallpaperRenderer identifierForScreen:first]]);
        assert([DBSettingsStore desktopIncludesScreen:first settings:@{}]);
        assert([DBSettingsStore desktopIncludesScreen:first
                                             settings:@{
                                                 @"desktopExcludedDisplays" : @[]
                                             }]);
        assert([DBSettingsStore desktopIncludesScreen:first
                                             settings:@{
                                                 @"desktopExcludedDisplays" : @42
                                             }]);
        assert(![DBSettingsStore desktopIncludesScreen:first
                                              settings:@{
                                                  @"desktopExcludedDisplays" : @[ identifier ]
                                              }]);

        wallpapers = NSMutableDictionary.new;
        NSMutableDictionary *originals = NSMutableDictionary.new;
        NSURL *originalURL =
            [NSURL fileURLWithPath:[testHome stringByAppendingPathComponent:@"original.png"]];
        NSURL *boardURL =
            [NSURL fileURLWithPath:[DBWallpaperRenderer.rootPath
                                       stringByAppendingPathComponent:@"Displays/board.png"]];

        for (NSScreen *screen in screens) {
            NSString *key = [DBSettingsStore identifierForScreen:screen];
            wallpapers[key] = boardURL;
            originals[key] = @{@"url" : originalURL.absoluteString};
        }
        [NSFileManager.defaultManager createDirectoryAtPath:DBWallpaperRenderer.rootPath
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:NULL];
        [originals writeToFile:[DBWallpaperRenderer.rootPath
                                   stringByAppendingPathComponent:@"Originals.plist"]
                    atomically:YES];
        method_setImplementation(
            class_getInstanceMethod(NSWorkspace.class, @selector(desktopImageURLForScreen:)),
            imp_implementationWithBlock(^id(id workspace, NSScreen *screen) {
                return wallpapers[[DBSettingsStore identifierForScreen:screen]];
            }));
        method_setImplementation(
            class_getInstanceMethod(NSWorkspace.class,
                                    @selector(setDesktopImageURL:forScreen:options:error:)),
            imp_implementationWithBlock(^BOOL(id workspace, NSURL *url, NSScreen *screen,
                                              NSDictionary *options, NSError **error) {
                wallpapers[[DBSettingsStore identifierForScreen:screen]] = url;
                wallpaperWrites++;
                return YES;
            }));
        method_setImplementation(
            class_getInstanceMethod(NSWorkspace.class, @selector(desktopImageOptionsForScreen:)),
            imp_implementationWithBlock(^id(id workspace, NSScreen *screen) {
                return @{};
            }));

        DBTestDesktopController *desktop = DBTestDesktopController.new;
        [desktop refresh];
        assert([[desktop valueForKey:@"windows"] count] == screens.count);
        testSettings = @{
            @"sampleData" : @YES,
            @"desktopEnabled" : @YES,
            @"desktopExcludedDisplays" : @[ identifier, @"disconnected-display" ]
        };
        [desktop refresh];
        assert([[desktop valueForKey:@"windows"] count] == screens.count - 1);
        assert([wallpapers[identifier] isEqual:originalURL]);
        assert(wallpaperWrites == 1);

        for (NSWindow *window in [desktop valueForKey:@"windows"]) {
            assert(![[DBSettingsStore identifierForScreen:window.screen] isEqual:identifier]);
        }
        DBBoardView *board = [[DBBoardView alloc] initWithFrame:NSMakeRect(0, 0, 640, 480)];
        NSWindow *editor = [board settingsWindowWithTarget:nil action:NULL];
        NSStackView *choices = [editor.contentView viewWithTag:211];
        assert(choices.arrangedSubviews.count == screens.count);
        NSString *preview = NSProcessInfo.processInfo.environment[@"DB_TEST_SETTINGS_SNAPSHOT"];

        if (preview) {
            [editor setFrame:NSMakeRect(0, 0, 720, 1100) display:NO];
            [editor.contentView layoutSubtreeIfNeeded];
            NSBitmapImageRep *image = [editor.contentView
                bitmapImageRepForCachingDisplayInRect:editor.contentView.bounds];
            [editor.contentView cacheDisplayInRect:editor.contentView.bounds
                                  toBitmapImageRep:image];
            assert([[image representationUsingType:NSBitmapImageFileTypePNG
                                        properties:@{}] writeToFile:preview atomically:YES]);
        }

        for (NSButton *choice in choices.arrangedSubviews) {
            assert(choice.title.length > 0 && choice.identifier.length > 0);
            BOOL excluded = [choice.identifier isEqual:identifier];
            assert((choice.state == NSControlStateValueOff) == excluded);
            choice.state = NSControlStateValueOn;
        }
        __block BOOL saved = NO;
        [board applySettingsFromWindow:editor
                            completion:^(BOOL success) {
                                saved = success;
                            }];
        assert(saved);
        assert([testSettings[@"desktopExcludedDisplays"] isEqual:@[ @"disconnected-display" ]]);
        [desktop refresh];
        assert(desktop.hasDesktopWindows);
        assert([[desktop valueForKey:@"windows"] count] == screens.count);
        connected = @[];
        [desktop refresh];
        assert(!desktop.hasDesktopWindows);
        connected = [[screens reverseObjectEnumerator] allObjects];
        [desktop refresh];
        assert([[desktop valueForKey:@"windows"] count] == screens.count);
        connected = screens;
        [desktop refresh];
        assert([[desktop valueForKey:@"windows"] count] == screens.count);
        [editor close];

        if (screens.count == 2) {
            NSScreen *second = screens[1];
            NSString *secondIdentifier = [DBSettingsStore identifierForScreen:second];
            testSettings = @{
                @"sampleData" : @YES,
                @"desktopEnabled" : @YES,
                @"desktopExcludedDisplays" : @[ secondIdentifier, @"disconnected-display" ]
            };
            [desktop refresh];
            NSArray<NSWindow *> *windows = [desktop valueForKey:@"windows"];
            assert(windows.count == 1);
            NSWindow *remainingWindow = windows.firstObject;
            assert(
                [[DBSettingsStore identifierForScreen:remainingWindow.screen] isEqual:identifier]);
            connected = @[ first ];
            [desktop refresh];
            assert([[desktop valueForKey:@"windows"] count] == 1);
            assert([[desktop valueForKey:@"windows"] firstObject] == remainingWindow);

            NSWindow *singleEditor = [board settingsWindowWithTarget:nil action:NULL];
            NSStackView *singleChoices = [singleEditor.contentView viewWithTag:211];
            assert(singleChoices.arrangedSubviews.count == 1);
            NSButton *singleChoice = (NSButton *)singleChoices.arrangedSubviews.firstObject;
            assert([singleChoice.identifier isEqual:identifier]);
            assert(singleChoice.state == NSControlStateValueOn);
            saved = NO;
            [board applySettingsFromWindow:singleEditor
                                completion:^(BOOL success) {
                                    saved = success;
                                }];
            assert(saved);
            assert(([testSettings[@"desktopExcludedDisplays"]
                isEqual:@[ secondIdentifier, @"disconnected-display" ]]));
            [singleEditor close];

            connected = screens;
            [desktop refresh];
            assert([[desktop valueForKey:@"windows"] count] == 1);
            assert([[desktop valueForKey:@"windows"] firstObject] == remainingWindow);
            NSWindow *dualEditor = [board settingsWindowWithTarget:nil action:NULL];
            NSStackView *dualChoices = [dualEditor.contentView viewWithTag:211];
            assert(dualChoices.arrangedSubviews.count == 2);

            for (NSButton *choice in dualChoices.arrangedSubviews) {
                assert((choice.state == NSControlStateValueOff) ==
                       [choice.identifier isEqual:secondIdentifier]);
                choice.state = NSControlStateValueOn;
            }
            [board applySettingsFromWindow:dualEditor
                                completion:^(BOOL success) {
                                    saved = success;
                                }];
            assert(saved);
            [dualEditor close];
            [desktop refresh];
            assert([[desktop valueForKey:@"windows"] count] == 2);

            for (NSScreen *remaining in screens) {
                connected = @[ remaining ];
                [desktop refresh];
                windows = [desktop valueForKey:@"windows"];
                assert(windows.count == 1);
                assert([[DBSettingsStore identifierForScreen:windows.firstObject.screen]
                    isEqual:[DBSettingsStore identifierForScreen:remaining]]);
                connected = screens;
                [desktop refresh];
                [desktop refresh];
                assert([[desktop valueForKey:@"windows"] count] == 2);
            }

            for (NSScreen *remaining in screens) {
                connected = @[ remaining ];
                [NSNotificationCenter.defaultCenter
                    postNotificationName:NSApplicationDidChangeScreenParametersNotification
                                  object:nil];
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.4]];
                windows = [desktop valueForKey:@"windows"];
                assert(windows.count == 1);
                assert([[DBSettingsStore identifierForScreen:windows.firstObject.screen]
                    isEqual:[DBSettingsStore identifierForScreen:remaining]]);
                connected = screens;
                [NSNotificationCenter.defaultCenter
                    postNotificationName:NSApplicationDidChangeScreenParametersNotification
                                  object:nil];
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.4]];
                assert([[desktop valueForKey:@"windows"] count] == 2);
            }
            puts("Passed simulated 2->1->2 transitions via refresh and screen-change notifications "
                 "with either monitor remaining and disconnected settings retained.");
        } else if (!singleMonitor) {
            puts("Skipped 1<->2 transitions: two connected display objects are required.");
        }

        NSMutableDictionary *disabled = [testSettings mutableCopy];
        NSMutableArray *excluded = NSMutableArray.new;

        for (NSScreen *screen in screens) {
            [excluded addObject:[DBSettingsStore identifierForScreen:screen]];
        }
        disabled[@"desktopExcludedDisplays"] = excluded;
        testSettings = disabled;
        NSURL *customURL =
            [NSURL fileURLWithPath:[testHome stringByAppendingPathComponent:@"custom.png"]];
        wallpapers[identifier] = customURL;
        [desktop refresh];
        assert([[desktop valueForKey:@"windows"] count] == 0);
        assert([wallpapers[identifier] isEqual:customURL]);
        NSUInteger writesBeforeRender = wallpaperWrites;
        assert(([DBWallpaperRenderer renderRequest:@{
            @"screens" : @[ @{@"identifier" : identifier, @"board" : board.snapshotConfiguration} ]
        }]));
        assert(wallpaperWrites == writesBeforeRender &&
               "Excluded monitors must reject stale render requests");
        [desktop refresh];
        assert([[desktop valueForKey:@"windows"] count] == 0);
        // Simulate a helper that finishes writing after its display was deselected.
        __block NSTask *pendingTask;
        Class taskClass = NSTask.new.class;
        method_setImplementation(
            class_getInstanceMethod(taskClass, @selector(launchAndReturnError:)),
            imp_implementationWithBlock(^BOOL(NSTask *task, NSError **error) {
                pendingTask = task;
                return YES;
            }));
        method_setImplementation(class_getInstanceMethod(taskClass, @selector(terminate)),
                                 imp_implementationWithBlock(^(id task){
                                 }));
        testSettings = @{@"sampleData" : @YES, @"desktopEnabled" : @YES};
        DBDesktopController *race = DBDesktopController.new;
        [race refresh];
        __block NSUInteger cancelledCallbacks = 0;
        void (^completion)(BOOL) = ^(BOOL success) {
            assert(!success);
            cancelledCallbacks++;
        };
        [race applyWallpaperWithCompletion:completion];
        [race applyWallpaperWithCompletion:completion];
        assert(pendingTask != nil);
        testSettings = @{
            @"sampleData" : @YES,
            @"desktopEnabled" : @YES,
            @"desktopExcludedDisplays" : excluded
        };
        [race refresh];
        assert(cancelledCallbacks == 1 && "Queued completion must finish when cancelled");
        wallpapers[identifier] = boardURL;
        pendingTask.terminationHandler(pendingTask);
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
        assert([wallpapers[identifier] isEqual:originalURL]);
        assert(!race.hasDesktopWindows);
        assert(cancelledCallbacks == 2 && "In-flight completion must finish exactly once");
        __block BOOL screenSaverActive = NO;
        ReplaceClassMethod(LiveFlightStore.class, @selector(screenSaverIsActive), ^BOOL(id cls) {
            return screenSaverActive;
        });
        ReplaceClassMethod(NSRunningApplication.class,
                           @selector(runningApplicationsWithBundleIdentifier:),
                           ^id(id cls, NSString *bundleIdentifier) {
                               return @[ DBTestRunningApplication.new ];
                           });
        assert(![LiveFlightStore shouldRefreshInBackground] &&
               "All excluded displays must stop maintenance polling");
        screenSaverActive = YES;
        assert([LiveFlightStore shouldRefreshInBackground]);
        screenSaverActive = NO;
        testSettings = @{@"sampleData" : @YES, @"desktopEnabled" : @YES};
        assert([LiveFlightStore shouldRefreshInBackground]);

        NSString *originalsPath =
            [DBWallpaperRenderer.rootPath stringByAppendingPathComponent:@"Originals.plist"];
        [NSFileManager.defaultManager removeItemAtPath:originalsPath error:NULL];
        [NSFileManager.defaultManager createDirectoryAtPath:originalsPath
                                withIntermediateDirectories:NO
                                                 attributes:nil
                                                      error:NULL];
        wallpapers[identifier] = customURL;
        NSUInteger writesBeforeFailure = wallpaperWrites;
        BOOL renderedWithoutBackup = [DBWallpaperRenderer renderRequest:@{
            @"screens" : @[ @{@"identifier" : identifier, @"board" : board.snapshotConfiguration} ]
        }];
        assert(!renderedWithoutBackup &&
               "Do not replace native wallpaper when saving its original fails");
        assert(wallpaperWrites == writesBeforeFailure);
        printf("Passed %s scenario: selection on %lu displays, settings preservation, "
               "reconnect/reorder, "
               "wallpaper restoration and stale request checks.\n",
               argv[2], screens.count);
    }
    return 0;
}
