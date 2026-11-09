#import "WallpaperRenderer.h"
#import "DepartureBoardView.h"
#import "LiveFlightStore.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation DBWallpaperRenderer

+ (NSString *)rootPath {

    return [[LiveFlightStore userHome]
        stringByAppendingPathComponent:@"Library/Application Support/DepartureBoard/Wallpapers"];
}

+ (NSString *)identifierForScreen:(NSScreen *)screen {

    CGDirectDisplayID display = [screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue];
    CFUUIDRef uuid = CGDisplayCreateUUIDFromDisplayID(display);
    NSString *identifier = uuid ? CFBridgingRelease(CFUUIDCreateString(NULL, uuid))
                                : [NSString stringWithFormat:@"%u", display];

    if (uuid) {
        CFRelease(uuid);
    }
    return identifier;
}

+ (NSEdgeInsets)contentInsetsForScreen:(NSScreen *)screen {

    if (!screen || screen.frame.size.width <= 0 || screen.frame.size.height <= 0) {
        return NSEdgeInsetsMake(0, 0, 0, 0);
    }
    NSRect frame = screen.frame;
    NSRect visible = NSIntersectionRect(frame, screen.visibleFrame);
    CGFloat margin = 12;
    return NSEdgeInsetsMake((NSMaxY(frame) - NSMaxY(visible) + margin) / frame.size.height,
                            (NSMinX(visible) - NSMinX(frame) + margin) / frame.size.width,
                            (NSMinY(visible) - NSMinY(frame) + margin) / frame.size.height,
                            (NSMaxX(frame) - NSMaxX(visible) + margin) / frame.size.width);
}

+ (void)removeLegacyHistory {

    NSString *domain = [[LiveFlightStore userHome]
        stringByAppendingPathComponent:
            @"Library/Containers/com.apple.wallpaper.extension.image/Data/Library/Preferences/"
             "com.apple.wallpaper.extension.image"];
    NSArray *entries = CFBridgingRelease(CFPreferencesCopyAppValue(
        CFSTR("ChoiceRequests.ImageFiles"), (__bridge CFStringRef)domain));

    if (![entries isKindOfClass:NSArray.class]) {
        return;
    }
    NSString *legacyRoot = [self.rootPath stringByAppendingString:@"/Frames/"];
    NSMutableArray *retained = NSMutableArray.new;

    for (id entry in entries) {
        NSDictionary *record = [entry isKindOfClass:NSData.class]
                                   ? [NSPropertyListSerialization propertyListWithData:entry
                                                                               options:0
                                                                                format:NULL
                                                                                 error:NULL]
                                   : nil;
        id original = [record isKindOfClass:NSDictionary.class] ? record[@"originalURL"] : nil;
        NSString *urlString =
            [original isKindOfClass:NSDictionary.class] ? original[@"relative"] : nil;
        NSURL *url =
            [urlString isKindOfClass:NSString.class] ? [NSURL URLWithString:urlString] : nil;

        if (![url.path hasPrefix:legacyRoot]) {
            [retained addObject:entry];
        }
    }

    if (retained.count == entries.count) {
        return;
    }
    NSString *backup = [self.rootPath stringByAppendingPathComponent:@"LegacyHistoryBackup.plist"];

    if (![NSFileManager.defaultManager fileExistsAtPath:backup]) {
        if (![entries writeToFile:backup atomically:YES]) {
            return;
        }
        [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions : @0600}
                                       ofItemAtPath:backup
                                              error:NULL];
    }
    CFPreferencesSetAppValue(CFSTR("ChoiceRequests.ImageFiles"), (__bridge CFArrayRef)retained,
                             (__bridge CFStringRef)domain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)domain);
}

