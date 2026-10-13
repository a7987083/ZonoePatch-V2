#import "ZNActivationStageRunner.h"
#import <objc/runtime.h>
void ZNRunActivationStage(NSString *name, void (^block)(void)) {
    if(!NSThread.isMainThread || !name.length || !block)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid activation stage %@ / main=%d",name,NSThread.isMainThread];
    // Fail before any dispatch_once installer can silently consume a missing class.
    if(!NSClassFromString(@"ZNRuntimeMenuControllerV040"))
        [NSException raise:NSInternalInconsistencyException format:@"Menu class missing at activation stage %@",name];
    static NSMutableSet<NSString *> *completed;
    static NSDictionary<NSString *,NSString *> *predecessors;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        completed=[NSMutableSet set];
        predecessors=@{@"FeatureGroupUI":@"RuntimeMenu",@"PublicCompactDefaults":@"FeatureGroupUI",
          @"IL2CPPNamedOffsetWorkspace":@"PublicCompactDefaults",@"FeatureBuilderUI":@"IL2CPPNamedOffsetWorkspace",
          @"RuntimeMethodBuilderUI":@"FeatureBuilderUI",@"MethodFinderUnifiedUI":@"RuntimeMethodBuilderUI",
          @"M630HardCutUI":@"MethodFinderUnifiedUI",@"ZonoePatchStart":@"M630HardCutUI",
          @"PublicCompactLayout":@"SharedSiteExecutionProbeV3",@"RuntimeExecutorV041":@"PublicCompactLayout",
          @"RuntimeDiagnosticsV042":@"RuntimeExecutorV041",@"StaticDispatchPrepare":@"RuntimeDiagnosticsV042"};
    });
    if([completed containsObject:name])return;
    NSString *required=predecessors[name];
    if(required && ![completed containsObject:required])
        [NSException raise:NSInternalInconsistencyException format:@"Activation %@ requires %@",name,required];
    block();
    [completed addObject:name];
}
