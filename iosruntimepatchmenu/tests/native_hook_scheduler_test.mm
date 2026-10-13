#import <Foundation/Foundation.h>
#import "ZNNativeHookScheduler.h"
#import "ZNNativeHookRuntime.h"
#import "ZNNativeHookAction.h"
#import "ZNPatchCore.h"
#include <cassert>
// Mock implementations intentionally implement only the consumed backend surface.
#pragma clang diagnostic ignored "-Wincomplete-implementation"
static unsigned installs,removes;
@implementation ZNNativeHookAction
- (id)copyWithZone:(NSZone *)zone { ZNNativeHookAction *a=[ZNNativeHookAction new];a.actionID=self.actionID;a.minValue=self.minValue;a.maxValue=self.maxValue;a.preparedRVA=self.preparedRVA;return a; }
@end
@implementation ZNNativeHookRuntime
+ (instancetype)sharedRuntime {static id x;static dispatch_once_t once;dispatch_once(&once,^{x=[self new];});return x;}
- (BOOL)installAction:(ZNNativeHookAction *)a value:(NSInteger)v error:(NSString **)e {(void)a;(void)v;if(e)*e=@"pending";installs++;return NO;}
- (BOOL)removeAction:(ZNNativeHookAction *)a error:(NSString **)e {(void)a;(void)e;removes++;return YES;}
- (BOOL)setValue:(NSInteger)v forAction:(ZNNativeHookAction *)a error:(NSString **)e {(void)v;(void)a;(void)e;return YES;}
@end
@implementation ZNRuntimeLogger
+ (instancetype)sharedLogger {static id x;static dispatch_once_t once;dispatch_once(&once,^{x=[self new];});return x;}
- (void)log:(NSString *)s {(void)s;}
@end
static void drain(id scheduler) {dispatch_queue_t q=[scheduler valueForKey:@"queue"];dispatch_sync(q,^{});dispatch_sync(q,^{});}
int main(){@autoreleasepool{
 ZNNativeHookScheduler *s=[ZNNativeHookScheduler new];ZNNativeHookAction *a=[ZNNativeHookAction new];a.actionID=71;a.maxValue=10;
 [s reconcileActions:@[a]];drain(s);assert(installs==1);
 [s teardownAction:a];drain(s);assert(removes==1);
 [NSThread sleepForTimeInterval:0.35];drain(s);assert(installs==1);
 [s reconcileActions:@[a]];drain(s);assert(installs==1);
 assert([s stateForActionID:71]==ZNNativeHookLifecycleStateTeardown);
 [s setDesiredValue:2 forAction:a];drain(s);assert([s stateForActionID:71]==ZNNativeHookLifecycleStateActive);
 ZNNativeHookAction *conflict=[a copy];conflict.preparedRVA=0x1234;
 [s setDesiredValue:3 forAction:conflict];drain(s);
 assert([s stateForActionID:71]==ZNNativeHookLifecycleStateFailed);
 [s reconcileActions:@[]];drain(s);assert([s stateForActionID:71]==ZNNativeHookLifecycleStateTeardown);
 [s setDesiredValue:3 forAction:conflict];drain(s);assert([s stateForActionID:71]==ZNNativeHookLifecycleStateFailed);
 puts("scheduler remove/retry/reconcile/identity-conflict regression PASS");
}}
