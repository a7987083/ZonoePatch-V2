#import "ZNUIInstallationTrace.h" // UI_MODULE_IMPORT
#import "ZNMenuControllerInternal.h" // UI_MODULE_IMPORT
#pragma mark - BEGIN ZNM47VersionUI.mm
#line 1 "ZNM47VersionUI.mm"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "ZNBuildVersion.h"
#import "ZNPatchCore.h"

@implementation ZNRuntimeMenuControllerV040 (ZNM47VersionUI)

- (void)znm47_tick:(NSTimer *)timer {
    [self znm47_tick:timer];
    if (!self.uiReady || !self.footerLabel) return;
    self.footerLabel.text = [NSString stringWithFormat:@"PatchCore %@    %@    iOS %@",
                            ZN_MENU_VERSION_DISPLAY,
                            ZN_MENU_VERSION_FEATURE,
                            UIDevice.currentDevice.systemVersion];
}

@end

static void ZNM47VersionSwap(Class cls, SEL original, SEL replacement) {
    Method a = class_getInstanceMethod(cls, original);
    Method b = class_getInstanceMethod(cls, replacement);
    if (a && b) method_exchangeImplementations(a, b);
}

extern "C" void ZNInstallM47VersionUIDeferred(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"ZNRuntimeMenuControllerV040");
        if (!cls) return;
        ZNM47VersionSwap(cls, @selector(tick:), @selector(znm47_tick:));
        [[ZNRuntimeLogger sharedLogger] log:[NSString stringWithFormat:@"[m4.7-version] footer version source installed %@", ZN_MENU_VERSION_DISPLAY]];
    });
}

#pragma mark - END ZNM47VersionUI.mm
