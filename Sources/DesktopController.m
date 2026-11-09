#import "DesktopController.h"
#import "DepartureBoardView.h"
#import "LiveFlightStore.h"
#import "SettingsStore.h"
#import "WallpaperRenderer.h"
#import <CoreGraphics/CoreGraphics.h>

@interface DBDesktopController ()
@property(nonatomic, strong) NSMutableArray<NSWindow *> *windows;
@property(nonatomic) NSTimeInterval nextSettingsCheck;
@property(nonatomic) NSTimeInterval nextWallpaperUpdate;
@property(nonatomic, strong) NSDictionary *appliedSettings;
@property(nonatomic) BOOL sessionInactive;
@property(nonatomic, strong) NSTask *wallpaperTask;
@property(nonatomic, strong) NSMutableArray *wallpaperCompletions;
@property(nonatomic) BOOL wallpaperPending;
@property(nonatomic) BOOL userWasIdle;
@property(nonatomic, strong) NSDictionary *screenLayout;
@property(nonatomic) NSUInteger screenChangeGeneration;
@end

@implementation DBDesktopController

- (instancetype)init {

    if ((self = [super init])) {

        self.windows = NSMutableArray.new;
        self.wallpaperCompletions = NSMutableArray.new;
        [NSNotificationCenter.defaultCenter
            addObserver:self
               selector:@selector(screensChanged:)
                   name:NSApplicationDidChangeScreenParametersNotification
                 object:nil];
        [NSWorkspace.sharedWorkspace.notificationCenter
            addObserver:self
               selector:@selector(sessionResigned:)
                   name:NSWorkspaceSessionDidResignActiveNotification
                 object:nil];
        [NSWorkspace.sharedWorkspace.notificationCenter
            addObserver:self
               selector:@selector(sessionActivated:)
                   name:NSWorkspaceSessionDidBecomeActiveNotification
                 object:nil];
        [NSWorkspace.sharedWorkspace.notificationCenter
            addObserver:self
               selector:@selector(sessionActivated:)
                   name:NSWorkspaceActiveSpaceDidChangeNotification
                 object:nil];
    }
    return self;
}

- (void)dealloc {

    [NSNotificationCenter.defaultCenter removeObserver:self];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
}

- (void)sessionResigned:(NSNotification *)notification {

    self.sessionInactive = YES;
}

- (void)sessionActivated:(NSNotification *)notification {

    self.sessionInactive = NO;
    if ([self showOnAllSpaces]) {

        self.nextWallpaperUpdate = 0;
    }
}

- (BOOL)showOnAllSpaces {

    return !self.appliedSettings[@"showAllSpaces"] ||
           [self.appliedSettings[@"showAllSpaces"] boolValue];
}

- (BOOL)userIsIdle {

    return [LiveFlightStore screenSaverIsActive] ||
           CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateCombinedSessionState,
                                                  kCGAnyInputEventType) >= 30;
}

- (NSString *)wallpaperRoot {

    return DBWallpaperRenderer.rootPath;
}

- (NSString *)identifierForScreen:(NSScreen *)screen {

    return [DBWallpaperRenderer identifierForScreen:screen];
}

- (void)restoreSystemWallpapers {

    NSString *path = [self.wallpaperRoot stringByAppendingPathComponent:@"Originals.plist"];
    NSDictionary *originals = [NSDictionary dictionaryWithContentsOfFile:path];
    for (NSScreen *screen in NSScreen.screens) {

        NSURL *current = [NSWorkspace.sharedWorkspace desktopImageURLForScreen:screen];
        NSDictionary *original = originals[[self identifierForScreen:screen]];
        if ([current.path hasPrefix:self.wallpaperRoot] && original[@"url"]) {

            [NSWorkspace.sharedWorkspace
                setDesktopImageURL:[NSURL URLWithString:original[@"url"]]
                         forScreen:screen
                           options:@{
                               NSWorkspaceDesktopImageScalingKey : original[@"scaling"]
                                   ?: @(NSImageScaleProportionallyUpOrDown),
                               NSWorkspaceDesktopImageAllowClippingKey : original[@"clipping"]
                                   ?: @YES
                           }
                             error:NULL];
        }
    }
}

