#import "BackgroundAgent.h"
#import "BoardViewInternal.h"
#import "DrawingSupport.h"
#import "InstallationGuide.h"
#import "LiveFlightStore.h"
#import "SettingsStore.h"

@interface DBSettingsDocumentView : NSView
@end

@implementation DBSettingsDocumentView

- (BOOL)isFlipped {

    return YES;
}

@end

static NSTextField *DBSettingsLabel(NSString *text) {

    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:13];
    label.textColor = NSColor.secondaryLabelColor;
    return label;
}

static NSArray<NSView *> *DBSettingsRow(NSString *label, NSView *control) {

    if ([control isKindOfClass:NSControl.class]) {
        [(NSControl *)control setFont:[NSFont systemFontOfSize:13]];
    }

    if (label.length) {
        [control setAccessibilityLabel:label];
    }
    [control.heightAnchor constraintGreaterThanOrEqualToConstant:28].active = YES;
    return @[ DBSettingsLabel(label), control ];
}

static NSView *DBSettingsGrid(NSArray<NSArray<NSView *> *> *rows) {

    NSGridView *grid = [NSGridView gridViewWithViews:rows];
    grid.rowSpacing = 12;
    grid.columnSpacing = 18;
    grid.yPlacement = NSGridCellPlacementCenter;
    grid.xPlacement = NSGridCellPlacementFill;
    [grid columnAtIndex:0].width = 128;
    [grid columnAtIndex:0].xPlacement = NSGridCellPlacementLeading;
    return grid;
}

static NSView *DBSettingsGroup(NSString *heading, NSView *body) {

    NSBox *box = NSBox.new;
    box.boxType = NSBoxCustom;
    box.borderWidth = 1;
    box.borderColor = NSColor.separatorColor;
    box.fillColor = NSColor.controlBackgroundColor;
    box.cornerRadius = 10;
    box.contentViewMargins = NSZeroSize;
    NSTextField *title = [NSTextField labelWithString:heading];
    title.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    body.translatesAutoresizingMaskIntoConstraints = NO;
    [box.contentView addSubview:title];
    [box.contentView addSubview:body];
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:box.contentView.topAnchor constant:18],
        [title.leadingAnchor constraintEqualToAnchor:box.contentView.leadingAnchor constant:20],
        [body.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:16],
        [body.leadingAnchor constraintEqualToAnchor:box.contentView.leadingAnchor constant:20],
        [body.trailingAnchor constraintEqualToAnchor:box.contentView.trailingAnchor constant:-20],
        [body.bottomAnchor constraintEqualToAnchor:box.contentView.bottomAnchor constant:-18]
    ]];
    return box;
}

@implementation DBBoardView (SettingsController)

