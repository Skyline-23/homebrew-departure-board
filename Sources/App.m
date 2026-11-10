#import "BackgroundAgent.h"
#import "CommandLine.h"
#import "DepartureBoardView.h"
#import "DesktopController.h"
#import "Diagnostics.h"
#import "LiveFlightStore.h"
#import "SettingsStore.h"
#import <errno.h>
#import <signal.h>
#import <unistd.h>

@interface DepartureBoardApp : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) DBBoardView *board;
@property(nonatomic, strong) NSWindow *options;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) DBDesktopController *desktop;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic) BOOL runtimeRegistered;
@end

@implementation DepartureBoardApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {

    DBDiagnosticEvent(@"app", @"app.started", @{
        @"version" : NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]
            ?: @"development"
    });
    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;

    if (!self.board && ![arguments containsObject:@"--background"]) {
        self.board = [DBCommandLine boardWithArguments:arguments];
    }
    NSMutableDictionary *currentSettings = [DBSettingsStore.settings mutableCopy];
    currentSettings[@"companionPath"] = NSBundle.mainBundle.bundlePath;
    [DBSettingsStore saveSettings:currentSettings replacementAPIKey:nil error:NULL];
    BOOL background = [arguments containsObject:@"--background"];

    if (!background) {
        [self createMainWindow];
    }
    [self buildMenus];
    [self buildStatusMenu];

    if (!background) {
        [self showBoard:nil];
    }
    self.desktop = DBDesktopController.new;
    [self.desktop refresh];
    self.runtimeRegistered = YES;
    [DBBackgroundAgent recordApplicationStarted];
    [self updateAnimationTimer];
    [LiveFlightStore refreshInBackground];
    [DBBackgroundAgent configure];

    if ([arguments containsObject:@"--fullscreen"]) {
        [self.window toggleFullScreen:nil];
    }

    if ([arguments containsObject:@"--settings"] || (!background && arguments.count == 1)) {
        [self showSettings:nil];
    }
}

- (BOOL)previewIsVisible {

    return self.window.visible && (self.window.occlusionState & NSWindowOcclusionStateVisible);
}

- (void)updateAnimationTimer {

    NSTimeInterval interval = self.desktop.preferredAnimationInterval;

    if ([self previewIsVisible]) {
        interval = MIN(interval, self.board.preferredAnimationInterval);
    }

    if (self.timer && fabs(self.timer.timeInterval - interval) < .001) {
        return;
    }
    [self.timer invalidate];
    __weak DepartureBoardApp *weakSelf = self;
    self.timer = [NSTimer timerWithTimeInterval:interval
                                        repeats:YES
                                          block:^(NSTimer *timer) {
                                              if ([weakSelf previewIsVisible]) {
                                                  [weakSelf.board tick];
                                              }
                                              [weakSelf.desktop tick];
                                              [weakSelf updateAnimationTimer];
                                          }];
    self.timer.tolerance = interval * .05;
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)createMainWindow {

    if (self.window) {
        return;
    }

    if (!self.board) {
        self.board = [[DBBoardView alloc] initWithFrame:NSMakeRect(0, 0, 1440, 900)];
    }
    self.window = [[NSWindow alloc]
        initWithContentRect:self.board.frame
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered

                      defer:YES];
    self.window.title = @"Departure Board";
    self.window.colorSpace = NSColorSpace.sRGBColorSpace;
    [self.window setDynamicDepthLimit:NO];
    self.window.depthLimit = NSWindowDepthTwentyfourBitRGB;
    // ARC owns this window across close/reopen cycles.
    self.window.releasedWhenClosed = NO;
    self.window.minSize = NSMakeSize(900, 580);
    self.window.delegate = self;
    self.window.contentView = self.board;
    self.board.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.window center];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {

    return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)visible {

    [self showSettings:nil];
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {

    DBDiagnosticEvent(@"app", @"app.stopped", @{});

    [self.timer invalidate];
    [self.desktop stop];
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];

    if (self.runtimeRegistered) {
        [DBBackgroundAgent recordApplicationQuit];
    }
}

- (void)windowWillClose:(NSNotification *)notification {

    if (notification.object != self.window) {
        return;
    }
    [self closeSettings];
    NSWindow *closed = self.window;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.window == closed && !closed.visible) {
            closed.contentView = nil;
            self.board.wantsLayer = NO;
            self.window = nil;
        }
    });
}

- (void)showBoard:(id)sender {

    [self createMainWindow];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)closeSettings {

    NSWindow *settings = self.options;

    if (!settings) {
        return;
    }
    [self.window endSheet:settings];
    [settings orderOut:nil];
    self.options = nil;
}

