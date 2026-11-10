#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSDictionary *DBDiagnosticFields(NSDictionary *fields);
FOUNDATION_EXPORT void DBDiagnosticEvent(NSString *category, NSString *event, NSDictionary *fields);
