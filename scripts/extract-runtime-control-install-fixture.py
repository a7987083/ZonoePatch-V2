"""Exact installers with Method facades; does not simulate UIKit interaction."""
from pathlib import Path
import sys,json,hashlib
root=Path(__file__).resolve().parents[1];out=Path(sys.argv[1]);spans=[];code=[]
for file,start in [('ui/finder/ZNRuntimeMethodCallFinderUI.mm','extern "C" void ZNInstallRuntimeMethodCallFinderUI'),('ui/features/ZNRuntimeMethodCallFeatureUI.mm','extern "C" void ZNInstallRuntimeMethodCallFeatureUI'),('ui/features/ZNM551RuntimeSliderStability.mm','extern "C" void ZNInstallM551'),('ui/features/ZNM57UnifiedRuntimeControls.mm','static void ZNM57Replace'),('ui/finder/ZNMethodFinderM43Polish.mm','static void ZNM43PolishSwap')]:
 s=(root/'iosruntimepatchmenu/src'/file).read_text();body=s[s.index(start):s.index('#pragma mark - END')];code.append(body);spans.append(dict(source=file,sha256=hashlib.sha256(body.encode()).hexdigest()))
headers='''#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "ZNUIInstallationTrace.h"
#import "ZNPatchCore.h"
#include <cassert>
#ifndef TEST_NO_CLASS
@interface ZNRuntimeMenuControllerV040:NSObject
@end
@implementation ZNRuntimeMenuControllerV040
- (void)zn60v3_renderDetailAtWidth:(double)w{(void)w;}
- (void)znrmc_renderDetailAtWidth:(double)w{(void)w;}
- (void)zn50_renderFeatureGroupsFull{}
- (void)znrmc_renderFeatureGroupsFull{}
- (void)zn50_renderFeatureGroupsCompact{}
- (void)znrmc_renderFeatureGroupsCompact{}
- (void)zn51_runtimeSliderChanged:(id)c{(void)c;}
- (void)znm551_runtimeSliderChanged:(id)c{(void)c;}
- (void)znm57_runtimeSliderChanged:(id)c{(void)c;}
- (void)zn51_runtimeNumberChanged:(id)c{(void)c;}
- (void)znm57_runtimeNumberChanged:(id)c{(void)c;}
- (void)zn51_runtimeSwitchChanged:(id)c{(void)c;}
- (void)znm57_runtimeSwitchChanged:(id)c{(void)c;}
- (void)zn60v3_renderSearchAtWidth:(double)w{(void)w;}
- (void)znm43p_renderSearchAtWidth:(double)w{(void)w;}
#ifndef TEST_MISSING_METHOD
- (void)zn60v3_renderResultsAtWidth:(double)w{(void)w;}
#endif
- (void)znm43p_renderResultsAtWidth:(double)w{(void)w;}
@end
#endif
'''
main='''
int main(){@autoreleasepool{
 ZNUITraceReset();ZNUITraceEnable(YES);
 Class cls=NSClassFromString(@"ZNRuntimeMenuControllerV040");
#ifndef TEST_NO_CLASS
 Method current=class_getInstanceMethod(cls,NSSelectorFromString(@"zn51_runtimeSliderChanged:"));
 Method stable=class_getInstanceMethod(cls,NSSelectorFromString(@"znm551_runtimeSliderChanged:"));
 Method unified=class_getInstanceMethod(cls,NSSelectorFromString(@"znm57_runtimeSliderChanged:"));
 IMP predecessor=method_getImplementation(current),wrapper=method_getImplementation(stable),owner=method_getImplementation(unified);
 assert(predecessor!=wrapper&&owner!=wrapper);
 ZNInstallM551RuntimeSliderStabilityDeferred();
 assert(method_getImplementation(current)==wrapper&&method_getImplementation(stable)==predecessor);
 ZNInstallM57UnifiedRuntimeControlsDeferred();
 assert(method_getImplementation(current)==owner&&method_getImplementation(stable)==predecessor);
 Method search=class_getInstanceMethod(cls,NSSelectorFromString(@"zn60v3_renderSearchAtWidth:")),alias=class_getInstanceMethod(cls,NSSelectorFromString(@"znm43p_renderSearchAtWidth:"));
 IMP base=method_getImplementation(search),polish=method_getImplementation(alias);
 ZNInstallMethodFinderM43PolishDeferred();
 assert(method_getImplementation(search)==polish&&method_getImplementation(alias)==base);
#else
 assert(cls==Nil);ZNInstallM551RuntimeSliderStabilityDeferred();ZNInstallM57UnifiedRuntimeControlsDeferred();ZNInstallMethodFinderM43PolishDeferred();
#endif

#ifndef TEST_NO_CLASS
 const char *selectors[]={"zn60v3_renderDetailAtWidth:","zn50_renderFeatureGroupsFull","zn50_renderFeatureGroupsCompact"};
 const char *aliases[]={"znrmc_renderDetailAtWidth:","znrmc_renderFeatureGroupsFull","znrmc_renderFeatureGroupsCompact"};
 IMP bases[3],wrappers[3];for(int i=0;i<3;i++){bases[i]=method_getImplementation(class_getInstanceMethod(cls,sel_registerName(selectors[i])));wrappers[i]=method_getImplementation(class_getInstanceMethod(cls,sel_registerName(aliases[i])));}
#endif
 ZNInstallRuntimeMethodCallFinderUIDeferred();ZNInstallRuntimeMethodCallFeatureUIDeferred();
#ifndef TEST_NO_CLASS
 for(int i=0;i<3;i++){assert(method_getImplementation(class_getInstanceMethod(cls,sel_registerName(selectors[i])))==wrappers[i]);assert(method_getImplementation(class_getInstanceMethod(cls,sel_registerName(aliases[i])))==bases[i]);}
#endif
 NSUInteger total=[ZNUITraceSnapshot()[@"total"] unsignedIntegerValue];
 for(int i=0;i<100;i++){ZNInstallRuntimeMethodCallFinderUIDeferred();ZNInstallRuntimeMethodCallFeatureUIDeferred();ZNInstallM551RuntimeSliderStabilityDeferred();ZNInstallM57UnifiedRuntimeControlsDeferred();ZNInstallMethodFinderM43PolishDeferred();}
 assert([ZNUITraceSnapshot()[@"total"] unsignedIntegerValue]==total);
#ifdef TEST_NO_CLASS
 assert(total==0);
#elif defined(TEST_MISSING_METHOD)
 assert(total==8);
#else
 assert(total==9);
#endif
 puts("exact RuntimeControls/Polish installers: predecessor, replacement, repeated install and missing class/method PASS; UIKit handlers DEVICE PENDING");
}}
'''
out.write_text(headers+''.join(code)+main);out.with_suffix('.json').write_text(json.dumps(dict(spans=spans,scope='Exact installers; Foundation Method facades only, no UIKit handler or external-consumer proof'),indent=2)+'\n')
