#define DB_APP_TEST 1
#import "../Sources/App.m"

@interface DBDesktopController (SettingsTests)
- (void)configureWindow:(NSWindow *)window;
@end

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
            DBDesktopController *desktop = DBDesktopController.new;
            [desktop setValue:@{ @"showAllSpaces" : @NO } forKey:@"appliedSettings"];
            [desktop configureWindow:controller.window];
            passed &= !(controller.window.collectionBehavior & NSWindowCollectionBehaviorCanJoinAllSpaces);
            [desktop setValue:@{ @"showAllSpaces" : @YES } forKey:@"appliedSettings"];
            [desktop configureWindow:controller.window];
            passed &= (controller.window.collectionBehavior & NSWindowCollectionBehaviorCanJoinAllSpaces) != 0;
            [controller.window close];
            passed &= ![DBBackgroundAgent shouldStartForSettings:@{
                @"launchAtLogin" : @NO
            }
                runtimeState:@{}
                sessionIdentifier:@"boot:login-2"];
            passed &= [DBBackgroundAgent shouldStartForSettings:@{
                @"launchAtLogin" : @YES
            }
                runtimeState:@{}
                sessionIdentifier:@"boot:login-2"];
            passed &= [DBBackgroundAgent shouldStartForSettings:@{}
                runtimeState:@{
                    @"sessionIdentifier" : @"boot:login-1",
                    @"keepRunning" : @YES
                }
                sessionIdentifier:@"boot:login-1"];
            passed &= ![DBBackgroundAgent shouldStartForSettings:@{
                @"launchAtLogin" : @YES
            }
                runtimeState:@{
                    @"sessionIdentifier" : @"boot:login-1",
                    @"keepRunning" : @NO
                }
                sessionIdentifier:@"boot:login-1"];
            passed &= [DBBackgroundAgent shouldStartForSettings:@{
                @"launchAtLogin" : @YES
            }
                runtimeState:@{
                    @"sessionIdentifier" : @"boot:login-1",
                    @"keepRunning" : @NO
                }
                sessionIdentifier:@"boot:login-2"];
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
