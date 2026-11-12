#import <Cocoa/Cocoa.h>

@protocol DBUpdateSettingsProviding <NSObject>
- (NSArray<NSView *> *)updateSettingsControls;
@end
