#import "UserInstallation.h"

static BOOL InstallBundle(NSString *source, NSString *destination, NSString *identifier,
                          NSString *legacyIdentifier, NSError **error) {
    NSFileManager *files = NSFileManager.defaultManager;
    NSBundle *bundle = [NSBundle bundleWithPath:source];
    if (![bundle.bundleIdentifier isEqual:identifier]) {
        return NO;
    }
    NSString *link = [files destinationOfSymbolicLinkAtPath:destination error:NULL];
    NSBundle *installed = [NSBundle bundleWithPath:destination];
    BOOL exists = [files fileExistsAtPath:destination] || link;
    if (exists && ![installed.bundleIdentifier isEqual:identifier] &&
        ![installed.bundleIdentifier isEqual:legacyIdentifier]) {
        if (error) {
            *error = [NSError
                errorWithDomain:@"com.skyline23.departureboard"
                           code:3
                       userInfo:@{
                           NSLocalizedDescriptionKey :
                               @"A different application already occupies the installation path."
                       }];
        }
        return NO;
    }
    // The signature seals resources and the executable; avoid walking thousands
    // of unchanged logo files on every launch of the Homebrew command.
    if (!link && [installed.bundleIdentifier isEqual:identifier] &&
        [files contentsEqualAtPath:
                   [source stringByAppendingPathComponent:@"Contents/_CodeSignature/CodeResources"]
                           andPath:[destination stringByAppendingPathComponent:
                                                    @"Contents/_CodeSignature/CodeResources"]] &&
        [files contentsEqualAtPath:bundle.executablePath andPath:installed.executablePath]) {
        return YES;
    }
    NSString *folder = destination.stringByDeletingLastPathComponent;
    if (![files createDirectoryAtPath:folder
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:error]) {
        return NO;
    }
    NSString *stagingRoot = [folder
        stringByAppendingPathComponent:[NSString stringWithFormat:@".DepartureBoard-%@.noindex",
                                                                  NSUUID.UUID.UUIDString]];
    // A temporary .app is registered by Launch Services even inside .noindex.
    // Add the .app extension only when the finished bundle reaches /Applications.
    NSString *staging = [stagingRoot stringByAppendingPathComponent:@"incoming"];
    if (![files createDirectoryAtPath:stagingRoot
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:error]) {
        return NO;
    }
    // Synced source folders can acquire Finder metadata after signing. Copy
    // bundle content without resource forks or extended attributes.
    NSTask *copy = NSTask.new;
    copy.executableURL = [NSURL fileURLWithPath:@"/usr/bin/ditto"];
    copy.arguments = @[ @"--noextattr", @"--norsrc", source, staging ];
    copy.standardOutput = NSFileHandle.fileHandleWithNullDevice;
    copy.standardError = NSFileHandle.fileHandleWithNullDevice;
    if (![copy launchAndReturnError:error]) {
        [files removeItemAtPath:stagingRoot error:NULL];
        return NO;
    }
    [copy waitUntilExit];
    if (copy.terminationStatus != 0) {
        if (error) {
            *error = [NSError
                errorWithDomain:@"com.skyline23.departureboard"
                           code:4
                       userInfo:@{
                           NSLocalizedDescriptionKey :
                               @"Could not copy the application into its installation folder."
                       }];
        }
        [files removeItemAtPath:stagingRoot error:NULL];
        return NO;
    }
    NSString *backup = [stagingRoot stringByAppendingPathComponent:@"previous"];
    if (exists && ![files moveItemAtPath:destination toPath:backup error:error]) {
        [files removeItemAtPath:stagingRoot error:NULL];
        return NO;
    }
    if (![files moveItemAtPath:staging toPath:destination error:error]) {
        if (exists) {
            [files moveItemAtPath:backup toPath:destination error:NULL];
        }
        [files removeItemAtPath:stagingRoot error:NULL];
        return NO;
    }
    [files removeItemAtPath:stagingRoot error:NULL];
    return YES;
}

BOOL RegisterUserInstallation(NSString *installationRoot, NSError **error) {
    NSString *app = [installationRoot stringByAppendingPathComponent:@"Departure Board.app"];
    NSString *saver = [installationRoot stringByAppendingPathComponent:@"Departure Board.saver"];
    if (![[NSBundle bundleWithPath:app].bundleIdentifier isEqual:@"com.skyline23.departureboard"] ||
        ![[NSBundle bundleWithPath:saver].bundleIdentifier
            isEqual:@"com.skyline23.departureboard.saver"]) {
        return NO;
    }
    if (!InstallBundle(app, @"/Applications/Departure Board.app", @"com.skyline23.departureboard",
                       @"io.skyline.departureboard.preview", error)) {
        return NO;
    }
    if (!InstallBundle(
            saver,
            [NSHomeDirectory()
                stringByAppendingPathComponent:@"Library/Screen Savers/Departure Board.saver"],
            @"com.skyline23.departureboard.saver", @"io.skyline.departureboard.saver", error)) {
        return NO;
    }
    // Retire only our former Homebrew alias. Never remove another user-owned app.
    NSFileManager *files = NSFileManager.defaultManager;
    NSString *alias =
        [NSHomeDirectory() stringByAppendingPathComponent:@"Applications/Departure Board.app"];
    NSString *target = [files destinationOfSymbolicLinkAtPath:alias error:NULL];
    if (target && ([target containsString:@"/departure-board/"] ||
                   [[NSBundle bundleWithPath:target].bundleIdentifier
                       isEqual:@"com.skyline23.departureboard"])) {
        [files removeItemAtPath:alias error:NULL];
    }
    NSString *registrar = @"/System/Library/Frameworks/CoreServices.framework/Frameworks/"
                           "LaunchServices.framework/Support/lsregister";
    for (NSArray *arguments in
         @[ @[ @"-u", app, alias ], @[ @"-f", @"/Applications/Departure Board.app" ] ]) {
        NSTask *task = NSTask.new;
        task.executableURL = [NSURL fileURLWithPath:registrar];
        task.arguments = arguments;
        task.standardOutput = NSFileHandle.fileHandleWithNullDevice;
        task.standardError = NSFileHandle.fileHandleWithNullDevice;
        if ([task launchAndReturnError:NULL]) {
            [task waitUntilExit];
        }
    }
    return YES;
}