- (void)closeWindow:(id)sender {

    [self closeSettings];
    [self.window close];
}

- (void)buildStatusMenu {

    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:@"airplane.departure"
                                             accessibilityDescription:@"Departure Board"];
    NSMenu *menu = NSMenu.new;

    for (NSArray *entry in @[
             @[ @"menu.settings", NSStringFromSelector(@selector(showSettings:)) ],
             @[ @"menu.showBoard", NSStringFromSelector(@selector(showBoard:)) ],
             @[ @"settings.setWallpaper", NSStringFromSelector(@selector(applyWallpaper:)) ]
         ]) {
        NSMenuItem *item = [menu addItemWithTitle:DBUIString(entry[0])
                                           action:NSSelectorFromString(entry[1])
                                    keyEquivalent:@""];
        item.target = self;
    }
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [menu addItemWithTitle:DBUIString(@"menu.quit")
                                       action:@selector(terminate:)
                                keyEquivalent:@""];
    quit.target = NSApp;
    self.statusItem.menu = menu;
    [NSDistributedNotificationCenter.defaultCenter
               addObserver:self
                  selector:@selector(showSettings:)
                      name:@"com.skyline23.departureboard.showSettings"
                    object:nil
        suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
}

- (void)buildMenus {

    NSMenu *bar = NSMenu.new;
    NSMenuItem *appItem = NSMenuItem.new;
    [bar addItem:appItem];
    NSMenu *app = NSMenu.new;
    [app addItemWithTitle:DBUIString(@"menu.settings")
                   action:@selector(showSettings:)
            keyEquivalent:@","];
    [app addItemWithTitle:DBUIString(@"menu.screensaver")
                   action:@selector(openScreenSaverSettings:)
            keyEquivalent:@""];
    [app addItem:NSMenuItem.separatorItem];
    [app addItemWithTitle:DBUIString(@"menu.quit") action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = app;
    NSMenuItem *placesItem = [[NSMenuItem alloc] initWithTitle:DBUIString(@"menu.location")
                                                        action:NULL
                                                 keyEquivalent:@""];
    NSMenu *places = [[NSMenu alloc] initWithTitle:DBUIString(@"menu.location")];

    for (NSDictionary *location in DBLocations()) {
        NSMenuItem *item = [places addItemWithTitle:DBUIString(location[@"displayNameKey"])
                                             action:@selector(chooseLocation:)
                                      keyEquivalent:@""];
        item.target = self;
        item.representedObject = location[@"code"];
    }
    placesItem.submenu = places;
    [bar addItem:placesItem];
    NSMenuItem *viewItem = [[NSMenuItem alloc] initWithTitle:DBUIString(@"menu.view")
                                                      action:NULL
                                               keyEquivalent:@""];
    NSMenu *view = [[NSMenu alloc] initWithTitle:DBUIString(@"menu.view")];
    [view addItemWithTitle:DBUIString(@"settings.setWallpaper")
                    action:@selector(applyWallpaper:)
             keyEquivalent:@""];
    NSMenuItem *full = [view addItemWithTitle:DBUIString(@"menu.fullscreen")
                                       action:@selector(toggleFullScreen:)
                                keyEquivalent:@"f"];
    full.keyEquivalentModifierMask = NSEventModifierFlagControl | NSEventModifierFlagCommand;
    [view addItemWithTitle:DBUIString(@"menu.next")
                    action:@selector(nextLocation:)
             keyEquivalent:@"]"];
    viewItem.submenu = view;
    [bar addItem:viewItem];
    NSMenuItem *windowItem = [[NSMenuItem alloc] initWithTitle:DBUIString(@"menu.window")
                                                        action:NULL
                                                 keyEquivalent:@""];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:DBUIString(@"menu.window")];
    NSMenuItem *close = [windowMenu addItemWithTitle:DBUIString(@"menu.closeWindow")
                                              action:@selector(closeWindow:)
                                       keyEquivalent:@"w"];
    close.target = self;
    windowItem.submenu = windowMenu;
    [bar addItem:windowItem];
    NSApp.mainMenu = bar;
}

- (void)chooseLocation:(NSMenuItem *)sender {

    self.board.locationCode = sender.representedObject;
    [self.board saveSettings];
    [self.board tick];
    [LiveFlightStore refreshInBackground];
}

- (void)nextLocation:(id)sender {

    NSArray *codes = [DBLocations() valueForKey:@"code"];
    NSUInteger current = [codes indexOfObject:self.board.locationCode];
    self.board.locationCode = codes[(current + 1) % codes.count];
    [self.board saveSettings];
    [self.board tick];
}

