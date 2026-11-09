#define DB_APP_TEST 1
#import "../Sources/App.m"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2)
            return 2;
        NSString *resultPath = [NSString stringWithUTF8String:argv[1]];
        NSApplication *application = NSApplication.sharedApplication;
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        dispatch_async(dispatch_get_main_queue(), ^{
            DepartureBoardApp *controller = DepartureBoardApp.new;
            [controller createMainWindow];
            [controller buildMenus];
            [controller buildStatusMenu];
            [controller.window setFrameOrigin:NSMakePoint(-10000, -10000)];
            BOOL passed = !controller.window.releasedWhenClosed &&
                          ![controller applicationShouldTerminateAfterLastWindowClosed:application];
            for (NSInteger attempt = 0; attempt < 12; attempt++) {
                [controller showBoard:nil];
                if (attempt % 2 == 0)
                    [controller closeWindow:nil];
                else
                    [controller.window close];
                passed &= !controller.window.visible &&
                          application.activationPolicy == NSApplicationActivationPolicyAccessory;
                [controller applicationShouldHandleReopen:application hasVisibleWindows:NO];
                passed &= controller.window.visible && controller.options != nil &&
                          application.activationPolicy == NSApplicationActivationPolicyRegular;
                [controller closeSettings];
            }
            [controller.window close];
            passed &= ![DBBackgroundAgent shouldStartForSettings:@{
                @"launchAtLogin" : @NO
            }
                runtimeState:@{}
                bootIdentifier:@"new-boot"];
            passed &= [DBBackgroundAgent shouldStartForSettings:@{
                @"launchAtLogin" : @YES
            }
                runtimeState:@{}
                bootIdentifier:@"new-boot"];
            passed &= [DBBackgroundAgent shouldStartForSettings:@{}
                runtimeState:@{
                    @"bootIdentifier" : @"same-boot",
                    @"keepRunning" : @YES
                }
                bootIdentifier:@"same-boot"];
            passed &= ![DBBackgroundAgent shouldStartForSettings:@{
                @"launchAtLogin" : @YES
            }
                runtimeState:@{
                    @"bootIdentifier" : @"same-boot",
                    @"keepRunning" : @NO
                }
                bootIdentifier:@"same-boot"];
            [(passed ? @"passed" : @"failed") writeToFile:resultPath
                                               atomically:YES
                                                 encoding:NSUTF8StringEncoding
                                                    error:NULL];
            [application terminate:nil];
        });
        [application run];
    }
    return 0;
}
