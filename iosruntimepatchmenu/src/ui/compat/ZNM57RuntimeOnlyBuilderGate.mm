#import "ZNUIInstallationTrace.h" // UI_MODULE_IMPORT
#import "ZNMethodFinderUIInternal.h" // UI_MODULE_IMPORT
#import "ZNBuildCapabilityRegistry.h" // UI_MODULE_IMPORT
#pragma mark - BEGIN ZNM57RuntimeOnlyBuilderGate.mm
#line 1 "ZNM57RuntimeOnlyBuilderGate.mm"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "ZNBinaryPatchWorkspace.h"
#import "ZNRuntimeActionModel.h"
#import "ZNNativeHookAction.h"
#import "ZNPatchCore.h"

// M5.7 Builder gate: Runtime-only is a first-class build mode. The historical
// Feature Builder enabled the build button only when workspace.filledCount > 0,
// which forced Runtime Method authoring to depend on a Static Offset row.
//
// This post-render gate does not change the Builder pipeline itself. It only
// reflects the same mode rule used by ZNStaticBinaryPipeline:
//   Runtime Actions > 0 && complete Static rows == 0 -> Runtime-only.
// A complete Static row requires both Offset and Enabled.

static NSUInteger ZNM57CompleteStaticRows(ZNBinaryPatchWorkspace *workspace) {
    NSUInteger count = 0;
    for (ZNBinaryPatchRow *row in workspace.rows ?: @[]) {
        if (row.offsetText.length > 0 && row.enabledText.length > 0) count++;
    }
    return count;
}

static UIButton *ZNM57FindBuildButton(UIView *root) {
    for (UIView *view in root.subviews ?: @[]) {
        if ([view isKindOfClass:UIButton.class]) {
            NSString *title = [(UIButton *)view titleForState:UIControlStateNormal] ?: @"";
            if ([title isEqualToString:@"生成新二进制"] || [title isEqualToString:@"正在生成…"]) return (UIButton *)view;
        }
        UIButton *nested = ZNM57FindBuildButton(view);
        if (nested) return nested;
    }
    return nil;
}

@interface ZNRuntimeMenuControllerV040 (ZNM57RuntimeOnlyBuilderGate)
- (void)znm57_renderOtherWithRuntimeOnlyGate;
@end

@implementation ZNRuntimeMenuControllerV040 (ZNM57RuntimeOnlyBuilderGate)
- (void)znm57_renderOtherWithRuntimeOnlyGate {
    [self znm57_renderOtherWithRuntimeOnlyGate];

    UIButton *build = ZNM57FindBuildButton(self.contentView);
    if (!build) return;

    ZNBinaryPatchWorkspace *workspace = [ZNBinaryPatchWorkspace sharedWorkspace];
    NSUInteger completeStatic = ZNM57CompleteStaticRows(workspace);
    NSUInteger runtimeActions = [[ZNRuntimeActionStore sharedStore] actionsSnapshot].count;
    NSUInteger nativeHooks = [[ZNNativeHookStore sharedStore] actionsSnapshot].count;
    (void)runtimeActions;
    (void)nativeHooks;
    (void)completeStatic;
    ZNBinaryBuildCoordinator *coordinator=[ZNBinaryBuildCoordinator sharedCoordinator];
    build.enabled = coordinator.canBuild;
    build.alpha = build.enabled ? 1.0 : 0.5;
    build.accessibilityHint = build.enabled
        ? [NSString stringWithFormat:@"可生成：%@", [coordinator.activeProviderIdentifiers componentsJoinedByString:@", "]]
        : coordinator.blockedReason;
}
@end

extern "C" void ZNInstallM57RuntimeOnlyBuilderGateDeferred(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"ZNRuntimeMenuControllerV040");
        if (!cls) return;
        Method current = class_getInstanceMethod(cls, @selector(zn50b_renderOther));
        Method gate = class_getInstanceMethod(cls, @selector(znm57_renderOtherWithRuntimeOnlyGate));
        if (current && gate) method_exchangeImplementations(current, gate);
        [[ZNRuntimeLogger sharedLogger] log:@"[m6.8-builder-gate] Runtime/Native-Hook-only build enabled with zero complete Static rows; partial drafts ignored"];
    });
}

#pragma mark - END ZNM57RuntimeOnlyBuilderGate.mm
