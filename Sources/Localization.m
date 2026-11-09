#import "DepartureBoardView.h"

// The settings UI stays in English. The board independently cycles through
// English and the language used at its selected airport or railway station.
NSString *DBBoardString(NSString *key, NSString *language) {

    static NSMutableDictionary<NSString *, NSDictionary *> *tables;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        tables = NSMutableDictionary.new;
    });

    NSString *locale = language ?: @"en";
    NSDictionary *strings = tables[locale];
    if (!strings) {

        NSBundle *bundle = [NSBundle bundleForClass:DBBoardView.class];
        NSURL *url = [bundle URLForResource:@"Localizable"
                              withExtension:@"strings"
                               subdirectory:nil
                               localization:locale];
        strings = url ? [NSDictionary dictionaryWithContentsOfURL:url] : @{};
        tables[locale] = strings ?: @{};
    }
    NSString *value = strings[key];
    if (value) {

        return value;
    }
    return [locale isEqual:@"en"] ? key : DBBoardString(key, @"en");
}

NSString *DBUIString(NSString *key) {

    return DBBoardString(key, @"en");
}
