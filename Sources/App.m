#import "DepartureBoardView.h"
#import "LiveFlightStore.h"

@interface DepartureBoardApp : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) DBBoardView *board;
@property(nonatomic, strong) NSWindow *options;
@property(nonatomic, strong) NSTimer *timer;
@end

@implementation DepartureBoardApp
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
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
        self.board.referenceDate = [NSDate dateWithTimeIntervalSince1970:1794214800];
        BOOL result = [self.board writeSnapshot:arguments[index + 1] size:NSMakeSize(1920, 1080)];
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
            success &= [self.board writeSnapshot:path size:NSMakeSize(1920, 1080)];
        }
        fprintf(success ? stdout : stderr, "Rendered %lu board snapshots: %s\n",
                (unsigned long)DBLocations().count, directory.UTF8String);
        [NSApp terminate:nil];
        return;
    }
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
    [self.window makeKeyAndOrderFront:nil];
    [self buildMenus];
    [NSApp activateIgnoringOtherApps:YES];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
                                                 repeats:YES
                                                   block:^(NSTimer *timer) {
                                                       [self.board tick];
                                                   }];
    [LiveFlightStore refreshInBackground];
    if ([arguments containsObject:@"--fullscreen"])
        [self.window toggleFullScreen:nil];
    if ([arguments containsObject:@"--settings"])
        [self showSettings:nil];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
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
    if (self.options) {
        [self.options makeKeyAndOrderFront:nil];
        return;
    }
    self.options = [self.board settingsWindowWithTarget:self action:@selector(saveSettings:)];
    [self.window beginSheet:self.options completionHandler:nil];
}
- (void)saveSettings:(id)sender {
    [self.board applySettingsFromWindow:self.options];
    [self.window endSheet:self.options];
    [self.options orderOut:nil];
    self.options = nil;
}
- (void)openScreenSaverSettings:(id)sender {
    [NSWorkspace.sharedWorkspace
        openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension"]];
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--refresh-data") == 0) {
            return [LiveFlightStore refreshWithError:NULL] ? 0 : 1;
        }
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        DepartureBoardApp *delegate = DepartureBoardApp.new;
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
