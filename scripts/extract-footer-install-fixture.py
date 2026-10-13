from pathlib import Path
import sys,hashlib,json
root=Path(__file__).resolve().parents[1];source=root/'iosruntimepatchmenu/src/ui/compat/ZNM47VersionUI.mm';s=source.read_text();a=s.index('@implementation');body=s[a:s.index('#pragma mark - END',a)];out=Path(sys.argv[1]);headers='''#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "ZNUIInstallationTrace.h"
#import "ZNBuildVersion.h"
#import "ZNPatchCore.h"
#include <cassert>
@interface FixtureFooter:NSObject
@property(nonatomic,copy) NSString *text;
@end
@implementation FixtureFooter @end
@interface FixtureDevice:NSObject
+ (instancetype)currentDevice;
- (NSString *)systemVersion;
@end
@implementation FixtureDevice
+ (instancetype)currentDevice{return [self new];}
- (NSString *)systemVersion{return @"fixture-os";}
@end
#define UIDevice FixtureDevice
@interface ZNRuntimeMenuControllerV040:NSObject
@property(nonatomic,assign) BOOL uiReady;
@property(nonatomic,strong) FixtureFooter *footerLabel;
@property(nonatomic,assign) unsigned ticks;
- (void)tick:(NSTimer *)timer;
@end
@implementation ZNRuntimeMenuControllerV040
- (void)tick:(NSTimer *)timer{(void)timer;self.ticks++;}
@end
''';test='''int main(){@autoreleasepool{
 ZNRuntimeMenuControllerV040 *c=[ZNRuntimeMenuControllerV040 new];c.uiReady=YES;c.footerLabel=[FixtureFooter new];c.footerLabel.text=@"before";Method tick=class_getInstanceMethod(c.class,@selector(tick:)),alias=class_getInstanceMethod(c.class,@selector(znm47_tick:));IMP original=method_getImplementation(tick),wrapper=method_getImplementation(alias);assert(original!=wrapper);[c tick:nil];assert(c.ticks==1&&[c.footerLabel.text isEqual:@"before"]);
 ZNUITraceReset();ZNUITraceEnable(YES);ZNInstallM47VersionUIDeferred();assert(method_getImplementation(tick)==wrapper&&method_getImplementation(alias)==original);[c tick:nil];assert(c.ticks==2&&[c.footerLabel.text containsString:ZN_MENU_VERSION_DISPLAY]);c.footerLabel.text=@"alias";[c znm47_tick:nil];assert(c.ticks==3&&[c.footerLabel.text isEqual:@"alias"]);for(int i=0;i<100;i++)ZNInstallM47VersionUIDeferred();assert([ZNUITraceSnapshot()[@"total"] unsignedIntegerValue]==1);assert(method_getImplementation(tick)==wrapper);puts("actual M47 installer/predecessor IMP/compatibility alias/repeated initialization and footer assignment PASS (UIKit receiver/device facade)");
}}
''';out.write_text(headers+body+test);out.with_suffix('.json').write_text(json.dumps(dict(source=str(source.relative_to(root)),sha256=hashlib.sha256(body.encode()).hexdigest(),scope='Actual production category and installer, Foundation receiver/device facade; no UIKit behavior/device claim'),indent=2)+'\n')
