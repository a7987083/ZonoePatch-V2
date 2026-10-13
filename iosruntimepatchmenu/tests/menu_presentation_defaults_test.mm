#import <Foundation/Foundation.h>
#include <cassert>
extern "C" void ZNInstallPublicCompactDefaultsDeferred(void);
#ifndef TEST_NO_MENU_CLASS
static unsigned sharedCalls=0;
@interface ZNRuntimeMenuControllerV040 : NSObject
@property(nonatomic,assign) BOOL compactMode;
@property(nonatomic,assign) NSInteger selectedCategory;
+ (instancetype)shared;
@end
@implementation ZNRuntimeMenuControllerV040
+ (instancetype)shared {static ZNRuntimeMenuControllerV040 *s; if(!s)s=[self new];++sharedCalls;return s;}
@end
#endif
int main(){@autoreleasepool{
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
 NSArray *keys=@[@"zonoe.public-compact-ui.v1",@"ZonoePatch.CompactMode",@"ZonoePatch.SelectedCategory",@"zonoe.feature-name-registry.v1"];
 NSMutableDictionary *saved=[NSMutableDictionary dictionary];for(NSString *key in keys){id v=[d objectForKey:key];if(v)saved[key]=v;[d removeObjectForKey:key];}
 @try{
  [d setObject:@{@"old":@1} forKey:keys[3]];ZNInstallPublicCompactDefaultsDeferred();assert([d boolForKey:keys[0]]&&[d boolForKey:keys[1]]&&[d integerForKey:keys[2]]==0);assert(![d objectForKey:keys[3]]);
#ifndef TEST_NO_MENU_CLASS
  assert(sharedCalls==1);ZNRuntimeMenuControllerV040 *c=[ZNRuntimeMenuControllerV040 shared];assert(c.compactMode&&c.selectedCategory==0);unsigned before=sharedCalls;
#endif
  [d setBool:NO forKey:keys[1]];[d setInteger:7 forKey:keys[2]];[d setObject:@1 forKey:keys[3]];ZNInstallPublicCompactDefaultsDeferred();assert(![d boolForKey:keys[1]]&&[d integerForKey:keys[2]]==7);assert(![d objectForKey:keys[3]]);
#ifndef TEST_NO_MENU_CLASS
  assert(sharedCalls==before);
#endif
 }@finally{for(NSString *key in keys){[d removeObjectForKey:key];if(saved[key])[d setObject:saved[key] forKey:key];}}
 NSLog(@"production menu defaults first/repeated migration and class contract PASS");
}}
