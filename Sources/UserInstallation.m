#import "UserInstallation.h"

BOOL RegisterUserInstallation(NSString *installationRoot, NSError **error) {
    NSFileManager *files = NSFileManager.defaultManager;
    NSString *app = [installationRoot stringByAppendingPathComponent:@"Departure Board.app"];
    NSString *saver = [installationRoot stringByAppendingPathComponent:@"Departure Board.saver"];
    if (![[NSBundle bundleWithPath:app].bundleIdentifier isEqual:@"com.skyline23.departureboard"] ||
        ![[NSBundle bundleWithPath:saver].bundleIdentifier isEqual:@"com.skyline23.departureboard.saver"]) {
        return NO;
    }
    NSDictionary *links = @{
        [NSHomeDirectory() stringByAppendingPathComponent:@"Applications/Departure Board.app"] : app,
    };
    for (NSString *destination in links) {
        NSString *existing = [files destinationOfSymbolicLinkAtPath:destination error:NULL];
        if (existing && [existing isEqual:links[destination]])
            continue;
        if ([files fileExistsAtPath:destination] && !existing) {
            if (error)
                *error = [NSError
                    errorWithDomain:@"com.skyline23.departureboard"
                               code:3
                           userInfo:@{
                               NSLocalizedDescriptionKey : @"A different installation already exists in "
                                                           @"Applications or Screen Savers."
                           }];
            return NO;
        }
        if (existing && ![existing containsString:@"/departure-board/"]) {
            NSString *identifier = [NSBundle bundleWithPath:existing].bundleIdentifier;
            if (![identifier isEqual:@"com.skyline23.departureboard"] &&
                ![identifier isEqual:@"io.skyline.departureboard.preview"])
                return NO;
        }
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
    // System Settings opens configuration in a separate sandboxed host. Install
    // a real bundle in its standard search path, rather than a Homebrew symlink.
    NSString *destination =
        [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Screen Savers/Departure Board.saver"];
    NSString *link = [files destinationOfSymbolicLinkAtPath:destination error:NULL];
    NSBundle *installed = [NSBundle bundleWithPath:destination];
    NSBundle *source = [NSBundle bundleWithPath:saver];
    if (!link && [installed.bundleIdentifier isEqual:source.bundleIdentifier] &&
        [files contentsEqualAtPath:destination andPath:saver])
        return YES;
    if ([files fileExistsAtPath:destination] && !link &&
        ![installed.bundleIdentifier isEqual:source.bundleIdentifier] &&
        ![installed.bundleIdentifier isEqual:@"io.skyline.departureboard.saver"])
        return NO;
    NSString *staging = [destination.stringByDeletingLastPathComponent
        stringByAppendingPathComponent:[NSString stringWithFormat:@".DepartureBoard-%@.saver",
                                                                  NSUUID.UUID.UUIDString]];
    if (![files createDirectoryAtPath:destination.stringByDeletingLastPathComponent
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:error] ||
        ![files copyItemAtPath:saver toPath:staging error:error])
        return NO;
    NSString *backup = [staging stringByAppendingString:@".previous"];
    BOOL existing = [files fileExistsAtPath:destination] || link;
    if (existing && ![files moveItemAtPath:destination toPath:backup error:error]) {
        [files removeItemAtPath:staging error:NULL];
        return NO;
    }
    if (![files moveItemAtPath:staging toPath:destination error:error]) {
        if (existing)
            [files moveItemAtPath:backup toPath:destination error:NULL];
        return NO;
    }
    if (existing)
        [files removeItemAtPath:backup error:NULL];
    return YES;
}
