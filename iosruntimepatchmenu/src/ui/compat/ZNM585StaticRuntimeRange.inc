#pragma mark - BEGIN ZNM585StaticRuntimeRange.mm
#line 1 "ZNM585StaticRuntimeRange.mm"
#import <Foundation/Foundation.h>
#import "ZNPatchCore.h"

// M6.3 owns Slider runtime semantics in ZNFeatureRuntimeControlsV2.
// Keep only the historical installer symbol because the activation chain still
// calls it; the old decorator category is intentionally retired.
extern "C" void ZNInstallM585StaticRuntimeRangeDeferred(void){
    static dispatch_once_t once;dispatch_once(&once,^{
        [[ZNRuntimeLogger sharedLogger]log:@"[m6.3-ui] M5.8.5 Slider runtime semantics consolidated into FeatureRuntimeControlsV2"];
    });
}

#pragma mark - END ZNM585StaticRuntimeRange.mm
