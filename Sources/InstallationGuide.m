#import "InstallationGuide.h"

NSURL *DBInstallationGuideURL(NSBundle *bundle) {

    NSString *language = NSLocale.preferredLanguages.firstObject ?: @"en";
    NSString *name = [language hasPrefix:@"ko"] ? @"ko" : @"index";
    return [bundle URLForResource:name withExtension:@"html" subdirectory:@"Guide"];
}

BOOL DBOpenInstallationGuide(NSBundle *bundle) {

    NSURL *url = DBInstallationGuideURL(bundle);

    if (url && [NSWorkspace.sharedWorkspace openURL:url]) {
        return YES;
    }
    NSAlert *alert = NSAlert.new;
    alert.messageText = @"Installation guide could not be opened";
    alert.informativeText =
        @"Reinstall the complete Departure Board package, including its Guide folder.";
    [alert runModal];
    return NO;
}
