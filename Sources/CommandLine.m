#import "CommandLine.h"
#import "BackgroundAgent.h"
#import "DepartureBoardView.h"
#import "LiveFlightStore.h"
#import "UserInstallation.h"
#import "WallpaperRenderer.h"
#import <CoreGraphics/CoreGraphics.h>
#import <unistd.h>

static NSString *ArgumentValue(NSArray<NSString *> *arguments, NSString *option) {
    NSUInteger index = [arguments indexOfObject:option];
    return index != NSNotFound && index + 1 < arguments.count ? arguments[index + 1] : nil;
}

@implementation DBCommandLine
+ (DBBoardView *)boardWithArguments:(NSArray<NSString *> *)arguments {
    DBBoardView *board = [[DBBoardView alloc] initWithFrame:NSMakeRect(0, 0, 1440, 900)];
    NSString *location = ArgumentValue(arguments, @"--location");
    NSString *style = ArgumentValue(arguments, @"--style");
    NSString *language = ArgumentValue(arguments, @"--language");
    if (location)
        board.locationCode = location;
    if (style)
        board.displayStyle = style;
    if (language)
        board.languageMode = language;
    return board;
}

+ (BOOL)renderSnapshots:(NSArray<NSString *> *)arguments {
    [NSApplication.sharedApplication setActivationPolicy:NSApplicationActivationPolicyProhibited];
    DBBoardView *board = [self boardWithArguments:arguments];
    NSString *path = ArgumentValue(arguments, @"--snapshot");
    if (path) {
        if ([arguments containsObject:@"--live-data"])
            board.useSampleData = NO;
        else
            board.referenceDate = [NSDate dateWithTimeIntervalSince1970:1794214800];
        NSSize size = NSMakeSize(1920, 1080);
        NSArray *dimensions = [ArgumentValue(arguments, @"--snapshot-size") componentsSeparatedByString:@"x"];
        if (dimensions.count == 2 && [dimensions[0] doubleValue] > 0 && [dimensions[1] doubleValue] > 0)
            size = NSMakeSize([dimensions[0] doubleValue], [dimensions[1] doubleValue]);
        BOOL saved = [board writeSnapshot:path size:size];
        fprintf(saved ? stdout : stderr, "Snapshot %s: %s\n", saved ? "saved" : "failed", path.UTF8String);
        return saved;
    }
    NSString *directory = ArgumentValue(arguments, @"--snapshot-all");
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:NULL])
        return NO;
    board.referenceDate = [NSDate dateWithTimeIntervalSince1970:1794214800];
    board.languageMode = @"native";
    BOOL success = YES;
    for (NSDictionary *location in DBLocations()) {
        board.locationCode = location[@"code"];
        NSString *destination =
            [directory stringByAppendingPathComponent:[location[@"code"] stringByAppendingString:@".png"]];
        NSSize size = NSMakeSize(1920, 1080);
        if ([arguments containsObject:@"--reference-size"] && location[@"display"][@"referenceAspect"]) {
            CGFloat aspect = [location[@"display"][@"referenceAspect"] doubleValue];
            size =
                aspect >= 1 ? NSMakeSize(1600, round(1600 / aspect)) : NSMakeSize(round(1200 * aspect), 1200);
        }
        success &= [board writeSnapshot:destination size:size];
    }
    fprintf(success ? stdout : stderr, "Rendered %lu board snapshots: %s\n",
            (unsigned long)DBLocations().count, directory.UTF8String);
    return success;
}

+ (NSNumber *)runWithArguments:(NSArray<NSString *> *)arguments {
    NSString *command = arguments.count > 1 ? arguments[1] : nil;
    NSString *value = arguments.count > 2 ? arguments[2] : nil;
    if ([command isEqual:@"--version"]) {
        NSString *version =
            NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"development";
        puts(version.UTF8String);
        return @0;
    }
    if ([command isEqual:@"--install-bundles"] && arguments.count == 3) {
        NSError *error = nil;
        BOOL installed = RegisterUserInstallation(value, &error);
        if (!installed)
            fprintf(stderr, "%s\n", error.localizedDescription.UTF8String ?: "Invalid installation root.");
        return @(installed ? 0 : 1);
    }
    if ([command isEqual:@"--import-api-key"] && value) {
        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:value error:NULL];
        if ([attributes[NSFileOwnerAccountID] unsignedIntValue] != getuid() ||
            ([attributes[NSFilePosixPermissions] unsignedIntValue] & 0077) != 0)
            return @1;
        NSString *key = [[NSString stringWithContentsOfFile:value encoding:NSUTF8StringEncoding error:NULL]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        return @([LiveFlightStore saveAPIKey:key error:NULL] ? 0 : 1);
    }
    if ([command isEqual:@"--render-wallpapers"] && arguments.count == 3) {
        NSDictionary *request =
            [NSJSONSerialization JSONObjectWithData:[value dataUsingEncoding:NSUTF8StringEncoding]
                                            options:0
                                              error:NULL];
        if (![request isKindOfClass:NSDictionary.class])
            return @1;
        if (![request[@"force"] boolValue] &&
            ([LiveFlightStore screenSaverIsActive] ||
             CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateCombinedSessionState,
                                                    kCGAnyInputEventType) >= 30))
            return @0;
        [NSApplication.sharedApplication setActivationPolicy:NSApplicationActivationPolicyProhibited];
        return @([DBWallpaperRenderer renderRequest:request] ? 0 : 1);
    }
    if ([command isEqual:@"--refresh-data"] || [command isEqual:@"--maintain-background"]) {
        [DBBackgroundAgent performMaintenance];
        return @0;
    }
    if ([command isEqual:@"--refresh-airport"] && value) {
        NSError *error = nil;
        BOOL refreshed = [LiveFlightStore refreshAirport:value error:&error];
        if (!refreshed)
            fprintf(stderr, "%s\n", error.localizedDescription.UTF8String ?: "Could not refresh flights.");
        return @(refreshed ? 0 : 1);
    }
    if (ArgumentValue(arguments, @"--snapshot") || ArgumentValue(arguments, @"--snapshot-all"))
        return @([self renderSnapshots:arguments] ? 0 : 1);
    return nil;
}
@end
