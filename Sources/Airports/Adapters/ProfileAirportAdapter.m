#import "Airports/AirportAdapters.h"
#import "Airports/AirportComponents.h"
#import "DepartureBoardView.h"
#import "DrawingSupport.h"

@implementation DBProfileAirportAdapter {
    NSDictionary *_location;
}

- (instancetype)initWithLocation:(NSDictionary *)location {

    if ((self = [super init])) {
        _location = [location copy];
    }

    return self;
}

- (NSDictionary *)location {

    return _location;
}

- (NSDictionary *)display {

    return self.location[@"display"];
}

- (NSString *)compactTitleLanguage {

    return self.display[@"compactHeader"][@"titleLanguage"];
}

- (void)drawCompactHeaderDecorationInRect:(NSRect)rect {

    NSDictionary *style = self.display[@"compactHeader"];

    if (style[@"bottomRuleColor"]) {
        DBFillRect(NSMakeRect(0, NSMaxY(rect) - [style[@"bottomRuleHeight"] doubleValue],
                              rect.size.width, [style[@"bottomRuleHeight"] doubleValue]),
                   DBColor(style[@"bottomRuleColor"]));
    }

    if (style[@"leftRuleColor"]) {
        DBFillRect(NSMakeRect(0, 0, [style[@"leftRuleWidth"] doubleValue], rect.size.height),
                   DBColor(style[@"leftRuleColor"]));
    }
}

- (NSArray *)columns {

    return self.location[@"columns"] ?: @[ @"time", @"flight", @"destination", @"gate", @"state" ];
}

- (CGFloat)weightForColumn:(NSString *)column {

    NSDictionary *weights = self.location[@"display"][@"columnWeights"];

    if (weights[column]) {
        return [weights[column] doubleValue];
    }

    NSDictionary *defaults = @{
        @"time" : @.13,
        @"flight" : @.21,
        @"destination" : @.30,
        @"expected" : @.12,
        @"airline" : @.14,
        @"terminal" : @.07,
        @"counter" : @.10,
        @"gate" : @.08,
        @"state" : @.22
    };
    return [defaults[column] doubleValue];
}

- (CGFloat)headerHeightForBounds:(NSRect)area scale:(CGFloat)scale {

    CGFloat fraction = [self.location[@"display"][@"headerFraction"] doubleValue];
    CGFloat height = fraction > 0 ? area.size.height * fraction * scale
                                  : [self.location[@"display"][@"headerHeight"] doubleValue];
    return MAX(height, [self.location[@"display"][@"minimumHeaderHeight"] doubleValue]);
}

- (CGFloat)columnHeaderHeight {

    return [self.location[@"display"][@"columnHeaderLanguages"] count] > 1 ? 46 : 30;
}

- (NSInteger)rowCountForBounds:(NSRect)area scale:(CGFloat)scale density:(NSInteger)density {

    if (density > 0) {
        return MAX(8, MIN(64, density));
    }

    NSDictionary *profile = self.location[@"display"];
    CGFloat tableTop =
        [self headerHeightForBounds:area scale:scale] + [self columnHeaderHeight] + 4;
    CGFloat tableBottom = area.size.height - MAX(29, [profile[@"footerHeight"] doubleValue] + 3);
    CGFloat minimum = [profile[@"stackedDestination"] boolValue] ? 49 : 34;
    NSInteger readableRows = (NSInteger)floor(MAX(0, tableBottom - tableTop) / minimum);
    NSInteger preferredRows = (NSInteger)ceil([profile[@"rowCount"] doubleValue] / scale);
    // Preserve each airport's density without enlarging a tall reference panel
    // to the full width of a landscape desktop.
    return MAX(8, MIN(64, MIN(preferredRows, readableRows)));
}

- (void)drawHeaderInBounds:(NSRect)bounds context:(DBAirportRenderContext *)context {

    DBDrawProfileAirportHeader(bounds, self, context);
}

- (void)drawFooterInBounds:(NSRect)bounds context:(DBAirportRenderContext *)context {

    DBDrawProfileAirportFooter(bounds, self, context);
}

@end
