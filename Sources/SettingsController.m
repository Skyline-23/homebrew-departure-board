#import "BackgroundAgent.h"
#import "BoardViewInternal.h"
#import "DrawingSupport.h"
#import "LiveFlightStore.h"
#import "SettingsStore.h"

@implementation DBBoardView (SettingsController)

- (NSWindow *)settingsWindowWithTarget:(id)target action:(SEL)action {
    NSWindow *window = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 700, 798)
                                                  styleMask:NSWindowStyleMaskTitled
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    window.title = DBUIString(@"settings.title");
    window.releasedWhenClosed = NO;
    NSView *v = window.contentView;
    NSTextField *title = [NSTextField labelWithString:@"Departure Board"];
    title.font = DBFont(23, YES, NO);
    title.frame = NSMakeRect(28, 392, 520, 32);
    [v addSubview:title];
    NSArray *labels = @[
        DBUIString(@"settings.location"), DBUIString(@"settings.style"), DBUIString(@"settings.language"),
        DBUIString(@"settings.density"), DBUIString(@"settings.brightness")
    ];
    for (NSInteger i = 0; i < 5; i++) {
        NSTextField *label = [NSTextField labelWithString:labels[i]];
        label.frame = NSMakeRect(29, 341 - i * 48, 130, 25);
        [v addSubview:label];
    }
    NSPopUpButton *locations = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(161, 339, 397, 29)
                                                          pullsDown:NO];
    locations.tag = 101;
    for (NSDictionary *l in DBLocations()) {
        [locations addItemWithTitle:DBUIString(l[@"displayNameKey"])];
        locations.lastItem.representedObject = l[@"code"];
        if ([l[@"code"] isEqual:self.locationCode])
            [locations selectItem:locations.lastItem];
    }
    [v addSubview:locations];
    NSArray *options = @[
        @[ DBUIString(@"style.auto"), DBUIString(@"style.lcd"), DBUIString(@"style.flap") ],
        @[
            DBUIString(@"language.alternate"), DBUIString(@"language.native"), DBUIString(@"language.english")
        ],
        @[
            DBUIString(@"density.reference"), DBUIString(@"density.10"), DBUIString(@"density.12"),
            DBUIString(@"density.16")
        ]
    ];
    NSArray *values =
        @[ @[ @"auto", @"lcd", @"flap" ], @[ @"alternate", @"native", @"english" ], @[ @0, @10, @12, @16 ] ];
    NSArray *current = @[ self.displayStyle, self.languageMode, @(self.density) ];
    for (NSInteger i = 0; i < 3; i++) {
        NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(161, 291 - i * 48, 397, 29)
                                                          pullsDown:NO];
        popup.tag = 102 + i;
        [popup addItemsWithTitles:options[i]];
        for (NSInteger j = 0; j < (NSInteger)popup.numberOfItems; j++) {
            [popup itemAtIndex:j].representedObject = values[i][j];
            if ([values[i][j] isEqual:current[i]])
                [popup selectItemAtIndex:j];
        }
        [v addSubview:popup];
    }
    NSSlider *brightness = [NSSlider sliderWithValue:self.brightness
                                            minValue:.35
                                            maxValue:1
                                              target:nil
                                              action:NULL];
    brightness.frame = NSMakeRect(161, 147, 397, 26);
    brightness.tag = 105;
    [v addSubview:brightness];
    NSButton *motion = [NSButton checkboxWithTitle:DBUIString(@"settings.reduceMotion")
                                            target:nil
                                            action:NULL];
    motion.tag = 106;
    motion.state = self.reducedMotion;
    motion.frame = NSMakeRect(161, 107, 397, 24);
    [v addSubview:motion];
    for (NSView *view in v.subviews) {
        NSRect frame = view.frame;
        frame.origin.y += 220;
        view.frame = frame;
    }
    NSDictionary *saved = DBSettingsStore.settings;
    NSButton *desktop = [NSButton checkboxWithTitle:DBUIString(@"settings.desktop") target:nil action:NULL];
    desktop.tag = 204;
    desktop.state = [saved[@"desktopEnabled"] boolValue];
    desktop.frame = NSMakeRect(161, 284, 250, 24);
    [v addSubview:desktop];
    NSButton *wallpaper = [NSButton buttonWithTitle:DBUIString(@"settings.setWallpaper")
                                             target:target
                                             action:@selector(applyWallpaper:)];
    wallpaper.bezelStyle = NSBezelStyleRounded;
    wallpaper.frame = NSMakeRect(452, 278, 206, 32);
    wallpaper.tag = 207;
    [v addSubview:wallpaper];
    NSTextField *refreshLabel = [NSTextField labelWithString:DBUIString(@"settings.refresh")];
    refreshLabel.frame = NSMakeRect(29, 245, 130, 25);
    [v addSubview:refreshLabel];
    NSPopUpButton *refresh = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(161, 243, 497, 29) pullsDown:NO];
    refresh.tag = 206;
    for (NSNumber *interval in @[ @60, @300, @900, @3600, @21600 ]) {
        [refresh addItemWithTitle:DBUIString([NSString stringWithFormat:@"refresh.%@", interval])];
        refresh.lastItem.representedObject = interval;
        if (interval.integerValue ==
            (saved[@"refreshInterval"] ? [saved[@"refreshInterval"] integerValue] : 60))
            [refresh selectItem:refresh.lastItem];
    }
    [v addSubview:refresh];
    NSDictionary *snapshot = [LiveFlightStore cachedSnapshotForAirport:self.locationCode];
    NSString *updated = snapshot[@"fetchedAt"] ?: DBUIString(@"settings.neverUpdated");
    NSDate *date = [NSISO8601DateFormatter.new dateFromString:updated];
    if (!date) {
        NSISO8601DateFormatter *formatter = NSISO8601DateFormatter.new;
        formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
        date = [formatter dateFromString:updated];
    }
    if (date)
        updated = DBTime(date, self.location, @"dd MMM yyyy, HH:mm z");
    NSInteger failure = [LiveFlightStore refreshFailureStatusForAirport:self.locationCode];
    NSString *issue = failure == 401 ? @"settings.apiAuthenticationFailed"
                      : failure == 403 ? @"settings.apiSubscriptionRequired"
                      : failure == 429 ? @"settings.apiRateLimited" : nil;
    NSTextField *lastUpdate =
        [NSTextField labelWithString:issue ? DBUIString(issue)
                    : [NSString stringWithFormat:DBUIString(@"settings.lastUpdate"), updated]];
    lastUpdate.frame = NSMakeRect(161, 215, 497, 22);
    lastUpdate.textColor = issue ? NSColor.systemOrangeColor : NSColor.secondaryLabelColor;
    lastUpdate.font = DBFont(11, NO, NO);
    [v addSubview:lastUpdate];
    NSArray *extraLabels = @[ @"settings.data", @"settings.provider", @"settings.apiKey" ];
    for (NSInteger index = 0; index < 3; index++) {
        NSTextField *label = [NSTextField labelWithString:DBUIString(extraLabels[index])];
        label.frame = NSMakeRect(29, 181 - index * 44, 130, 25);
        [v addSubview:label];
    }
    NSPopUpButton *source = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(161, 179, 497, 29) pullsDown:NO];
    source.tag = 203;
    [source addItemsWithTitles:@[ DBUIString(@"data.live"), DBUIString(@"data.sample") ]];
    [source selectItemAtIndex:self.useSampleData ? 1 : 0];
    [v addSubview:source];
    NSTextField *provider = [NSTextField labelWithString:@"AeroDataBox · RapidAPI"];
    provider.frame = NSMakeRect(161, 137, 497, 25);
    [v addSubview:provider];
    NSSecureTextField *apiKey = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(161, 93, 497, 25)];
    apiKey.tag = 202;
    apiKey.placeholderString = DBUIString(@"settings.apiKeyHint");
    BOOL keySaved = [saved[@"hasAPIKey"] boolValue];
    if (keySaved)
        apiKey.stringValue = DBStoredAPIKeyMask;
    [v addSubview:apiKey];
    NSTextField *keyNote = [NSTextField
        labelWithString:DBUIString(keySaved ? @"settings.apiKeySaved" : @"settings.apiKeyMissing")];
    keyNote.frame = NSMakeRect(161, 58, 497, 25);
    keyNote.font = DBFont(11, NO, NO);
    keyNote.textColor = NSColor.secondaryLabelColor;
    [v addSubview:keyNote];
    NSButton *done = [NSButton buttonWithTitle:DBUIString(@"settings.apply") target:target action:action];
    done.bezelStyle = NSBezelStyleRounded;
    done.keyEquivalent = @"\r";
    done.tag = 205;
    done.frame = NSMakeRect(468, 24, 92, 32);
    [v addSubview:done];
    for (NSView *view in v.subviews) {
        if (view.frame.origin.y >= 278) {
            NSRect frame = view.frame;
            frame.origin.y += 136;
            view.frame = frame;
        }
    }
    NSButton *login = [NSButton checkboxWithTitle:DBUIString(@"settings.launchAtLogin")
                                           target:nil
                                           action:NULL];
    login.tag = 208;
    login.state = [saved[@"launchAtLogin"] boolValue];
    login.frame = NSMakeRect(161, 328, 497, 24);
    [v addSubview:login];
    NSButton *spaces = [NSButton checkboxWithTitle:DBUIString(@"settings.showAllSpaces") target:nil action:NULL];
    spaces.tag = 209;
    spaces.state = (!saved[@"showAllSpaces"] || [saved[@"showAllSpaces"] boolValue])
                       ? NSControlStateValueOn : NSControlStateValueOff;
    spaces.frame = NSMakeRect(161, 284, 497, 24);
    [v addSubview:spaces];
    NSTextField *scaleLabel = [NSTextField labelWithString:DBUIString(@"settings.boardScale")];
    scaleLabel.frame = NSMakeRect(29, 376, 130, 25);
    [v addSubview:scaleLabel];
    NSPopUpButton *scale = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(161, 374, 497, 29) pullsDown:NO];
    scale.tag = 210;
    for (NSNumber *value in @[ @.5, @.65, @.75, @.85, @1.0 ]) {
        [scale addItemWithTitle:[NSString stringWithFormat:@"%.0f%%", value.doubleValue * 100]];
        scale.lastItem.representedObject = value;
        if (fabs(value.doubleValue - self.boardScale) < .001)
            [scale selectItem:scale.lastItem];
    }
    [v addSubview:scale];
    self.optionsWindow = window;
    return window;
}

