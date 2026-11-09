#import "../Sources/UserInstallation.m"
#import <Foundation/Foundation.h>
#import <sys/xattr.h>

static void WriteBundle(NSString *path, NSString *identifier, NSString *revision) {
    NSFileManager *files = NSFileManager.defaultManager;
    [files createDirectoryAtPath:[path stringByAppendingPathComponent:@"Contents/MacOS"]
        withIntermediateDirectories:YES
                         attributes:nil
                              error:NULL];
    [files createDirectoryAtPath:[path stringByAppendingPathComponent:@"Contents/_CodeSignature"]
        withIntermediateDirectories:YES
                         attributes:nil
                              error:NULL];
    [@{
        @"CFBundleIdentifier" : identifier,
        @"CFBundleExecutable" : @"TestApp",
        @"CFBundlePackageType" : @"APPL",
        @"CFBundleVersion" : revision
    } writeToFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]
        atomically:YES];
    [revision writeToFile:[path stringByAppendingPathComponent:@"Contents/MacOS/TestApp"]
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:NULL];
    [revision
        writeToFile:[path stringByAppendingPathComponent:@"Contents/_CodeSignature/CodeResources"]
         atomically:YES
           encoding:NSUTF8StringEncoding
              error:NULL];
}

int main(void) {
    @autoreleasepool {
        NSFileManager *files = NSFileManager.defaultManager;
        NSString *root =
            [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSString *source = [root stringByAppendingPathComponent:@"source/Board.app"];
        NSString *destination = [root stringByAppendingPathComponent:@"Applications/Board.app"];
        NSString *identifier = @"com.skyline23.departureboard.test";
        WriteBundle(source, identifier, @"1");
        char metadata[32] = {1};
        setxattr(source.fileSystemRepresentation, "com.apple.FinderInfo", metadata,
                 sizeof(metadata), 0, 0);
        BOOL passed = InstallBundle(source, destination, identifier, nil, NULL);
        passed &= getxattr(destination.fileSystemRepresentation, "com.apple.FinderInfo", NULL, 0, 0,
                           0) < 0;
        NSDate *modified = [files attributesOfItemAtPath:destination
                                                   error:NULL][NSFileModificationDate];
        passed &= InstallBundle(source, destination, identifier, nil, NULL);
        passed &= [modified isEqual:[files attributesOfItemAtPath:destination
                                                            error:NULL][NSFileModificationDate]];
        WriteBundle(source, identifier, @"2");
        passed &= InstallBundle(source, destination, identifier, nil, NULL);
        NSString *executable =
            [destination stringByAppendingPathComponent:@"Contents/MacOS/TestApp"];
        passed &= [[NSString stringWithContentsOfFile:executable
                                             encoding:NSUTF8StringEncoding
                                                error:NULL] isEqual:@"2"];
        passed &= [files contentsOfDirectoryAtPath:destination.stringByDeletingLastPathComponent
                                             error:NULL]
                      .count == 1;
        NSString *foreign = [root stringByAppendingPathComponent:@"Applications/Foreign.app"];
        WriteBundle(foreign, @"org.example.other", @"original");
        NSError *error = nil;
        passed &= !InstallBundle(source, foreign, identifier, nil, &error) && error != nil;
        passed &= [[NSString
            stringWithContentsOfFile:[foreign
                                         stringByAppendingPathComponent:@"Contents/MacOS/TestApp"]
                            encoding:NSUTF8StringEncoding
                               error:NULL] isEqual:@"original"];
        [files removeItemAtPath:root error:NULL];
        puts(passed ? "Application installation checks passed."
                    : "Application installation checks failed.");
        return passed ? 0 : 1;
    }
}
