#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>

int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc != 2) return 1;
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        NSBundle *bundle = [NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
        if (![bundle load]) return 2;
        ScreenSaverView *view = [[bundle.principalClass alloc] initWithFrame:NSMakeRect(0, 0, 1280, 720)
                                                                 isPreview:YES];
        if (!view || !view.hasConfigureSheet || !view.configureSheet) return 3;
        [view startAnimation];
        [view animateOneFrame];
        if (!view.isAnimating) return 4;
        [view stopAnimation];
        if (view.isAnimating) return 5;
        puts("Installed screen saver loaded, animated, stopped, and supplied its options sheet.");
    }
    return 0;
}
