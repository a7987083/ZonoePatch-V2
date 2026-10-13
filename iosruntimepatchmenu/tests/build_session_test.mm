#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "ZNBuildSession.h"
#import "ZNBinaryPatchWorkspace.h"
#import "ZNFeatureControlModel.h"
#import "ZNRuntimeActionModel.h"
#import "ZNNativeHookAction.h"
#import "ZNIL2CPPResolver.h"
#import "ZNPatchCore.h"
#include <cassert>
#pragma clang diagnostic ignored "-Wincomplete-implementation"
// Only host UI/workspace shell and absent IL2CPP backend are stubbed; snapshots,
// rows, Store copies/persistence and session routing are production code.
@interface ZNBinaryPatchWorkspace ()
@property(nonatomic,strong,readwrite) NSMutableArray<ZNBinaryPatchRow *> *rows;
@end
@implementation ZNBinaryPatchWorkspace
- (instancetype)init {self=[super init];if(self)_rows=[NSMutableArray array];return self;}
@end
@implementation ZNIL2CPPResolver
+ (instancetype)sharedResolver{return nil;}
- (void)refresh{}
@end
@implementation ZNRuntimeLogger
+ (instancetype)sharedLogger{return nil;}
- (void)log:(NSString *)s{(void)s;}
@end
static const void *controlKey=&controlKey,*valueKey=&valueKey;
@implementation ZNBinaryPatchRow (TestAssociatedControls)
- (ZNFeatureControlType)featureControlType{return (ZNFeatureControlType)[objc_getAssociatedObject(self,controlKey) integerValue];}
- (void)setFeatureControlType:(ZNFeatureControlType)t{objc_setAssociatedObject(self,controlKey,@(t),OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
- (ZNValueType)featureValueType{return (ZNValueType)[objc_getAssociatedObject(self,valueKey) integerValue];}
- (void)setFeatureValueType:(ZNValueType)t{objc_setAssociatedObject(self,valueKey,@(t),OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
@end
int main(){@autoreleasepool{
 ZNBinaryPatchWorkspace *w=[ZNBinaryPatchWorkspace new];ZNBinaryPatchRow *row=[ZNBinaryPatchRow new];row.title=@"old";row.offsetText=@"0x100";row.featureControlType=ZNFeatureControlTypeSlider;[w.rows addObject:row];
 ZNRuntimeActionStore *global=[ZNRuntimeActionStore sharedStore];NSString *error=nil;
 assert([global replaceWithImportedDictionaries:@[@{@"actionID":@7,@"executionKind":@1,@"class":@"Example",@"method":@"Run",@"title":@"old",@"argumentCount":@0,@"argumentValues":@[]}] error:&error]);
 ZNBuildSession *session=[ZNBuildSession captureWorkspace:w];
 row.title=@"edited";assert([global updateTitle:@"edited" atIndex:0 error:&error]);
 assert(session.workspace.rows[0]!=row);assert([session.workspace.rows[0].title isEqualToString:@"old"]);
 assert(session.workspace.rows[0].featureControlType==ZNFeatureControlTypeSlider);
 assert([session perform:^BOOL{
   assert([ZNRuntimeActionStore sharedStore]==session.runtimeStore);
   assert([[[ZNRuntimeActionStore sharedStore] actionsSnapshot][0].title isEqualToString:@"old"]);
   assert(![session perform:^BOOL{return YES;}]);
   [[ZNRuntimeActionStore sharedStore] updateTitle:@"prepared" atIndex:0 error:nil];return YES;
 }]);
 assert([ZNRuntimeActionStore sharedStore]==global);assert([[global actionsSnapshot][0].title isEqualToString:@"edited"]);
 BOOL threw=NO;@try{[session perform:^BOOL{[NSException raise:@"fault" format:@"injected"];return NO;}];}@catch(NSException *e){(void)e;threw=YES;}
 assert(threw&&[ZNRuntimeActionStore sharedStore]==global);
 NSData *defaultsBefore=[NSJSONSerialization dataWithJSONObject:[NSUserDefaults.standardUserDefaults objectForKey:@"zonoe.native-hook-actions.v1"]?:@[] options:0 error:nil];
 [session.hookStore clear];
 NSData *defaultsAfter=[NSJSONSerialization dataWithJSONObject:[NSUserDefaults.standardUserDefaults objectForKey:@"zonoe.native-hook-actions.v1"]?:@[] options:0 error:nil];
 assert([defaultsBefore isEqualToData:defaultsAfter]);puts("production BuildSession isolation/deep-copy/exception/persistence PASS");
}}
