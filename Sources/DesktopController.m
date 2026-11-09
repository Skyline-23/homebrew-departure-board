#import "DesktopController.h"
#import "DepartureBoardView.h"
#import "SettingsStore.h"
#import <CoreGraphics/CoreGraphics.h>

@interface DBDesktopController ()
@property(nonatomic, strong) NSMutableArray<NSWindow *> *windows;
@property(nonatomic) NSTimeInterval nextSettingsCheck;
@end

@implementation DBDesktopController
- (instancetype)init {
    if ((self = [super init])) {
        self.windows = NSMutableArray.new;
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(screensChanged:)
                                                   name:NSApplicationDidChangeScreenParametersNotification
                                                 object:nil];
    }
    return self;
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}
- (void)screensChanged:(NSNotification *)notification {
    for (NSWindow *window in self.windows)
        [window close];
    [self.windows removeAllObjects];
    [self refresh];
}
- (void)refresh {
    BOOL enabled = [DBSettingsStore.settings[@"desktopEnabled"] boolValue];
    if (!enabled) {
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
- (void)tick {
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (now >= self.nextSettingsCheck) {
        self.nextSettingsCheck = now + 1;
        [self refresh];
    }
    for (NSWindow *window in self.windows)
        [(DBBoardView *)window.contentView tick];
}
@end