- (void)updateSystemWallpapersWithCompletion:(void (^)(BOOL))completion {

    if (self.sessionInactive || !self.windows.count || (!completion && [self userIsIdle])) {

        if (completion) {

            completion(NO);
        }
        return;
    }
    if (completion) {

        [self.wallpaperCompletions addObject:[completion copy]];
    }
    if (self.wallpaperTask) {

        self.wallpaperPending = YES;
        return;
    }
    NSArray *completions = [self.wallpaperCompletions copy];
    [self.wallpaperCompletions removeAllObjects];
    NSMutableArray *screens = NSMutableArray.new;
    for (NSWindow *window in self.windows) {

        NSScreen *screen = window.screen;
        if (!screen ||
            (![self showOnAllSpaces] && !(window.occlusionState & NSWindowOcclusionStateVisible))) {

            continue;
        }
        [screens addObject:@{
            @"identifier" : [self identifierForScreen:screen],
            @"board" : [(DBBoardView *)window.contentView snapshotConfiguration]
        }];
    }
    NSData *json = [NSJSONSerialization
        dataWithJSONObject:@{@"screens" : screens, @"force" : @(completions.count > 0)}
                   options:0
                     error:NULL];
    NSTask *task = NSTask.new;
    task.executableURL = NSBundle.mainBundle.executableURL;
    task.arguments = @[
        @"--render-wallpapers", [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]
    ];
    task.qualityOfService = NSQualityOfServiceUtility;
    task.standardOutput = NSFileHandle.fileHandleWithNullDevice;
    task.standardError = NSFileHandle.fileHandleWithNullDevice;
    __weak DBDesktopController *weakSelf = self;
    task.terminationHandler = ^(NSTask *finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            DBDesktopController *controller = weakSelf;
            if (controller.wallpaperTask != finished) {

                return;
            }
            controller.wallpaperTask = nil;
            if (finished.terminationStatus != 0) {

                NSLog(@"Wallpaper rendering failed with status %d", finished.terminationStatus);
            }
            for (void (^callback)(BOOL) in completions) {

                callback(finished.terminationStatus == 0);
            }
            if (controller.wallpaperPending) {

                controller.wallpaperPending = NO;
                [controller updateSystemWallpapersWithCompletion:nil];
            }
        });
    };
    self.wallpaperTask = task;
    if (![task launchAndReturnError:NULL]) {

        self.wallpaperTask = nil;
        for (void (^callback)(BOOL) in completions) {

            callback(NO);
        }
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                       if (task.running) {

                           [task terminate];
                       }
                   });
}

- (void)applyWallpaperWithCompletion:(void (^)(BOOL))completion {

    [self refresh];
    self.nextWallpaperUpdate = NSProcessInfo.processInfo.systemUptime + 60;
    [self updateSystemWallpapersWithCompletion:completion];
}

- (void)stop {

    [self.wallpaperTask terminate];
    self.wallpaperTask = nil;
    self.wallpaperPending = NO;
    [self.wallpaperCompletions removeAllObjects];
}

- (NSDictionary *)currentScreenLayout {

    NSMutableDictionary *layout = NSMutableDictionary.new;
    for (NSScreen *screen in NSScreen.screens) {

        layout[[self identifierForScreen:screen]] =
            @{@"frame" : NSStringFromRect(screen.frame), @"scale" : @(screen.backingScaleFactor)};
    }
    return layout;
}

- (void)screensChanged:(NSNotification *)notification {

    // AppKit also posts this for Dock/Space changes. Recreating every Retina
    // surface in response causes flicker, allocation spikes and more notifications.
    if (!self.windows.count || [[self currentScreenLayout] isEqual:self.screenLayout]) {

        return;
    }
    NSUInteger generation = ++self.screenChangeGeneration;
    __weak DBDesktopController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 4), dispatch_get_main_queue(), ^{
        DBDesktopController *controller = weakSelf;
        if (!controller || controller.screenChangeGeneration != generation ||
            [[controller currentScreenLayout] isEqual:controller.screenLayout]) {

            return;
        }
        for (NSWindow *window in controller.windows) {

            [window close];
        }
        [controller.windows removeAllObjects];
        [controller refresh];
    });
}

