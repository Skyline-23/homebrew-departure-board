#import "AirportTableRenderer.h"
#import "DepartureBoardView.h"
#import "DrawingSupport.h"

void DBDrawAirportTable(NSRect area, id<DBAirportAdapter> adapter,
                        DBAirportRenderContext *context) {

    NSDictionary *profile = adapter.display;
    [adapter drawHeaderInBounds:area context:context];
    // A physical display gets one panel. Long reference walls are cropped to
    // that panel instead of being shrunk or repeated across the desktop.
    NSInteger rowCount = [adapter rowCountForBounds:area
                                              scale:context.scale
                                            density:context.density];
    CGFloat margin = 20;
    CGFloat panelWidth = area.size.width - 2 * margin;
    CGFloat headingY = [adapter headerHeightForBounds:area scale:context.scale] + 4;
    CGFloat headingHeight = [adapter columnHeaderHeight];
    CGFloat tableY = headingY + headingHeight;
    CGFloat tableBottom = area.size.height - MAX(29, [profile[@"footerHeight"] doubleValue] + 3);
    CGFloat rowHeight = (tableBottom - tableY) / rowCount;
    CGFloat fontSize = MIN(36, MIN(rowHeight * .78, panelWidth / 34));
    if (profile[@"rowFontScale"]) {

        fontSize *= [profile[@"rowFontScale"] doubleValue];
    }
    NSArray *columns = adapter.columns;
    CGFloat totalWeight = 0;
    for (NSString *column in columns) {

        totalWeight += [adapter weightForColumn:column];
    }

    CGFloat left = margin;
    DBFillRect(NSMakeRect(left, headingY, panelWidth, headingHeight - 2),
               DBColor(profile[@"columnBand"]));
    CGFloat columnX = left;
    for (NSString *column in columns) {

        CGFloat width = panelWidth * [adapter weightForColumn:column] / totalWeight;
        NSArray *languages = profile[@"columnHeaderLanguages"];
        NSUInteger lines = MAX(1, languages.count);
        NSString *key =
            profile[@"columnLabels"][column] ?: [@"column." stringByAppendingString:column];
        for (NSUInteger line = 0; line < lines; line++) {

            NSString *label = languages.count ? DBBoardString(key, languages[line])
                                              : DBBoardString(key, context.language);
            DBDrawTextWithFont(
                label,
                NSMakeRect(columnX + 5, headingY + line * headingHeight / lines, width - 8,
                           headingHeight / lines - 2),
                DBNamedFont(profile[@"bodyFont"], lines > 1 ? 18 : MIN(24, panelWidth / 37)),
                DBColor(line ? profile[@"headerSecondaryInk"] ?: profile[@"columnInk"]
                             : profile[@"columnInk"]),
                NSTextAlignmentLeft);
        }
        columnX += width;
    }
    for (NSInteger index = 0; index < rowCount; index++) {

        NSUInteger rowIndex = (NSUInteger)(context.page * rowCount + index);
        if (rowIndex >= context.rows.count) {

            break;
        }
        NSDictionary *row = context.rows[rowIndex];
        CGFloat top = tableY + index * rowHeight;
        NSArray *rowColors = profile[@"rowColors"];
        DBFillRect(NSMakeRect(left, top, panelWidth, rowHeight - 1), DBColor(rowColors[index % 2]));
        columnX = left;
        for (NSString *column in columns) {

            CGFloat width = panelWidth * [adapter weightForColumn:column] / totalWeight;
            NSRect cell = NSMakeRect(columnX + 5, top + 1, width - 9, rowHeight - 3);
            NSString *columnFill = profile[@"columnFills"][column];
            if (columnFill) {

                DBFillRect(NSMakeRect(columnX, top, width - 1, rowHeight - 1), DBColor(columnFill));
            }
            if (profile[@"verticalRules"]) {

                DBFillRect(NSMakeRect(columnX + width - 1, top, 1, rowHeight),
                           DBColor(profile[@"verticalRules"]));
            }
            DBDrawAirportCell(row, column, cell, fontSize, index, adapter, context);
            columnX += width;
        }
    }
    if (!context.rows.count) {

        DBDrawText(DBBoardString(context.emptyMessageKey ?: @"data.loading", context.language),
                   NSMakeRect(100, tableY + 70, area.size.width - 200, 80), 26, DBColor(@"b9c9d4"),
                   NO, NSTextAlignmentCenter, NO);
    }
    [adapter drawFooterInBounds:area context:context];
}
