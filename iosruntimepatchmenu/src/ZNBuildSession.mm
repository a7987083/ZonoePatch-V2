#import "ZNBuildSession.h"
#import "ZNBinaryPatchWorkspace.h"
#import "ZNRuntimeActionModel.h"
#import "ZNNativeHookAction.h"
@interface ZNBuildSession ()
@property(nonatomic,strong,readwrite) ZNBinaryPatchWorkspace *workspace;
@property(nonatomic,strong,readwrite) ZNRuntimeActionStore *runtimeStore;
@property(nonatomic,strong,readwrite) ZNNativeHookStore *hookStore;
@end
@implementation ZNBuildSession
+ (instancetype)captureWorkspace:(ZNBinaryPatchWorkspace *)workspace {
    ZNBuildSession *session=[self new];
    void (^capture)(void)=^{
        NSMutableArray *indexes=[NSMutableArray array];
        for(NSUInteger i=0;i<workspace.rows.count;i++)[indexes addObject:@(i)];
        session.workspace=[workspace buildSnapshotForRowIndexes:indexes];
        session.runtimeStore=[[ZNRuntimeActionStore alloc] initForBuildWithActions:[[ZNRuntimeActionStore sharedStore] actionsSnapshot]];
        session.hookStore=[[ZNNativeHookStore alloc] initForBuildWithActions:[[ZNNativeHookStore sharedStore] actionsSnapshot]];
    };
    // Editing belongs to UIKit/main. Capture all three inputs in one main turn.
    if(NSThread.isMainThread)capture();else dispatch_sync(dispatch_get_main_queue(),capture);
    return session;
}
- (BOOL)perform:(BOOL (^)(void))body {
    NSMutableDictionary *thread=NSThread.currentThread.threadDictionary;
    if(thread[ZNBuildRuntimeStoreThreadKey]||thread[ZNBuildHookStoreThreadKey])return NO;
    thread[ZNBuildRuntimeStoreThreadKey]=self.runtimeStore;
    thread[ZNBuildHookStoreThreadKey]=self.hookStore;
    @try{return body();}
    @finally{[thread removeObjectForKey:ZNBuildRuntimeStoreThreadKey];[thread removeObjectForKey:ZNBuildHookStoreThreadKey];}
}
@end