- (NSWindow *)settingsWindowWithTarget:(id)target action:(SEL)action {

    NSWindow *window =
        [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 720, 760)
                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskResizable
                                     backing:NSBackingStoreBuffered

                                       defer:NO];
    window.title = DBUIString(@"settings.title");
    window.contentMinSize = NSMakeSize(620, 500);
    window.releasedWhenClosed = NO;
    NSView *root = window.contentView;
    NSDictionary *saved = DBSettingsStore.settings;
    NSPopUpButton *locations = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    locations.tag = 101;

    for (NSDictionary *location in DBLocations()) {
        [locations addItemWithTitle:DBUIString(location[@"displayNameKey"])];
        locations.lastItem.representedObject = location[@"code"];

        if ([location[@"code"] isEqual:self.locationCode]) {
            [locations selectItem:locations.lastItem];
        }
    }
    NSArray *options = @[
        @[ DBUIString(@"style.auto"), DBUIString(@"style.lcd"), DBUIString(@"style.flap") ],
        @[
            DBUIString(@"language.alternate"), DBUIString(@"language.native"),
            DBUIString(@"language.english")
        ],
        @[
            DBUIString(@"density.reference"), DBUIString(@"density.10"), DBUIString(@"density.12"),
            DBUIString(@"density.16")
        ]
    ];
    NSArray *values = @[
        @[ @"auto", @"lcd", @"flap" ], @[ @"alternate", @"native", @"english" ],
        @[ @0, @10, @12, @16 ]
    ];
    NSArray *current = @[ self.displayStyle, self.languageMode, @(self.density) ];
    NSMutableArray<NSPopUpButton *> *popups = NSMutableArray.new;

    for (NSInteger i = 0; i < 3; i++) {
        NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
        popup.tag = 102 + i;
        [popup addItemsWithTitles:options[i]];

        for (NSInteger j = 0; j < popup.numberOfItems; j++) {
            [popup itemAtIndex:j].representedObject = values[i][j];

            if ([values[i][j] isEqual:current[i]]) {
                [popup selectItemAtIndex:j];
            }
        }
        [popups addObject:popup];
    }
    NSSlider *brightness = [NSSlider sliderWithValue:self.brightness
                                            minValue:.35
                                            maxValue:1
                                              target:nil
                                              action:NULL];
    brightness.tag = 105;
    NSButton *motion = [NSButton checkboxWithTitle:DBUIString(@"settings.reduceMotion")
                                            target:nil
                                            action:NULL];
    motion.tag = 106;
    motion.state = self.reducedMotion;
    NSPopUpButton *scale = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    scale.tag = 210;

    for (NSNumber *value in @[ @.5, @.65, @.75, @.85, @1.0 ]) {
        [scale addItemWithTitle:[NSString stringWithFormat:@"%.0f%%", value.doubleValue * 100]];
        scale.lastItem.representedObject = value;

        if (fabs(value.doubleValue - self.boardScale) < .001) {
            [scale selectItem:scale.lastItem];
        }
    }
    NSView *displayGroup =
        DBSettingsGroup(DBUIString(@"settings.groupDisplay"), DBSettingsGrid(@[
                            DBSettingsRow(DBUIString(@"settings.location"), locations),
                            DBSettingsRow(DBUIString(@"settings.language"), popups[1]),
                            DBSettingsRow(DBUIString(@"settings.style"), popups[0]),
                            DBSettingsRow(DBUIString(@"settings.density"), popups[2]),
                            DBSettingsRow(DBUIString(@"settings.boardScale"), scale),
                            DBSettingsRow(DBUIString(@"settings.brightness"), brightness),
                            DBSettingsRow(@"", motion)
                        ]));

    NSButton *desktop = [NSButton checkboxWithTitle:DBUIString(@"settings.desktop")
                                             target:nil
                                             action:NULL];
    desktop.tag = 204;
    desktop.state = [saved[@"desktopEnabled"] boolValue];
    NSButton *spaces = [NSButton checkboxWithTitle:DBUIString(@"settings.showAllSpaces")
                                            target:nil
                                            action:NULL];
    spaces.tag = 209;
    spaces.state = !saved[@"showAllSpaces"] || [saved[@"showAllSpaces"] boolValue];
    NSButton *login = [NSButton checkboxWithTitle:DBUIString(@"settings.launchAtLogin")
                                           target:nil
                                           action:NULL];
    login.tag = 208;
    login.state = [saved[@"launchAtLogin"] boolValue];
    NSButton *wallpaper = [NSButton buttonWithTitle:DBUIString(@"settings.setWallpaper")
                                             target:target
                                             action:@selector(applyWallpaper:)];
    wallpaper.bezelStyle = NSBezelStyleRounded;
    wallpaper.tag = 207;
    NSButton *saver = [NSButton buttonWithTitle:DBUIString(@"menu.screensaver")
                                         target:target
                                         action:@selector(openScreenSaverSettings:)];
    saver.bezelStyle = NSBezelStyleRounded;
    NSStackView *desktopActions = [NSStackView stackViewWithViews:@[ wallpaper, saver ]];
    desktopActions.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    desktopActions.spacing = 10;
    NSStackView *desktopOptions =
        [NSStackView stackViewWithViews:@[ desktop, spaces, login, desktopActions ]];
    desktopOptions.orientation = NSUserInterfaceLayoutOrientationVertical;
    desktopOptions.alignment = NSLayoutAttributeLeading;
    desktopOptions.spacing = 14;
    NSView *desktopGroup = DBSettingsGroup(DBUIString(@"settings.groupDesktop"), desktopOptions);

    NSPopUpButton *refresh = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    refresh.tag = 206;

    for (NSNumber *interval in @[ @60, @300, @900, @3600, @21600 ]) {
        [refresh addItemWithTitle:DBUIString([NSString stringWithFormat:@"refresh.%@", interval])];
        refresh.lastItem.representedObject = interval;

        if (interval.integerValue ==
            (saved[@"refreshInterval"] ? [saved[@"refreshInterval"] integerValue] : 300)) {
            [refresh selectItem:refresh.lastItem];
        }
    }
    NSPopUpButton *source = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    source.tag = 203;
    [source addItemsWithTitles:@[ DBUIString(@"data.live"), DBUIString(@"data.sample") ]];
    [source selectItemAtIndex:self.useSampleData ? 1 : 0];
    NSSecureTextField *apiKey = [[NSSecureTextField alloc] initWithFrame:NSZeroRect];
    apiKey.tag = 202;
    apiKey.placeholderString = DBUIString(@"settings.apiKeyHint");
    BOOL keySaved = [saved[@"hasAPIKey"] boolValue];

    if (keySaved) {
        apiKey.stringValue = DBStoredAPIKeyMask;
    }
    NSTextField *provider = DBSettingsLabel(@"AeroDataBox · RapidAPI");
    NSDictionary *snapshot = [LiveFlightStore cachedSnapshotForAirport:self.locationCode];
    NSString *updated = snapshot[@"fetchedAt"] ?: DBUIString(@"settings.neverUpdated");
    NSDate *date = [NSISO8601DateFormatter.new dateFromString:updated];

    if (!date) {
        NSISO8601DateFormatter *formatter = NSISO8601DateFormatter.new;
        formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
        date = [formatter dateFromString:updated];
    }

    if (date) {
        updated = DBTime(date, self.location, @"dd MMM yyyy, HH:mm z");
    }
    NSInteger failure =
        self.useSampleData ? 0 : [LiveFlightStore refreshFailureStatusForAirport:self.locationCode];
    NSString *issue = failure == 401   ? @"settings.apiAuthenticationFailed"
                      : failure == 403 ? @"settings.apiSubscriptionRequired"
                      : failure == 429 ? @"settings.apiRateLimited"
                                       : nil;
    NSTextField *lastUpdate = DBSettingsLabel(
        self.useSampleData ? DBUIString(@"data.sample")
        : issue            ? DBUIString(issue)
                : [NSString stringWithFormat:DBUIString(@"settings.lastUpdate"), updated]);
    lastUpdate.textColor = issue ? NSColor.systemOrangeColor : NSColor.secondaryLabelColor;
    NSTextField *keyNote =
        DBSettingsLabel(DBUIString(keySaved ? @"settings.apiKeySaved" : @"settings.apiKeyMissing"));
    NSView *dataGroup =
        DBSettingsGroup(DBUIString(@"settings.groupData"), DBSettingsGrid(@[
                            DBSettingsRow(DBUIString(@"settings.data"), source),
                            DBSettingsRow(DBUIString(@"settings.apiKey"), apiKey),
                            DBSettingsRow(DBUIString(@"settings.refresh"), refresh),
                            DBSettingsRow(DBUIString(@"settings.provider"), provider),
                            DBSettingsRow(@"", lastUpdate), DBSettingsRow(@"", keyNote)
                        ]));

    NSImageView *icon =
        [NSImageView imageViewWithImage:[NSImage imageNamed:NSImageNameApplicationIcon]];
    [icon.widthAnchor constraintEqualToConstant:44].active = YES;
    [icon.heightAnchor constraintEqualToConstant:44].active = YES;
    NSTextField *title = [NSTextField labelWithString:@"Departure Board"];
    title.font = [NSFont systemFontOfSize:24 weight:NSFontWeightSemibold];
    NSStackView *heading = [NSStackView
        stackViewWithViews:@[ title, DBSettingsLabel(DBUIString(@"settings.subtitle")) ]];
    heading.orientation = NSUserInterfaceLayoutOrientationVertical;
    heading.alignment = NSLayoutAttributeLeading;
    heading.spacing = 3;
    NSStackView *header = [NSStackView stackViewWithViews:@[ icon, heading ]];
    header.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    header.spacing = 14;
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:header];
    NSScrollView *scroll = NSScrollView.new;
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = NO;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:scroll];
    DBSettingsDocumentView *document = DBSettingsDocumentView.new;
    document.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = document;
    NSStackView *groups =
        [NSStackView stackViewWithViews:@[ displayGroup, desktopGroup, dataGroup ]];
    groups.orientation = NSUserInterfaceLayoutOrientationVertical;
    groups.alignment = NSLayoutAttributeLeading;
    groups.spacing = 16;
    groups.translatesAutoresizingMaskIntoConstraints = NO;
    [document addSubview:groups];

    for (NSView *group in groups.arrangedSubviews) {
        [group.widthAnchor constraintEqualToAnchor:groups.widthAnchor].active = YES;
    }
    NSButton *guide = [NSButton buttonWithTitle:DBUIString(@"menu.guide")
                                         target:self
                                         action:@selector(openInstallationGuide:)];
    guide.bezelStyle = NSBezelStyleRounded;
    NSButton *done = [NSButton buttonWithTitle:DBUIString(@"settings.apply")
                                        target:target
                                        action:action];
    done.bezelStyle = NSBezelStyleRounded;
    done.keyEquivalent = @"\r";
    done.tag = 205;
    guide.translatesAutoresizingMaskIntoConstraints = NO;
    done.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:guide];
    [root addSubview:done];
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:root.topAnchor constant:24],
        [header.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:28],
        [scroll.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:22],
        [scroll.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:done.topAnchor constant:-20],
        [document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],
        [groups.topAnchor constraintEqualToAnchor:document.topAnchor constant:2],
        [groups.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:24],
        [groups.trailingAnchor constraintEqualToAnchor:document.trailingAnchor constant:-24],
        [groups.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-20],
        [done.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],
        [done.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-20],
        [guide.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [guide.centerYAnchor constraintEqualToAnchor:done.centerYAnchor]
    ]];
    self.optionsWindow = window;
    return window;
}

- (void)openInstallationGuide:(id)sender {

    DBOpenInstallationGuide([NSBundle bundleForClass:self.class]);
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
    saved[@"refreshInterval"] =
        [(NSPopUpButton *)[v viewWithTag:206] selectedItem].representedObject;
    saved[@"launchAtLogin"] = @([(NSButton *)[v viewWithTag:208] state] == NSControlStateValueOn);
    saved[@"showAllSpaces"] = @([(NSButton *)[v viewWithTag:209] state] == NSControlStateValueOn);
    saved[@"boardScale"] = [(NSPopUpButton *)[v viewWithTag:210] selectedItem].representedObject;
    NSButton *button = (NSButton *)[v viewWithTag:205];
    button.enabled = NO;
    button.title = DBUIString(@"settings.saving");
    [DBSettingsStore submitSettings:saved
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

                             if ([NSBundle.mainBundle.bundleIdentifier
                                     isEqual:@"com.skyline23.departureboard"]) {
                                 [DBBackgroundAgent configure];

                                 if ([DBSettingsStore.settings[@"hasAPIKey"] boolValue] &&
                                     !self.useSampleData) {
                                     [LiveFlightStore refreshInBackground];
                                 }
                             }
                             completion(YES);
                         }];
}

@end
