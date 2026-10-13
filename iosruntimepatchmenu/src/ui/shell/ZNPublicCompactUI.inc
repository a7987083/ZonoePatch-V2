#pragma mark - BEGIN ZNPublicCompactUI.mm
#line 1 "ZNPublicCompactUI.mm"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Public menu presentation policy for v0.5.6 Full Deferred Bootstrap.
// Keep the existing compact layout implementation and make it the default
// presentation after this migration. Users can still expand through the
// existing mode button; this only changes the post-upgrade default.

// UI_RELOCATED: ZNMenuPresentationDefaults.mm:constants
@implementation ZNRuntimeMenuControllerV040 (ZNPublicCompactUI)

- (void)znpublic_layoutPanel {
    [self znpublic_layoutPanel];
    if (self.compactMode) {
        self.subtitleLabel.text = @"0.5.6";
        self.subtitleLabel.alpha = 0.72;
    }
}

+ (void)znpublic_installLayoutDeferred {
    Method original = class_getInstanceMethod(self, @selector(layoutPanel));
    Method replacement = class_getInstanceMethod(self, @selector(znpublic_layoutPanel));
    if (original && replacement) method_exchangeImplementations(original, replacement);
}


@end

extern "C" void ZNInstallPublicCompactLayoutDeferred(void) {
    [ZNRuntimeMenuControllerV040 znpublic_installLayoutDeferred];
}

// UI_RELOCATED: ZNMenuPresentationDefaults.mm:policy
#pragma mark - END ZNPublicCompactUI.mm