- (void)showSettings:(id)sender {

    [self showBoard:nil];

    if (self.options) {
        [self.options makeKeyAndOrderFront:nil];
        return;
    }
    [self.board reloadSettings];
    self.options = [self.board settingsWindowWithTarget:self action:@selector(saveSettings:)];
    [self.window beginSheet:self.options completionHandler:nil];
}

- (void)saveSettings:(id)sender {

    [self.board applySettingsFromWindow:self.options
                             completion:^(BOOL saved) {
                                 if (!saved) {
                                     return;
                                 }
                                 [self closeSettings];
                                 [self.desktop refresh];
                             }];
}

- (void)applyWallpaper:(id)sender {

    void (^apply)(void) = ^{
        NSButton *button = [sender isKindOfClass:NSButton.class] ? sender : nil;
        button.enabled = NO;
        [self.desktop applyWallpaperWithCompletion:^(BOOL success) {
            button.enabled = YES;
            button.title =
                DBUIString(success ? @"settings.wallpaperApplied" : @"settings.setWallpaper");

            if (!success) {
                NSAlert *alert = NSAlert.new;
                alert.messageText = DBUIString(@"settings.wallpaperFailed");
                [alert runModal];
            }
        }];
    };

    if (self.options) {
        [(NSButton *)[self.options.contentView viewWithTag:204] setState:NSControlStateValueOn];
        [self.board applySettingsFromWindow:self.options
                                 completion:^(BOOL saved) {
                                     if (saved) {
                                         apply();
                                     }
                                 }];
    } else {
        NSMutableDictionary *settings = [DBSettingsStore.settings mutableCopy];
        settings[@"desktopEnabled"] = @YES;
        [DBSettingsStore saveSettings:settings replacementAPIKey:nil error:NULL];
        apply();
    }
}

- (void)openScreenSaverSettings:(id)sender {

    NSString *pane = @"com.apple.ScreenSaver-Settings.extension";

    if (@available(macOS 26.0, *)) {
        pane = @"com.apple.Wallpaper-Settings.extension";
    }
    [NSWorkspace.sharedWorkspace
        openURL:[NSURL URLWithString:[@"x-apple.systempreferences:" stringByAppendingString:pane]]];
}

@end

#ifndef DB_APP_TEST
static BOOL HandleRunningApplication(NSArray<NSString *> *arguments) {

    NSRunningApplication *running = [DBBackgroundAgent runningApplication];

    if (!running) {
        return NO;
    }
    NSString *statePath = [[LiveFlightStore userHome]
        stringByAppendingPathComponent:@"Library/Application Support/DepartureBoard/Runtime.plist"];
    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:statePath];
    BOOL recordedProcess = [state[@"processID"] intValue] == running.processIdentifier;
    NSString *installedVersion = recordedProcess
                                     ? state[@"appVersion"]
                                     : [NSBundle bundleWithURL:running.bundleURL]
                                           .infoDictionary[@"CFBundleShortVersionString"];
    NSString *currentVersion = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
    NSDate *modified =
        [NSFileManager.defaultManager attributesOfItemAtPath:running.executableURL.path
                                                       error:NULL][NSFileModificationDate];
    BOOL replacedOnDisk = modified && running.launchDate &&
                          [modified compare:running.launchDate] == NSOrderedDescending;

    if (replacedOnDisk || (currentVersion && ![installedVersion isEqual:currentVersion])) {
        [running terminate];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
        // Launch Services may cache isTerminated after the process has exited.
        pid_t previousPID = running.processIdentifier;

        while (deadline.timeIntervalSinceNow > 0) {
            if (kill(previousPID, 0) == -1 && errno == ESRCH) {
                return NO;
            }
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
        }
    }

    if (![arguments containsObject:@"--background"]) {
        [NSDistributedNotificationCenter.defaultCenter
            postNotificationName:@"com.skyline23.departureboard.showSettings"
                          object:nil
                        userInfo:nil
              deliverImmediately:YES];
        [running activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    }
    return YES;
}

int main(int argc, const char *argv[]) {

    @autoreleasepool {
        NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
        NSNumber *commandResult = [DBCommandLine runWithArguments:arguments];

        if (commandResult) {
            return commandResult.intValue;
        }

        if (!DBSettingsStore.settings[@"hasAPIKey"]) {
            [DBSettingsStore saveSettings:DBSettingsStore.settings
                        replacementAPIKey:nil
                                    error:NULL];
        }

        if (HandleRunningApplication(arguments)) {
            return 0;
        }
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        __attribute__((objc_precise_lifetime)) DepartureBoardApp *delegate = DepartureBoardApp.new;
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
#endif
