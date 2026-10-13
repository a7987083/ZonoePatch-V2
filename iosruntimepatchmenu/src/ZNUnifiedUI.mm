// ZNUnifiedUI.mm
// Single UI owner for Runtime Patch Menu.
// Consolidated from baseline b72c2a271c703e494397f680c327a26a6cf275f5 without intentional behavior changes.
// UI drawing, layout and UIKit interaction handlers live in this translation unit.


// UI_INCLUDE_DIAGNOSTICS_BEGIN
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability-completeness"
#include "ZNPerformance.h"
#import "ZNAsyncPerformance.h" // UI_MODULE_IMPORT
#include "ZNLoadedImageApple.h" // UI_MODULE_IMPORT
extern "C" void ZNObserveFirstDisplayTick(void); // UI_MODULE_IMPORT
#import "ZNUIInstallationTrace.h" // UI_MODULE_IMPORT
#import "ZNMenuControllerInternal.h" // UI_MODULE_IMPORT
#import "ZNMenuUIKeys.h" // UI_MODULE_IMPORT
#import "ZNMenuUIHelpers.h" // UI_MODULE_IMPORT
#import "ZNMenuSearchPolicy.h" // UI_MODULE_IMPORT
#include "ui/core/ZonoeRuntimeMenu.inc"

@interface ZNRuntimeMenuControllerV040 (ZNUnifiedUICrossSectionDecls)
- (void)zn61v3_createPatch:(UIButton *)sender;
- (void)zn52_chainTapped:(UIButton *)sender;
- (void)znm55_runtimeSliderChanged:(UISlider *)control;
@end



#include "ui/shell/ZNDeferredBootstrap.inc"


// UI_COMPILED_MODULE: ui/shell/ZNRuntimeMenuModalShell.mm


// UI_COMPILED_MODULE: ui/features/ZNFeatureGroupUI.mm


// UI_COMPILED_MODULE: ui/features/ZNFeatureRuntimeControlsV2.mm


// UI_COMPILED_MODULE: ui/shell/ZNPublicCompactUI.mm


#include "ui/features/ZNFeatureBuilderUI.inc"


// UI_COMPILED_MODULE: ui/features/ZNFeatureBuilderControlsV2.mm


#include "ui/finder/ZNIL2CPPMethodFinderUI.inc"


#include "ui/finder/ZNIL2CPPMethodFinderMenuBinding.inc"


#include "ui/finder/ZNIL2CPPMethodFinderUXV2.inc"


#include "ui/finder/ZNIL2CPPMethodFinderUIV3.inc"


// UI_COMPILED_MODULE: ui/finder/ZNIL2CPPMethodFinderM2.mm


#include "ui/finder/ZNIL2CPPMethodFinderM21CancelUX.inc"


#include "ui/finder/ZNIL2CPPMethodFinderM22StableCancelUX.inc"


#include "ui/compat/ZNIL2CPPABIDetailUI.inc"


#include "ui/finder/ZNRuntimeMethodCallFinderUI.inc"


#include "ui/compat/ZNRuntimeMethodCallBuilderUI.inc"


#include "ui/features/ZNRuntimeMethodCallFeatureUI.inc"


#include "ui/compat/ZNUXFixesV2.inc"


#include "ui/finder/ZNMethodFinderM42UI.inc"


#include "ui/finder/ZNMethodFinderM43UI.inc"


#include "ui/finder/ZNMethodFinderM43Polish.inc"


#include "ui/execution/ZNInstanceSelectionV2UI.inc"


#include "ui/compat/ZNM441Hotfix.inc"


#include "ui/finder/ZNM442SearchRestore.inc"


#include "ui/finder/ZNM45AddressOwningMethodUI.inc"


#include "ui/execution/ZNM46FullSignatureUI.inc"


#include "ui/compat/ZNM461Polish.inc"


#include "ui/features/ZNM462CandidateBindingUI.inc"


#include "ui/execution/ZNM47ReceiverCaptureUI.inc"


#include "ui/execution/ZNM47MultiArgUI.inc"


#include "ui/compat/ZNM47BuilderArgsUI.inc"


// UI_COMPILED_MODULE: ui/compat/ZNM47VersionUI.mm


#include "ui/execution/ZNM49GenericInvokeEditableArgs.inc"


#include "ui/finder/ZNMethodFinderUnifiedUI.inc"


#include "ui/execution/ZNM51RuntimeArgControlsImmediateChain.inc"


#include "ui/compat/ZNM51SilentCustomerExecution.inc"


#include "ui/execution/ZNM52ChainExecuteButton.inc"


#include "ui/finder/ZNM52MethodSearchHistory.inc"


#include "ui/features/ZNM53ControlBinding.inc"


#include "ui/features/ZNM55TypedControlBinding.inc"


#include "ui/features/ZNM551RuntimeSliderStability.inc"


// UI_COMPILED_MODULE: ui/features/ZNM562SliderIsolation.mm


#include "ui/compat/ZNM57RuntimeOnlyBuilderGate.inc"


#include "ui/features/ZNM57UnifiedRuntimeControls.inc"


#include "ui/features/ZNM584SchemeALayout.inc"


#include "ui/features/ZNM585UnifiedControlSemantics.inc"


#include "ui/compat/ZNM585StaticRuntimeRange.inc"


#include "ui/features/ZNM58UnifiedControlRuntime.inc"


#include "ui/features/ZNM590UnifiedActionModel.inc"


#include "ui/features/ZNM591OffsetHookControls.inc"


#include "ui/features/ZNM600UnifiedFeatureSurface.inc"


#include "ui/features/ZNM630HardCutUI.inc"
// UI_INCLUDE_DIAGNOSTICS_END
#pragma clang diagnostic pop






