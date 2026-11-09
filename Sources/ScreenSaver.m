#import "DepartureBoardView.h"
#import <ScreenSaver/ScreenSaver.h>

// The system owns animation timing. The board redraws only when its content changes.
@interface DepartureBoardSaver : ScreenSaverView
@property(nonatomic, strong) DBBoardView *board;
@property(nonatomic, strong) NSWindow *options;
@end

@implementation DepartureBoardSaver
- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)preview {
    if ((self = [super initWithFrame:frame isPreview:preview])) {
        self.animationTimeInterval = 1.0 / 30.0;
        self.board = [[DBBoardView alloc] initWithFrame:self.bounds];
        self.board.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self addSubview:self.board];
    }
    return self;
}
- (void)startAnimation {
    [self.board reloadSettings];
    [super startAnimation];
}
- (void)animateOneFrame {
    [self.board tick];
}
- (BOOL)hasConfigureSheet {
    return YES;
}
- (NSWindow *)configureSheet {
    self.options = [self.board settingsWindowWithTarget:self action:@selector(saveOptions:)];
    return self.options;
}
- (void)saveOptions:(id)sender {
    [self.board applySettingsFromWindow:self.options];
    [NSApp endSheet:self.options];
    [self.options orderOut:nil];
    self.options = nil;
}
@end