- (void)applySettingsFromWindow:(NSWindow *)window completion:(void (^)(BOOL saved))completion {
    NSView *v = window.contentView;
    NSMutableDictionary *saved = [DBSettingsStore.settings mutableCopy];
    saved[@"location"] = [(NSPopUpButton *)[v viewWithTag:101] selectedItem].representedObject;
    saved[@"style"] = [(NSPopUpButton *)[v viewWithTag:102] selectedItem].representedObject;
    saved[@"language"] = [(NSPopUpButton *)[v viewWithTag:103] selectedItem].representedObject;
    saved[@"density"] = [(NSPopUpButton *)[v viewWithTag:104] selectedItem].representedObject;
    saved[@"brightness"] = @([(NSSlider *)[v viewWithTag:105] doubleValue]);
    saved[@"reduceMotion"] = @([(NSButton *)[v viewWithTag:106] state] == NSControlStateValueOn);
    saved[@"sampleData"] = @([(NSPopUpButton *)[v viewWithTag:203] indexOfSelectedItem] == 1);
    saved[@"desktopEnabled"] = @([(NSButton *)[v viewWithTag:204] state] == NSControlStateValueOn);
    saved[@"refreshInterval"] = [(NSPopUpButton *)[v viewWithTag:206] selectedItem].representedObject;
    saved[@"launchAtLogin"] = @([(NSButton *)[v viewWithTag:208] state] == NSControlStateValueOn);
    saved[@"showAllSpaces"] = @([(NSButton *)[v viewWithTag:209] state] == NSControlStateValueOn);
    saved[@"boardScale"] = [(NSPopUpButton *)[v viewWithTag:210] selectedItem].representedObject;
    NSButton *button = (NSButton *)[v viewWithTag:205];
    button.enabled = NO;
    button.title = DBUIString(@"settings.saving");
    [DBSettingsStore
           submitSettings:saved
        replacementAPIKey:[(NSSecureTextField *)[v viewWithTag:202] stringValue]
               completion:^(NSError *error) {
                   button.enabled = YES;
                   button.title = DBUIString(@"settings.apply");
                   if (error) {
                       NSAlert *alert = NSAlert.new;
                       alert.messageText = DBUIString(@"settings.saveFailed");
                       alert.informativeText = error.localizedDescription;
                       [alert runModal];
                       completion(NO);
                       return;
                   }
                   [self reloadSettings];
                   if ([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.skyline23.departureboard"]) {
                       [DBBackgroundAgent configure];
                       if ([DBSettingsStore.settings[@"hasAPIKey"] boolValue] && !self.useSampleData)
                           [LiveFlightStore refreshInBackground];
                   }
                   completion(YES);
               }];
}

@end
