from pathlib import Path
import sys,hashlib,json
root=Path(__file__).resolve().parents[1];source=root/'iosruntimepatchmenu/src/ui/finder/ZNM52MethodSearchHistory.mm';s=source.read_text();out=Path(sys.argv[1]);spans=[]
def span(start,end):
 a=s.index(start);b=s.index(end,a);code=s[a:b];spans.append(dict(start=start,end=end,sha256=hashlib.sha256(code.encode()).hexdigest()));return code
constants=span('static NSString * const kZNM52SearchHistoryDefaultsKey','static const NSInteger kZNM52SearchHistoryButtonTagBase')
helpers=span('static NSString *ZNM52HTrim','static CGFloat ZNM52HMaxY')
forward=span('- (void)znm52h_startM43Search:(id)sender {','- (void)znm52h_renderM43SearchAtWidth:(CGFloat)width {')
install=span('static void ZNM52HSwap','#pragma mark - END')
headers='''#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "ZNUIInstallationTrace.h"
#import "ZNPatchCore.h"
#include <cassert>
@interface ZNRuntimeMenuControllerV040:NSObject
@property(nonatomic,copy) NSString *query;
@property(nonatomic,assign) unsigned calls;
- (NSString *)zn57mf_query;
- (void)znm43_startSearch:(id)sender;
- (void)znm43_renderSearchAtWidth:(CGFloat)width;
@end
@implementation ZNRuntimeMenuControllerV040
- (NSString *)zn57mf_query{return self.query;}
- (void)znm43_startSearch:(id)sender{(void)sender;self.calls++;}
- (void)znm43_renderSearchAtWidth:(CGFloat)width{(void)width;}
@end
@interface ZNRuntimeMenuControllerV040 (HistoryFixture)
- (void)znm52h_startM43Search:(id)sender;
- (void)znm52h_renderM43SearchAtWidth:(CGFloat)width;
@end
'''
# Renderer facade supplies only the Method required by the real installer.
renderer='- (void)znm52h_renderM43SearchAtWidth:(CGFloat)width{(void)width;}\n'
test='''int main(){@autoreleasepool{
 NSUserDefaults *prefs=NSUserDefaults.standardUserDefaults;id old=[prefs objectForKey:kZNM52SearchHistoryDefaultsKey];[prefs removeObjectForKey:kZNM52SearchHistoryDefaultsKey];
 ZNRuntimeMenuControllerV040 *c=[ZNRuntimeMenuControllerV040 new];c.query=@" first ";Method method=class_getInstanceMethod(c.class,@selector(znm43_startSearch:)),alias=class_getInstanceMethod(c.class,@selector(znm52h_startM43Search:));IMP original=method_getImplementation(method),wrapper=method_getImplementation(alias);assert(original!=wrapper);[c znm43_startSearch:nil];assert(c.calls==1&&ZNM52HHistory().count==0);
 ZNUITraceReset();ZNUITraceEnable(YES);ZNInstallM52MethodSearchHistoryDeferred();assert(method_getImplementation(method)==wrapper&&method_getImplementation(alias)==original);[c znm43_startSearch:nil];assert(c.calls==2&&[ZNM52HHistory() isEqual:@[@"first"]]);c.query=@"external-alias";[c znm52h_startM43Search:nil];assert(c.calls==3&&[ZNM52HHistory() isEqual:@[@"first"]]);
 for(int i=0;i<100;i++)ZNInstallM52MethodSearchHistoryDeferred();assert([ZNUITraceSnapshot()[@"total"] unsignedIntegerValue]==2);assert(method_getImplementation(method)==wrapper&&method_getImplementation(alias)==original);
 for(unsigned i=0;i<55;i++){c.query=[NSString stringWithFormat:@"q%u",i];[c znm43_startSearch:nil];}assert(ZNM52HHistory().count==50);c.query=@" Q54 ";[c znm43_startSearch:nil];assert(ZNM52HHistory().count==50&&[ZNM52HHistory().firstObject isEqual:@"Q54"]);
 if(old)[prefs setObject:old forKey:kZNM52SearchHistoryDefaultsKey];else [prefs removeObjectForKey:kZNM52SearchHistoryDefaultsKey];
 puts("actual SearchHistory installer + start predecessor IMP/old alias/repeated installation/history cap and dedupe PASS; renderer is a facade, UIKit interaction NOT VERIFIED");
}}'''
out.write_text(headers+constants+helpers+'@implementation ZNRuntimeMenuControllerV040 (HistoryFixture)\n'+forward+renderer+'@end\n'+install+test);out.with_suffix('.json').write_text(json.dumps(dict(source=str(source.relative_to(root)),spans=spans,scope='Exact production installer/search forwarding/history storage with Foundation predecessor and renderer facades; no UIKit rendering claim'),indent=2)+'\n')
