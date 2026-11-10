#import "DepartureBoardView.h"
#import "Diagnostics.h"
#import "SettingsStore.h"
#import <ScreenSaver/ScreenSaver.h>
#import <os/log.h>

static os_log_t ScreenSaverLog(void) {

    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        log = os_log_create("com.skyline23.departureboard.saver", "refresh");
    });
    return log;
}

// The system owns animation timing. The board redraws only when its content changes.
@interface DepartureBoardSaver : ScreenSaverView
@property(nonatomic, strong) DBBoardView *board;
@property(nonatomic, strong) NSWindow *options;
@property(nonatomic, copy) NSString *heartbeatPath;
@property(nonatomic) NSTimeInterval lastHeartbeat;
@property(nonatomic, strong) NSTimer *refreshTimer;
@property(nonatomic) NSTimeInterval lastHostFrameTime;
@property(nonatomic) BOOL refreshingWithoutHost;
@end

@implementation DepartureBoardSaver

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)preview {

    if ((self = [super initWithFrame:frame isPreview:preview])) {
        self.animationTimeInterval = 1.0;
        self.board = [[DBBoardView alloc] initWithFrame:self.bounds];
        self.board.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self addSubview:self.board];
        DBDiagnosticEvent(@"saver", @"saver.created", @{
            @"preview" : @(preview),
            @"version" : [NSBundle bundleForClass:self.class]
                    .infoDictionary[@"CFBundleShortVersionString"]
                ?: @"development"
        });
        [self startRefreshTimer];
    }
    return self;
}

- (void)startAnimation {

    os_log(ScreenSaverLog(), "Screen saver started; preview=%d", self.isPreview);
    [self.board reloadSettings];
    [self updateHeartbeat];
    [self startRefreshTimer];
    [super startAnimation];
}

- (void)stopAnimation {

    os_log(ScreenSaverLog(), "Screen saver stopped; preview=%d", self.isPreview);
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;

    if (self.heartbeatPath.length) {
        [NSFileManager.defaultManager removeItemAtPath:self.heartbeatPath error:NULL];
    }
    [super stopAnimation];
}

- (void)dealloc {

    [self.refreshTimer invalidate];
}

- (void)viewDidMoveToWindow {

    [super viewDidMoveToWindow];

    if (self.window) {
        [self startRefreshTimer];
    } else {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }
}

- (void)startRefreshTimer {

    if (self.refreshTimer.valid) {
        return;
    }
    // Some ExtensionKit hosts keep presenting the initial view without sending
    // animation callbacks. Continue polling its shared cache in that case.
    __weak DepartureBoardSaver *weakSelf = self;
    self.refreshTimer = [NSTimer
        timerWithTimeInterval:1
                      repeats:YES
                        block:^(NSTimer *timer) {
                            DepartureBoardSaver *saver = weakSelf;

                            if (!saver) {
                                [timer invalidate];
                                return;
                            }
                            NSTimeInterval elapsed =
                                NSProcessInfo.processInfo.systemUptime - saver.lastHostFrameTime;

                            if (elapsed >= 1.5) {
                                if (!saver.refreshingWithoutHost) {
                                    saver.refreshingWithoutHost = YES;
                                    os_log(ScreenSaverLog(),
                                           "Host frames paused; refreshing shared cache");
                                }
                                [saver refreshBoard];
                            }
                        }];
    self.refreshTimer.tolerance = .1;
    [NSRunLoop.mainRunLoop addTimer:self.refreshTimer forMode:NSRunLoopCommonModes];
}

- (void)setFrameSize:(NSSize)size {

    [super setFrameSize:size];
    self.board.frame = self.bounds;
}

- (void)animateOneFrame {

    if (self.refreshingWithoutHost) {
        os_log(ScreenSaverLog(), "Host animation callbacks resumed");
        self.refreshingWithoutHost = NO;
    }
    self.lastHostFrameTime = NSProcessInfo.processInfo.systemUptime;
    [self refreshBoard];
}

- (void)refreshBoard {

    [self.board tick];
    NSTimeInterval interval = self.board.preferredAnimationInterval;

    if (fabs(self.animationTimeInterval - interval) >= .001) {
        self.animationTimeInterval = interval;
    }

    if (NSDate.timeIntervalSinceReferenceDate - self.lastHeartbeat > 30) {
        [self updateHeartbeat];
    }
}

- (void)updateHeartbeat {

    if (!self.isPreview) {
        NSString *folder =
            [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
                    .firstObject stringByAppendingPathComponent:@"DepartureBoard"];
        [NSFileManager.defaultManager createDirectoryAtPath:folder
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:NULL];
        self.heartbeatPath = [folder
            stringByAppendingPathComponent:[NSString stringWithFormat:@"active-%d",
                                                                      NSProcessInfo.processInfo
                                                                          .processIdentifier]];
        [NSData.data writeToFile:self.heartbeatPath atomically:YES];
        self.lastHeartbeat = NSDate.timeIntervalSinceReferenceDate;
    }
}

- (BOOL)hasConfigureSheet {

    return YES;
}

- (NSWindow *)configureSheet {

    if (!self.options) {
        self.options = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 500, 164)
                                                  styleMask:NSWindowStyleMaskTitled
                                                    backing:NSBackingStoreBuffered

                                                      defer:NO];
        self.options.title = DBUIString(@"settings.title");
        self.options.releasedWhenClosed = NO;
        NSTextField *message =
            [NSTextField wrappingLabelWithString:DBUIString(@"settings.companionExplanation")];
        message.frame = NSMakeRect(24, 83, 452, 58);
        [self.options.contentView addSubview:message];
        NSButton *open = [NSButton buttonWithTitle:DBUIString(@"settings.openCompanion")
                                            target:self
                                            action:@selector(openCompanion:)];
        open.frame = NSMakeRect(24, 27, 340, 32);
        open.bezelStyle = NSBezelStyleRounded;
        open.tag = 301;
        [self.options.contentView addSubview:open];
        NSButton *done = [NSButton buttonWithTitle:DBUIString(@"settings.done")
                                            target:self
                                            action:@selector(closeOptions:)];
        done.frame = NSMakeRect(382, 27, 92, 32);
        done.bezelStyle = NSBezelStyleRounded;
        [self.options.contentView addSubview:done];
    }
    return self.options;
}

- (void)openCompanion:(id)sender {

    NSString *path = DBSettingsStore.settings[@"companionPath"];

    if (!path.length) {
        path =
            [NSHomeDirectory() stringByAppendingPathComponent:@"Applications/Departure Board.app"];
    }
    NSWorkspaceOpenConfiguration *configuration = NSWorkspaceOpenConfiguration.configuration;
    configuration.activates = YES;
    configuration.arguments = @[ @"--settings" ];
    [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:path]
                                        configuration:configuration
                                    completionHandler:nil];
}

- (void)closeOptions:(id)sender {

    [NSApp endSheet:self.options];
    [self.options orderOut:nil];
    self.options = nil;
}

@end
