#import "DesktopController.h"
#import "DepartureBoardView.h"
#import "LiveFlightStore.h"
#import "SettingsStore.h"
#import <CoreGraphics/CoreGraphics.h>

@interface DBDesktopController ()
@property(nonatomic, strong) NSMutableArray<NSWindow *> *windows;
@property(nonatomic) NSTimeInterval nextSettingsCheck;
@property(nonatomic) NSTimeInterval nextWallpaperUpdate;
@property(nonatomic, strong) NSDictionary *appliedSettings;
@property(nonatomic) BOOL sessionInactive;
@property(nonatomic) NSUInteger wallpaperFrame;
@end

@implementation DBDesktopController
- (instancetype)init {
    if ((self = [super init])) {
        self.windows = NSMutableArray.new;
        [NSNotificationCenter.defaultCenter addObserver:self
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
    self.nextWallpaperUpdate = 0;
}
- (NSString *)wallpaperRoot {
    return [[LiveFlightStore userHome]
        stringByAppendingPathComponent:@"Library/Application Support/DepartureBoard/Wallpapers"];
}
- (NSString *)identifierForScreen:(NSScreen *)screen {
    CGDirectDisplayID display = [screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue];
    CFUUIDRef uuid = CGDisplayCreateUUIDFromDisplayID(display);
    NSString *identifier =
        uuid ? CFBridgingRelease(CFUUIDCreateString(NULL, uuid)) : [NSString stringWithFormat:@"%u", display];
    if (uuid)
        CFRelease(uuid);
    return identifier;
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
                               NSWorkspaceDesktopImageAllowClippingKey : original[@"clipping"] ?: @YES
                           }
                             error:NULL];
        }
    }
}
- (BOOL)updateSystemWallpapers {
    if (self.sessionInactive || !self.windows.count)
        return NO;
    BOOL applied = YES;
    NSFileManager *files = NSFileManager.defaultManager;
    NSString *frames = [self.wallpaperRoot stringByAppendingPathComponent:@"Frames"];
    [files createDirectoryAtPath:frames withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *originalsPath = [self.wallpaperRoot stringByAppendingPathComponent:@"Originals.plist"];
    NSMutableDictionary *originals =
        [[NSDictionary dictionaryWithContentsOfFile:originalsPath] mutableCopy] ?: NSMutableDictionary.new;
    for (NSWindow *window in self.windows) {
        NSScreen *screen = window.screen;
        if (!screen)
            continue;
        NSString *identifier = [self identifierForScreen:screen];
        NSURL *current = [NSWorkspace.sharedWorkspace desktopImageURLForScreen:screen];
        if (!originals[identifier] && current && ![current.path hasPrefix:self.wallpaperRoot]) {
            NSDictionary *options = [NSWorkspace.sharedWorkspace desktopImageOptionsForScreen:screen];
            originals[identifier] = @{
                @"url" : current.absoluteString,
                @"scaling" : options[NSWorkspaceDesktopImageScalingKey]
                    ?: @(NSImageScaleProportionallyUpOrDown),
                @"clipping" : options[NSWorkspaceDesktopImageAllowClippingKey] ?: @YES
            };
            [originals writeToFile:originalsPath atomically:YES];
        }
        NSString *filename =
            [NSString stringWithFormat:@"%@-%lu.png", identifier, (unsigned long)(self.wallpaperFrame % 2)];
        NSString *path = [frames stringByAppendingPathComponent:filename];
        DBBoardView *board = (DBBoardView *)window.contentView;
        NSSize pixels = NSMakeSize(screen.frame.size.width * screen.backingScaleFactor,
                                   screen.frame.size.height * screen.backingScaleFactor);
        if (![board writeSnapshot:path size:pixels]) {
            applied = NO;
            continue;
        }
        NSError *error = nil;
        if (![NSWorkspace.sharedWorkspace
                setDesktopImageURL:[NSURL fileURLWithPath:path]
                         forScreen:screen
                           options:@{
                               NSWorkspaceDesktopImageScalingKey : @(NSImageScaleProportionallyUpOrDown),
                               NSWorkspaceDesktopImageAllowClippingKey : @YES
                           }
                             error:&error]) {
            applied = NO;
            NSLog(@"Could not update the system wallpaper: %@", error.localizedDescription);
        }
    }
    self.wallpaperFrame++;
    return applied;
}
- (BOOL)applyWallpaper {
    [self refresh];
    for (NSWindow *window in self.windows)
        [(DBBoardView *)window.contentView tick];
    self.nextWallpaperUpdate = NSProcessInfo.processInfo.systemUptime + 60;
    return [self updateSystemWallpapers];
}
- (void)screensChanged:(NSNotification *)notification {
    for (NSWindow *window in self.windows)
        [window close];
    [self.windows removeAllObjects];
    [self refresh];
}
- (void)refresh {
    NSDictionary *settings = DBSettingsStore.settings;
    BOOL enabled = [settings[@"desktopEnabled"] boolValue];
    if (![self.appliedSettings isEqual:settings]) {
        self.appliedSettings = settings;
        self.nextWallpaperUpdate = 0;
    }
    if (!enabled) {
        if (self.windows.count)
            [self restoreSystemWallpapers];
        for (NSWindow *window in self.windows)
            [window close];
        [self.windows removeAllObjects];
        return;
    }
    if (self.windows.count)
        return;
    for (NSScreen *screen in NSScreen.screens) {
        NSWindow *window = [[NSWindow alloc] initWithContentRect:screen.frame
                                                       styleMask:NSWindowStyleMaskBorderless
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO
                                                          screen:screen];
        window.releasedWhenClosed = NO;
        window.title = [@"Departure Board — " stringByAppendingString:screen.localizedName];
        [window setFrame:screen.frame display:NO];
        window.level = CGWindowLevelForKey(kCGDesktopWindowLevelKey) + 1;
        window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                    NSWindowCollectionBehaviorStationary |
                                    NSWindowCollectionBehaviorIgnoresCycle;
        window.ignoresMouseEvents = YES;
        window.hidesOnDeactivate = NO;
        window.hasShadow = NO;
        window.backgroundColor = NSColor.blackColor;
        DBBoardView *board = [[DBBoardView alloc]
            initWithFrame:NSMakeRect(0, 0, screen.frame.size.width, screen.frame.size.height)];
        board.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        window.contentView = board;
        [window orderFrontRegardless];
        [self.windows addObject:window];
    }
}
- (BOOL)shouldUpdateWindow:(NSWindow *)window {
    CGDirectDisplayID display = [window.screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue];
    return !self.sessionInactive && window.visible &&
           (window.occlusionState & NSWindowOcclusionStateVisible) && !CGDisplayIsAsleep(display);
}
- (NSTimeInterval)preferredAnimationInterval {
    NSTimeInterval interval = 1;
    for (NSWindow *window in self.windows)
        if ([self shouldUpdateWindow:window])
            interval = MIN(interval, [(DBBoardView *)window.contentView preferredAnimationInterval]);
    return interval;
}
- (void)tick {
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (now >= self.nextSettingsCheck) {
        self.nextSettingsCheck = now + 1;
        [self refresh];
    }
    for (NSWindow *window in self.windows)
        if ([self shouldUpdateWindow:window])
            [(DBBoardView *)window.contentView tick];
    if (self.windows.count && now >= self.nextWallpaperUpdate && !self.sessionInactive) {
        self.nextWallpaperUpdate = now + 60;
        [self updateSystemWallpapers];
    }
}
@end