- (void)refresh {

    NSDictionary *settings = DBSettingsStore.settings;
    BOOL enabled = [settings[@"desktopEnabled"] boolValue];
    if (![self.appliedSettings isEqual:settings]) {

        self.appliedSettings = settings;
        self.nextWallpaperUpdate = 0;
        for (NSWindow *window in self.windows) {

            [self configureWindow:window];
        }
    }
    if (!enabled) {

        [self stop];
        if (self.windows.count) {

            [self restoreSystemWallpapers];
        }
        for (NSWindow *window in self.windows) {

            [window close];
        }
        [self.windows removeAllObjects];
        return;
    }
    if (self.windows.count) {

        return;
    }
    self.screenLayout = [self currentScreenLayout];
    NSTimeInterval cycleStart = NSProcessInfo.processInfo.systemUptime;
    for (NSScreen *screen in NSScreen.screens) {

        NSWindow *window = [[NSWindow alloc] initWithContentRect:screen.frame
                                                       styleMask:NSWindowStyleMaskBorderless
                                                         backing:NSBackingStoreBuffered
                                                           defer:YES
                                                          screen:screen];
        window.releasedWhenClosed = NO;
        window.title = [@"Departure Board — " stringByAppendingString:screen.localizedName];
        [window setFrame:screen.frame display:NO];
        window.level = CGWindowLevelForKey(kCGDesktopWindowLevelKey) + 1;
        [self configureWindow:window];
        window.ignoresMouseEvents = YES;
        window.hidesOnDeactivate = NO;
        window.hasShadow = NO;
        window.backgroundColor = NSColor.blackColor;
        DBBoardView *board = [[DBBoardView alloc]
            initWithFrame:NSMakeRect(0, 0, screen.frame.size.width, screen.frame.size.height)];
        NSMutableDictionary *configuration = [board.snapshotConfiguration mutableCopy];
        configuration[@"startTime"] = @(cycleStart);
        [board applySnapshotConfiguration:configuration];
        board.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        window.contentView = board;
        [window orderFrontRegardless];
        [self.windows addObject:window];
    }
}

- (void)configureWindow:(NSWindow *)window {

    window.colorSpace = NSColorSpace.sRGBColorSpace;
    [window setDynamicDepthLimit:NO];
    window.depthLimit = NSWindowDepthTwentyfourBitRGB;
    window.collectionBehavior =
        NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle |
        ([self showOnAllSpaces] ? NSWindowCollectionBehaviorCanJoinAllSpaces : 0);
}

- (BOOL)shouldUpdateWindow:(NSWindow *)window {

    CGDirectDisplayID display =
        [window.screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue];
    return !self.sessionInactive && window.visible &&
           (window.occlusionState & NSWindowOcclusionStateVisible) && !CGDisplayIsAsleep(display);
}

- (NSTimeInterval)preferredAnimationInterval {

    NSTimeInterval interval = 1;
    for (NSWindow *window in self.windows) {

        if ([self shouldUpdateWindow:window]) {

            interval =
                MIN(interval, [(DBBoardView *)window.contentView preferredAnimationInterval]);
        }
    }
    return interval;
}

- (void)tick {

    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    BOOL idle = [self userIsIdle];
    if (self.userWasIdle && !idle) {

        self.nextWallpaperUpdate = 0;
    }
    self.userWasIdle = idle;
    if (now >= self.nextSettingsCheck) {

        self.nextSettingsCheck = now + 1;
        [self refresh];
    }
    for (NSWindow *window in self.windows) {

        if ([self shouldUpdateWindow:window]) {

            [(DBBoardView *)window.contentView tick];
        }
    }
    if (self.windows.count && now >= self.nextWallpaperUpdate && !self.sessionInactive && !idle) {

        self.nextWallpaperUpdate = now + 60;
        [self updateSystemWallpapersWithCompletion:nil];
    }
}

@end
