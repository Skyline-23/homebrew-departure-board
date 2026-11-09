#import "AirportAdapter.h"
FOUNDATION_EXPORT void DBDrawAirportTable(NSRect area, id<DBAirportAdapter> adapter,
                                          DBAirportRenderContext *context);
FOUNDATION_EXPORT void DBDrawAirportCell(NSDictionary *row, NSString *column, NSRect cell,
                                         CGFloat size, NSInteger rowIndex,
                                         id<DBAirportAdapter> adapter,
                                         DBAirportRenderContext *context);
