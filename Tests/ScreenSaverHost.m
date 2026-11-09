#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        [NSApplication sharedApplication];
        NSBundle *bundle=[NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSError *error=nil;
        if (![bundle loadAndReturnError:&error]) {
            fprintf(stderr,"Could not load the screen saver bundle: %s\n",error.localizedDescription.UTF8String);
            return 1;
        }
        Class principal=bundle.principalClass;
        if (![principal isSubclassOfClass:ScreenSaverView.class]) return 1;
        ScreenSaverView *preview=[[principal alloc] initWithFrame:NSMakeRect(0,0,800,450) isPreview:YES];
        [preview startAnimation];
        [preview animateOneFrame];
        if (!preview.hasConfigureSheet || !preview.configureSheet || preview.subviews.count!=1) return 1;
        [preview stopAnimation];
        puts("The native screen saver loads, animates and creates its settings sheet.");
    }
    return 0;
}