+ (BOOL)renderRequest:(NSDictionary *)request {

    if (![request isKindOfClass:NSDictionary.class] ||
        ![request[@"screens"] isKindOfClass:NSArray.class]) {
        return NO;
    }
    NSFileManager *files = NSFileManager.defaultManager;
    NSString *frames = [self.rootPath stringByAppendingPathComponent:@"Displays"];

    if (![files createDirectoryAtPath:frames
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:NULL]) {
        return NO;
    }
    NSString *originalsPath = [self.rootPath stringByAppendingPathComponent:@"Originals.plist"];
    NSMutableDictionary *originals =
        [[NSDictionary dictionaryWithContentsOfFile:originalsPath] mutableCopy]
            ?: NSMutableDictionary.new;
    BOOL success = YES;
    NSMutableDictionary<NSDictionary *, NSString *> *renderedScreens = NSMutableDictionary.new;

    for (NSDictionary *item in request[@"screens"]) {
        @autoreleasepool {
            if (![item isKindOfClass:NSDictionary.class] ||
                ![item[@"identifier"] isKindOfClass:NSString.class] ||
                ![item[@"board"] isKindOfClass:NSDictionary.class]) {
                return NO;
            }
            NSScreen *screen = nil;

            for (NSScreen *candidate in NSScreen.screens) {
                if ([[self identifierForScreen:candidate] isEqual:item[@"identifier"]]) {
                    screen = candidate;
                    break;
                }
            }

            if (!screen) {
                continue;
            }
            NSString *identifier = item[@"identifier"];
            NSURL *current = [NSWorkspace.sharedWorkspace desktopImageURLForScreen:screen];

            if (!originals[identifier] && current && ![current.path hasPrefix:self.rootPath]) {
                NSDictionary *options =
                    [NSWorkspace.sharedWorkspace desktopImageOptionsForScreen:screen];
                originals[identifier] = @{
                    @"url" : current.absoluteString,
                    @"scaling" : options[NSWorkspaceDesktopImageScalingKey]
                        ?: @(NSImageScaleProportionallyUpOrDown),
                    @"clipping" : options[NSWorkspaceDesktopImageAllowClippingKey] ?: @YES
                };
                [originals writeToFile:originalsPath atomically:YES];
            }
            NSSize pixels = NSMakeSize(screen.frame.size.width * screen.backingScaleFactor,
                                       screen.frame.size.height * screen.backingScaleFactor);
            NSString *folder = [frames stringByAppendingPathComponent:identifier];
            [files createDirectoryAtPath:folder
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL];
            NSString *path = [folder stringByAppendingPathComponent:@"Departure Board.png"];
            NSDictionary *renderKey =
                @{@"size" : NSStringFromSize(pixels), @"board" : item[@"board"]};
            NSString *rendered = renderedScreens[renderKey];
            BOOL written;

            if (rendered) {
                // Equal Retina displays share one render and PNG encoding.
                NSData *png = [NSData dataWithContentsOfFile:rendered
                                                     options:NSDataReadingMappedIfSafe
                                                       error:NULL];
                written = [png writeToFile:path atomically:YES];
            } else {
                DBBoardView *board = [[DBBoardView alloc]
                    initWithFrame:NSMakeRect(0, 0, pixels.width, pixels.height)];
                [board applySnapshotConfiguration:item[@"board"]];
                board.contentInsets = [self contentInsetsForScreen:screen];
                written = [board writeSnapshot:path size:pixels];

                if (written) {
                    renderedScreens[renderKey] = path;
                }
            }

            if (!written) {
                success = NO;
                continue;
            }
            success &= [NSWorkspace.sharedWorkspace
                setDesktopImageURL:[NSURL fileURLWithPath:path]
                         forScreen:screen
                           options:@{
                               NSWorkspaceDesktopImageScalingKey :
                                   @(NSImageScaleProportionallyUpOrDown),
                               NSWorkspaceDesktopImageAllowClippingKey : @NO
                           }
                             error:NULL];
        }
    }

    if (success) {
        [self removeLegacyHistory];
    }
    return success;
}

@end
