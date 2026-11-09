#import "BackgroundAgent.h"
#import "LiveFlightStore.h"
#import "SettingsStore.h"
#import <bsm/audit.h>
#import <sys/sysctl.h>
#import <unistd.h>

@implementation DBBackgroundAgent
+ (NSString *)sessionIdentifier {
    char value[128] = {0};
    size_t length = sizeof(value);
    NSString *boot;
    if (sysctlbyname("kern.bootsessionuuid", value, &length, NULL, 0) == 0) {
        boot = [NSString stringWithUTF8String:value];
    } else {
        struct timeval bootTime = {0};
        length = sizeof(bootTime);
        sysctlbyname("kern.boottime", &bootTime, &length, NULL, 0);
        boot = [NSString stringWithFormat:@"%lld", (long long)bootTime.tv_sec];
    }
    // A logout/login starts a new audit session even without restarting macOS.
    auditinfo_addr_t audit = {0};
    if (getaudit_addr(&audit, sizeof(audit)) == 0)
        return [NSString stringWithFormat:@"%@:%u", boot, audit.ai_asid];
    return boot;
}
+ (NSString *)statePath {
    return [[LiveFlightStore userHome]
        stringByAppendingPathComponent:@"Library/Application Support/DepartureBoard/Runtime.plist"];
}
+ (void)recordRunning:(BOOL)running {
    NSString *path = self.statePath;
    [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:NULL];
    [@{@"sessionIdentifier" : self.sessionIdentifier, @"keepRunning" : @(running)} writeToFile:path atomically:YES];
}
+ (void)recordApplicationStarted {
    [self recordRunning:YES];
}
+ (void)recordApplicationQuit {
    [self recordRunning:NO];
}
+ (BOOL)shouldStartForSettings:(NSDictionary *)settings
                  runtimeState:(NSDictionary *)state
                sessionIdentifier:(NSString *)sessionIdentifier {
    if ([state[@"sessionIdentifier"] isEqual:sessionIdentifier])
        return [state[@"keepRunning"] boolValue];
    return [settings[@"launchAtLogin"] boolValue];
}
+ (NSRunningApplication *)runningApplication {
    for (NSRunningApplication *application in
         [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.skyline23.departureboard"])
        if (application.processIdentifier != getpid() && !application.terminated &&
            application.activationPolicy != NSApplicationActivationPolicyProhibited)
            return application;
    return nil;
}
+ (void)performMaintenance {
    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:self.statePath] ?: @{};
    if (!self.runningApplication && [self shouldStartForSettings:DBSettingsStore.settings
                                                    runtimeState:state
                                                  sessionIdentifier:self.sessionIdentifier]) {
        NSString *path = DBSettingsStore.settings[@"companionPath"];
        NSString *installed =
            [[LiveFlightStore userHome] stringByAppendingPathComponent:@"Applications/Departure Board.app"];
        NSBundle *installedBundle = [NSBundle bundleWithPath:installed];
        if ([installedBundle.bundleIdentifier isEqual:@"com.skyline23.departureboard"] &&
            [installedBundle.infoDictionary[@"CFBundleShortVersionString"]
                isEqual:NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]])
            path = installed;
        if (path.length) {
            NSWorkspaceOpenConfiguration *configuration = NSWorkspaceOpenConfiguration.configuration;
            configuration.activates = NO;
            configuration.createsNewApplicationInstance = YES;
            configuration.arguments = @[ @"--background" ];
            dispatch_semaphore_t done = dispatch_semaphore_create(0);
            [NSWorkspace.sharedWorkspace
                openApplicationAtURL:[NSURL fileURLWithPath:path]
                       configuration:configuration
                   completionHandler:^(NSRunningApplication *application, NSError *error) {
                       if (error)
                           NSLog(@"Could not restore Departure Board: %@", error.localizedDescription);
                       dispatch_semaphore_signal(done);
                   }];
            // The command-line helper needs a run loop for Launch Services' callback.
            NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:8];
            while (dispatch_semaphore_wait(done, DISPATCH_TIME_NOW) != 0 && deadline.timeIntervalSinceNow > 0)
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
        }
    }
    if ([LiveFlightStore shouldRefreshInBackground])
        [LiveFlightStore refreshWithError:NULL];
}
+ (void)configure {
    NSString *folder = [[LiveFlightStore userHome] stringByAppendingPathComponent:@"Library/LaunchAgents"];
    [NSFileManager.defaultManager createDirectoryAtPath:folder
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:NULL];
    NSString *legacyPath = [folder stringByAppendingPathComponent:@"io.skyline.departureboard.refresh.plist"];
    NSDictionary *legacyJob = [NSDictionary dictionaryWithContentsOfFile:legacyPath];
    if ([legacyJob[@"Label"] isEqual:@"io.skyline.departureboard.refresh"]) {
        NSTask *stopLegacy = NSTask.new;
        stopLegacy.executableURL = [NSURL fileURLWithPath:@"/bin/launchctl"];
        stopLegacy.arguments = @[
            @"bootout", [NSString stringWithFormat:@"gui/%u/io.skyline.departureboard.refresh", getuid()]
        ];
        stopLegacy.standardOutput = NSFileHandle.fileHandleWithNullDevice;
        stopLegacy.standardError = NSFileHandle.fileHandleWithNullDevice;
        [stopLegacy launchAndReturnError:NULL];
        [stopLegacy waitUntilExit];
        [NSFileManager.defaultManager removeItemAtPath:legacyPath error:NULL];
    }
    NSString *path = [folder stringByAppendingPathComponent:@"com.skyline23.departureboard.refresh.plist"];
    NSString *executable = NSBundle.mainBundle.executablePath;
    for (NSString *application in @[
             [[LiveFlightStore userHome] stringByAppendingPathComponent:@"Applications/Departure Board.app"],
             @"/Applications/Departure Board.app"
         ]) {
        NSBundle *bundle = [NSBundle bundleWithPath:application];
        if ([bundle.bundleIdentifier isEqual:@"com.skyline23.departureboard"] &&
            [bundle.infoDictionary[@"CFBundleShortVersionString"]
                isEqual:NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]]) {
            executable = [application stringByAppendingPathComponent:@"Contents/MacOS/DepartureBoard"];
            break;
        }
    }
    NSDictionary *job = @{
        @"Label" : @"com.skyline23.departureboard.refresh",
        @"ProgramArguments" : @[ executable, @"--maintain-background" ],
        @"StartInterval" : @30,
        @"RunAtLoad" : @YES,
        @"ProcessType" : @"Background"
    };
    BOOL unchanged = [[NSDictionary dictionaryWithContentsOfFile:path] isEqual:job];
    [job writeToFile:path atomically:YES];
    NSString *service = [NSString stringWithFormat:@"gui/%u/com.skyline23.departureboard.refresh", getuid()];
    NSTask *check = NSTask.new;
    check.executableURL = [NSURL fileURLWithPath:@"/bin/launchctl"];
    check.arguments = @[ @"print", service ];
    check.standardOutput = NSFileHandle.fileHandleWithNullDevice;
    check.standardError = NSFileHandle.fileHandleWithNullDevice;
    [check launchAndReturnError:NULL];
    [check waitUntilExit];
    if (unchanged && check.terminationStatus == 0)
        return;
    if (check.terminationStatus == 0) {
        NSTask *stop = NSTask.new;
        stop.executableURL = check.executableURL;
        stop.arguments = @[ @"bootout", service ];
        stop.standardError = NSFileHandle.fileHandleWithNullDevice;
        [stop launchAndReturnError:NULL];
        [stop waitUntilExit];
    }
    NSTask *task = NSTask.new;
    task.executableURL = [NSURL fileURLWithPath:@"/bin/launchctl"];
    task.arguments = @[ @"bootstrap", [NSString stringWithFormat:@"gui/%u", getuid()], path ];
    [task launchAndReturnError:NULL];
}
@end
