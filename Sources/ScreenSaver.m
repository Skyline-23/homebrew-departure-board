#import "DepartureBoardView.h"
#import "SettingsStore.h"
#import <ScreenSaver/ScreenSaver.h>

// The system owns animation timing. The board redraws only when its content changes.
@interface DepartureBoardSaver : ScreenSaverView
@property(nonatomic, strong) DBBoardView *board;
@property(nonatomic, strong) NSWindow *options;
@property(nonatomic, copy) NSString *heartbeatPath;
@property(nonatomic) NSTimeInterval lastHeartbeat;
@end

@implementation DepartureBoardSaver

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)preview {

    if ((self = [super initWithFrame:frame isPreview:preview])) {

        self.animationTimeInterval = 1.0;
        self.board = [[DBBoardView alloc] initWithFrame:self.bounds];
        self.board.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self addSubview:self.board];
    }
    return self;
}

- (void)startAnimation {

    [self.board reloadSettings];
    [self updateHeartbeat];
    [super startAnimation];
}

- (void)stopAnimation {

    if (self.heartbeatPath.length) {

        [NSFileManager.defaultManager removeItemAtPath:self.heartbeatPath error:NULL];
    }
    [super stopAnimation];
}

- (void)setFrameSize:(NSSize)size {

    [super setFrameSize:size];
    self.board.frame = self.bounds;
}

- (void)animateOneFrame {

    [self.board tick];
    self.animationTimeInterval = self.board.preferredAnimationInterval;
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
