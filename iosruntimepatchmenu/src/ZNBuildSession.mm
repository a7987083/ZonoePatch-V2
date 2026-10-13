#import "ZNBuildSession.h"
#import "ZNBuildOutputTransaction.h"
#import "ZNBinaryPatchWorkspace.h"
#import "ZNRuntimeActionModel.h"
#import "ZNNativeHookAction.h"
@interface ZNBuildSession ()
@property(nonatomic,copy,readwrite) NSString *identifier;
@property(nonatomic,strong,readwrite) ZNBuildOutputTransaction *outputTransaction;
@property(nonatomic,copy,readwrite) NSDictionary<NSString *,id> *staticDefaults;
@property(nonatomic,strong,readwrite) ZNBinaryPatchWorkspace *workspace;
@property(nonatomic,strong,readwrite) ZNRuntimeActionStore *runtimeStore;
@property(nonatomic,strong,readwrite) ZNNativeHookStore *hookStore;
@end
@implementation ZNBuildSession
+ (instancetype)currentSession {return NSThread.currentThread.threadDictionary[ZNBuildSessionThreadKey];}
+ (instancetype)captureWorkspace:(ZNBinaryPatchWorkspace *)workspace {
    ZNBuildSession *session=[self new];session.identifier=NSUUID.UUID.UUIDString;session.outputTransaction=[ZNBuildOutputTransaction new];
    void (^capture)(void)=^{
        ZNRuntimeActionStore *runtime=[ZNRuntimeActionStore sharedStore];
        ZNNativeHookStore *hooks=[ZNNativeHookStore sharedStore];
        // Store mutation APIs are synchronized; hold both locks while capturing.
        @synchronized(runtime) { @synchronized(hooks) {
        NSMutableDictionary *defaults=[NSMutableDictionary dictionary];
        NSDictionary *all=NSUserDefaults.standardUserDefaults.dictionaryRepresentation;
        for(NSString *key in all)if([key hasPrefix:@"zonoe.m5.8.5.static-slider-max.v1."])defaults[key]=all[key];
        session.staticDefaults=[defaults copy];
        NSMutableArray *indexes=[NSMutableArray array];
        for(NSUInteger i=0;i<workspace.rows.count;i++)[indexes addObject:@(i)];
        session.workspace=[workspace buildSnapshotForRowIndexes:indexes];
        session.runtimeStore=[[ZNRuntimeActionStore alloc] initForBuildWithActions:[runtime actionsSnapshot]];
        session.hookStore=[[ZNNativeHookStore alloc] initForBuildWithActions:[hooks actionsSnapshot]];
        } }
    };
    // Editing belongs to UIKit/main. Capture all three inputs in one main turn.
    if(NSThread.isMainThread)capture();else dispatch_sync(dispatch_get_main_queue(),capture);
    return session;
}
- (BOOL)perform:(BOOL (^)(void))body {
    NSMutableDictionary *thread=NSThread.currentThread.threadDictionary;
    if(thread[ZNBuildRuntimeStoreThreadKey]||thread[ZNBuildHookStoreThreadKey])return NO;
    thread[ZNBuildSessionThreadKey]=self;
    thread[ZNBuildRuntimeStoreThreadKey]=self.runtimeStore;
    thread[ZNBuildHookStoreThreadKey]=self.hookStore;
    @try{return body();}
    @finally{[thread removeObjectForKey:ZNBuildSessionThreadKey];[thread removeObjectForKey:ZNBuildRuntimeStoreThreadKey];[thread removeObjectForKey:ZNBuildHookStoreThreadKey];}
}
@end
