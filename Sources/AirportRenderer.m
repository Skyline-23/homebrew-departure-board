#import "Airports/AirportTableRenderer.h"
#import "BoardViewInternal.h"

@implementation DBBoardView (AirportRenderer)

- (DBAirportRenderContext *)airportRenderContext {

    return [[DBAirportRenderContext alloc] initWithDate:self.boardDate
                                               language:self.currentLanguage
                                                   rows:self.rows
                                                   page:self.currentPage
                                                  scale:self.boardScale
                                                density:self.density
                                        emptyMessageKey:self.emptyMessageKey];
}

- (CGFloat)airportHeaderHeight:(NSRect)area {

    return [self.airportAdapter headerHeightForBounds:area scale:self.boardScale];
}

- (NSInteger)airportRowCountForArea:(NSRect)area {

    return [self.airportAdapter rowCountForBounds:area scale:self.boardScale density:self.density];
}

- (void)drawAirport:(NSRect)area {

    NSInteger count = [self airportRowCountForArea:area];
    NSInteger pages = MAX(1, (self.rows.count + count - 1) / count);
    self.currentPage =
        (NSInteger)((NSProcessInfo.processInfo.systemUptime - self.startTime) / 15) % pages;
    DBDrawAirportTable(area, self.airportAdapter, [self airportRenderContext]);
}

@end
