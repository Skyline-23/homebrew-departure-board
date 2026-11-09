#import "BoardViewInternal.h"
#import "DrawingSupport.h"
#import "LiveFlightStore.h"
#import <CoreText/CoreText.h>

@implementation DBBoardView (SettingsController)

- (NSWindow *)settingsWindowWithTarget:(id)target action:(SEL)action {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 700, 622)
                                                   styleMask:NSWindowStyleMaskTitled
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = DBUIString(@"settings.title");
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
    NSTextField *note = [NSTextField wrappingLabelWithString:DBUIString(@"settings.note")];
    note.textColor = NSColor.secondaryLabelColor;
    note.font = DBFont(12, NO, NO);
    note.frame = NSMakeRect(29, 49, 425, 44);
    [v addSubview:note];
    for (NSView *view in v.subviews) {
        NSRect frame = view.frame;
        frame.origin.y += 180;
        view.frame = frame;
    }
    NSDictionary *saved = [NSUserDefaults.standardUserDefaults persistentDomainForName:DBDefaultsDomain];
    NSArray *extraLabels = @[ @"settings.data", @"settings.gateway", @"settings.token" ];
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
    NSTextField *gateway = [[NSTextField alloc] initWithFrame:NSMakeRect(161, 137, 497, 25)];
    gateway.tag = 201;
    gateway.stringValue = saved[@"gatewayURL"] ?: @"";
    gateway.placeholderString = @"https://departure-board-api.example.workers.dev";
    [v addSubview:gateway];
    NSSecureTextField *token = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(161, 93, 497, 25)];
    token.tag = 202;
    token.placeholderString = DBUIString(@"settings.tokenHint");
    [v addSubview:token];
    BOOL companion = [NSBundle.mainBundle.bundleIdentifier isEqual:@"io.skyline.departureboard.preview"];
    gateway.enabled = companion;
    token.enabled = companion;
    NSTextField *tokenNote = [NSTextField
        labelWithString:DBUIString(companion ? @"settings.keychain" : @"settings.openCompanion")];
    tokenNote.frame = NSMakeRect(161, 58, 497, 25);
    tokenNote.font = DBFont(11, NO, NO);
    tokenNote.textColor = NSColor.secondaryLabelColor;
    [v addSubview:tokenNote];
    NSButton *done = [NSButton buttonWithTitle:DBUIString(@"settings.apply") target:target action:action];
    done.bezelStyle = NSBezelStyleRounded;
    done.keyEquivalent = @"\r";
    done.frame = NSMakeRect(468, 24, 92, 32);
    [v addSubview:done];
    self.optionsWindow = window;
    return window;
}

- (void)applySettingsFromWindow:(NSWindow *)window {
    NSView *v = window.contentView;
    self.locationCode = [(NSPopUpButton *)[v viewWithTag:101] selectedItem].representedObject;
    self.displayStyle = [(NSPopUpButton *)[v viewWithTag:102] selectedItem].representedObject;
    self.languageMode = [(NSPopUpButton *)[v viewWithTag:103] selectedItem].representedObject;
    self.density = [[(NSPopUpButton *)[v viewWithTag:104] selectedItem].representedObject integerValue];
    self.brightness = [(NSSlider *)[v viewWithTag:105] doubleValue];
    self.reducedMotion = [(NSButton *)[v viewWithTag:106] state] == NSControlStateValueOn;
    self.useSampleData = [(NSPopUpButton *)[v viewWithTag:203] indexOfSelectedItem] == 1;
    if ([NSBundle.mainBundle.bundleIdentifier isEqual:@"io.skyline.departureboard.preview"]) {
        NSMutableDictionary *saved =
            [[NSUserDefaults.standardUserDefaults persistentDomainForName:DBDefaultsDomain] mutableCopy]
                ?: NSMutableDictionary.new;
        saved[@"gatewayURL"] = [(NSTextField *)[v viewWithTag:201] stringValue];
        [NSUserDefaults.standardUserDefaults setPersistentDomain:saved forName:DBDefaultsDomain];
        NSError *error = nil;
        if (![LiveFlightStore saveAccessToken:[(NSSecureTextField *)[v viewWithTag:202] stringValue]
                                        error:&error]) {
            NSAlert *alert = NSAlert.new;
            alert.messageText = DBUIString(@"settings.keychainFailed");
            [alert runModal];
        }
        if ([saved[@"gatewayURL"] length] && !self.useSampleData)
            [LiveFlightStore configureBackgroundRefresh];
    }
    [self saveSettings];
    [LiveFlightStore refreshInBackground];
    [self tick];
    self.needsDisplay = YES;
}

@end
