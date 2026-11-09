#import "UserInstallation.h"

BOOL RegisterUserInstallation(NSString *installationRoot, NSError **error) {
    NSFileManager *files = NSFileManager.defaultManager;
    NSString *app = [installationRoot stringByAppendingPathComponent:@"Departure Board.app"];
    NSString *saver = [installationRoot stringByAppendingPathComponent:@"Departure Board.saver"];
    if (![[NSBundle bundleWithPath:app].bundleIdentifier isEqual:@"io.skyline.departureboard.preview"] ||
        ![[NSBundle bundleWithPath:saver].bundleIdentifier isEqual:@"io.skyline.departureboard.saver"]) {
        return NO;
    }
    NSDictionary *links = @{
        [NSHomeDirectory() stringByAppendingPathComponent:@"Applications/Departure Board.app"] : app,
        [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Screen Savers/Departure Board.saver"] :
            saver,
    };
    for (NSString *destination in links) {
        NSString *existing = [files destinationOfSymbolicLinkAtPath:destination error:NULL];
        if (existing && [existing isEqual:links[destination]])
            continue;
        if ([files fileExistsAtPath:destination] && !existing) {
            if (error)
                *error = [NSError
                    errorWithDomain:@"io.skyline.departureboard"
                               code:3
                           userInfo:@{
                               NSLocalizedDescriptionKey : @"A different installation already exists in "
                                                           @"Applications or Screen Savers."
                           }];
            return NO;
        }
        if (existing && ![existing containsString:@"/departure-board/"])
            return NO;
        if (![files createDirectoryAtPath:destination.stringByDeletingLastPathComponent
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:error])
            return NO;
        if (existing && ![files removeItemAtPath:destination error:error])
            return NO;
        if (![files createSymbolicLinkAtPath:destination withDestinationPath:links[destination] error:error])
            return NO;
    }
    return YES;
}
