#import "DepartureBoardView.h"
#import "DesktopController.h"
#import "LiveFlightStore.h"
#import "SettingsStore.h"
#import "UserInstallation.h"
#import <unistd.h>

@interface DepartureBoardApp : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) DBBoardView *board;
@property(nonatomic, strong) NSWindow *options;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) DBDesktopController *desktop;
@end

@implementation DepartureBoardApp
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
    NSUInteger registration = [arguments indexOfObject:@"--register-bundles"];
    if (registration != NSNotFound && registration + 1 < arguments.count) {
        NSError *error = nil;
        if (!RegisterUserInstallation(arguments[registration + 1], &error)) {
            NSLog(@"Screen saver registration failed: %@",
                  error.localizedDescription ?: @"Invalid installation root");
        }
    }
    self.board = [[DBBoardView alloc] initWithFrame:NSMakeRect(0, 0, 1440, 900)];
    NSUInteger index = [arguments indexOfObject:@"--location"];
    if (index != NSNotFound && index + 1 < arguments.count)
        self.board.locationCode = arguments[index + 1];
    index = [arguments indexOfObject:@"--style"];
    if (index != NSNotFound && index + 1 < arguments.count)
        self.board.displayStyle = arguments[index + 1];
    index = [arguments indexOfObject:@"--language"];
    if (index != NSNotFound && index + 1 < arguments.count)
        self.board.languageMode = arguments[index + 1];
    index = [arguments indexOfObject:@"--snapshot"];
    if (index != NSNotFound && index + 1 < arguments.count) {
        // A fixed instant makes design review and regression snapshots reproducible.
        if ([arguments containsObject:@"--live-data"])
            self.board.useSampleData = NO;
        else
            self.board.referenceDate = [NSDate dateWithTimeIntervalSince1970:1794214800];
        NSSize size = NSMakeSize(1920, 1080);
        NSUInteger dimensions = [arguments indexOfObject:@"--snapshot-size"];
        if (dimensions != NSNotFound && dimensions + 1 < arguments.count) {
            NSArray *parts = [arguments[dimensions + 1] componentsSeparatedByString:@"x"];
            if (parts.count == 2 && [parts[0] doubleValue] > 0 && [parts[1] doubleValue] > 0)
                size = NSMakeSize([parts[0] doubleValue], [parts[1] doubleValue]);
        }
        BOOL result = [self.board writeSnapshot:arguments[index + 1] size:size];
        fprintf(result ? stdout : stderr, "Snapshot %s: %s\n", result ? "saved" : "failed",
                arguments[index + 1].UTF8String);
        [NSApp terminate:nil];
        return;
    }
    index = [arguments indexOfObject:@"--snapshot-all"];
    if (index != NSNotFound && index + 1 < arguments.count) {
        NSString *directory = arguments[index + 1];
        [NSFileManager.defaultManager createDirectoryAtPath:directory
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:NULL];
        self.board.referenceDate = [NSDate dateWithTimeIntervalSince1970:1794214800];
        self.board.languageMode = @"native";
        BOOL success = YES;
        for (NSDictionary *location in DBLocations()) {
            self.board.locationCode = location[@"code"];
            NSString *path = [directory
                stringByAppendingPathComponent:[location[@"code"] stringByAppendingString:@".png"]];
            NSSize size = NSMakeSize(1920, 1080);
            if ([arguments containsObject:@"--reference-size"] && location[@"display"][@"referenceAspect"]) {
                CGFloat aspect = [location[@"display"][@"referenceAspect"] doubleValue];
                size = aspect >= 1 ? NSMakeSize(1600, round(1600 / aspect))
                                   : NSMakeSize(round(1200 * aspect), 1200);
            }
            success &= [self.board writeSnapshot:path size:size];
        }
        fprintf(success ? stdout : stderr, "Rendered %lu board snapshots: %s\n",
                (unsigned long)DBLocations().count, directory.UTF8String);
        [NSApp terminate:nil];
        return;
    }
    NSMutableDictionary *currentSettings = [DBSettingsStore.settings mutableCopy];
    currentSettings[@"companionPath"] = NSBundle.mainBundle.bundlePath;
    [DBSettingsStore saveSettings:currentSettings replacementAPIKey:nil error:NULL];
    self.window =
        [[NSWindow alloc] initWithContentRect:self.board.frame
                                    styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                              NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                      backing:NSBackingStoreBuffered
                                        defer:NO];
    self.window.title = @"Departure Board";
    self.window.minSize = NSMakeSize(900, 580);
    self.window.delegate = self;
    self.window.contentView = self.board;
    self.board.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.window center];
    BOOL background = NO;
    if (!background)
        [self.window makeKeyAndOrderFront:nil];
    [self buildMenus];
    if (!background)
        [NSApp activateIgnoringOtherApps:YES];
    self.desktop = DBDesktopController.new;
    [self.desktop refresh];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
                                                 repeats:YES
                                                   block:^(NSTimer *timer) {
                                                       [self.board tick];
                                                       [self.desktop tick];
                                                   }];
    [LiveFlightStore refreshInBackground];
    NSDictionary *savedSettings = DBSettingsStore.settings;
    if ([savedSettings[@"hasAPIKey"] boolValue] && !self.board.useSampleData) {
        [LiveFlightStore configureBackgroundRefresh];
    }
    if ([arguments containsObject:@"--fullscreen"])
        [self.window toggleFullScreen:nil];
    if ([arguments containsObject:@"--settings"] || arguments.count == 1)
        [self showSettings:nil];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return ![DBSettingsStore.settings[@"desktopEnabled"] boolValue];
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)visible {
    [self showSettings:nil];
    return YES;
}
- (void)buildMenus {
    NSMenu *bar = NSMenu.new;
    NSMenuItem *appItem = NSMenuItem.new;
    [bar addItem:appItem];
    NSMenu *app = NSMenu.new;
    [app addItemWithTitle:DBUIString(@"menu.settings") action:@selector(showSettings:) keyEquivalent:@","];
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
    NSMenuItem *full = [view addItemWithTitle:DBUIString(@"menu.fullscreen")
                                       action:@selector(toggleFullScreen:)
                                keyEquivalent:@"f"];
    full.keyEquivalentModifierMask = NSEventModifierFlagControl | NSEventModifierFlagCommand;
    [view addItemWithTitle:DBUIString(@"menu.next") action:@selector(nextLocation:) keyEquivalent:@"]"];
    viewItem.submenu = view;
    [bar addItem:viewItem];
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
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
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
                                 if (!saved)
                                     return;
                                 [self.window endSheet:self.options];
                                 [self.options orderOut:nil];
                                 self.options = nil;
                                 [self.desktop refresh];
                             }];
}
- (void)openScreenSaverSettings:(id)sender {
    NSString *pane = @"com.apple.ScreenSaver-Settings.extension";
    if (@available(macOS 26.0, *))
        pane = @"com.apple.Wallpaper-Settings.extension";
    [NSWorkspace.sharedWorkspace
        openURL:[NSURL URLWithString:[@"x-apple.systempreferences:" stringByAppendingString:pane]]];
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc > 2 && strcmp(argv[1], "--import-api-key") == 0) {
            NSString *path = [NSString stringWithUTF8String:argv[2]];
            NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL];
            if ([attributes[NSFileOwnerAccountID] unsignedIntValue] != getuid() ||
                ([attributes[NSFilePosixPermissions] unsignedIntValue] & 0077) != 0)
                return 1;
            NSString *key = [[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL]
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            return [LiveFlightStore saveAPIKey:key error:NULL] ? 0 : 1;
        }
        if (argc > 1 && strcmp(argv[1], "--version") == 0) {
            puts([NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]
                     ? [[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]
                           UTF8String]
                     : "development");
            return 0;
        }
        if (argc > 1 && strcmp(argv[1], "--refresh-data") == 0) {
            if (![LiveFlightStore shouldRefreshInBackground])
                return 0;
            NSError *error = nil;
            BOOL refreshed = [LiveFlightStore refreshWithError:&error];
            if (!refreshed)
                fprintf(stderr, "%s\n",
                        error.localizedDescription.UTF8String ?: "Could not refresh flights.");
            return refreshed ? 0 : 1;
        }
        if (argc > 2 && strcmp(argv[1], "--refresh-airport") == 0) {
            NSError *error = nil;
            BOOL refreshed = [LiveFlightStore refreshAirport:[NSString stringWithUTF8String:argv[2]]
                                                       error:&error];
            if (!refreshed)
                fprintf(stderr, "%s\n",
                        error.localizedDescription.UTF8String ?: "Could not refresh flights.");
            return refreshed ? 0 : 1;
        }
        if (!DBSettingsStore.settings[@"hasAPIKey"])
            [DBSettingsStore saveSettings:DBSettingsStore.settings replacementAPIKey:nil error:NULL];
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        DepartureBoardApp *delegate = DepartureBoardApp.new;
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
