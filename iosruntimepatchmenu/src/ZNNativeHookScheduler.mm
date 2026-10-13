#import "ZNNativeHookScheduler.h"

#import "ZNNativeHookAction.h"
#import "ZNNativeHookRuntime.h"
#import "ZNPatchCore.h"

NSNotificationName const ZNNativeHookSchedulerStateDidChangeNotification =
    @"ZNNativeHookSchedulerStateDidChangeNotification";

static NSString * const kZNNativeHookSchedulerValuePrefix =
    @"zonoe.native-hook.runtime-value.v2";

static NSString *ZNHookBindingIdentity(ZNNativeHookAction *a) {
    NSString *extra=[NSString stringWithFormat:@"%@|%lu|%d|%d|%lu|%llu|%llu",a.codecSetterMethod?:@"",(unsigned long)a.callbackArgumentIndex,a.skipOriginal,a.preparedIsStatic,(unsigned long)a.argumentCount,(unsigned long long)a.preparedCodecGetterRVA,(unsigned long long)a.preparedCodecSetterRVA];
    return [NSString stringWithFormat:@"%@|%@|%@|%llx|%lu|%lu|%lu|%llu|%@|%@|%@|%@|%@|%@|%llu",
            extra,a.preparedUUID?:@"",a.canonicalIdentity?:@"",(unsigned long long)a.preparedRVA,
            (unsigned long)a.templateKind,(unsigned long)a.argumentIndex,(unsigned long)a.fieldArgumentIndex,
            (unsigned long long)a.fieldOffset,a.fieldArgumentMode?:@"",a.fieldCodec?:@"",
            a.codecAssembly?:@"",a.codecNamespaceName?:@"",a.codecClassName?:@"",a.codecGetterMethod?:@"",
            (unsigned long long)a.staticHookSlotRVA];
}
static NSString *ZNHookStorageKey(ZNNativeHookAction *a) {
    return [NSString stringWithFormat:@"%@.%u.%@",kZNNativeHookSchedulerValuePrefix,a.actionID,ZNHookBindingIdentity(a)];
}

@interface ZNNativeHookScheduler ()
@property(nonatomic,strong) dispatch_queue_t queue;
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,ZNNativeHookAction *> *actionsByID;
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,NSNumber *> *desiredValues;
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,NSNumber *> *states;
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,NSString *> *errors;
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,NSNumber *> *retryCounts;
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,NSNumber *> *epochs;
@property(nonatomic,strong) NSMutableSet<NSNumber *> *pendingUpdates;
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,NSNumber *> *lifecycleGenerations;
@property(nonatomic,strong) NSMutableSet<NSNumber *> *removedActions;
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,NSString *> *bindingIdentities;
@end

@implementation ZNNativeHookScheduler

+ (instancetype)sharedScheduler {
    static ZNNativeHookScheduler *scheduler;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        scheduler=[ZNNativeHookScheduler new];
    });
    return scheduler;
}

- (instancetype)init {
    self=[super init];
    if(!self)return nil;
    _queue=dispatch_queue_create("com.zonoe.native-hook.scheduler",DISPATCH_QUEUE_SERIAL);
    _actionsByID=[NSMutableDictionary dictionary];
    _desiredValues=[NSMutableDictionary dictionary];
    _states=[NSMutableDictionary dictionary];
    _errors=[NSMutableDictionary dictionary];
    _retryCounts=[NSMutableDictionary dictionary];
    _epochs=[NSMutableDictionary dictionary];
    _pendingUpdates=[NSMutableSet set];
    _lifecycleGenerations=[NSMutableDictionary dictionary];
    _removedActions=[NSMutableSet set];
    _bindingIdentities=[NSMutableDictionary dictionary];
    return self;
}

- (void)publishState:(ZNNativeHookLifecycleState)state
            actionID:(uint32_t)actionID
               error:(NSString *)error {
    NSNumber *key=@(actionID);
    @synchronized(self) {
        self.states[key]=@(state);
        if(error.length)self.errors[key]=error;
        else [self.errors removeObjectForKey:key];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter
            postNotificationName:ZNNativeHookSchedulerStateDidChangeNotification
                          object:self
                        userInfo:@{@"actionID":key,@"state":@(state),@"error":error?:@""}];
    });
}

- (NSInteger)initialDesiredValueForAction:(ZNNativeHookAction *)action {
    NSNumber *key=@(action.actionID);
    @synchronized(self) {
        NSNumber *cached=self.desiredValues[key];
        if(cached)return cached.integerValue;
    }
    NSString *storageKey=ZNHookStorageKey(action);
    id stored=[NSUserDefaults.standardUserDefaults objectForKey:storageKey];
    NSInteger value=stored?[stored integerValue]:action.defaultValue;
    value=MIN(MAX(value,action.minValue),action.maxValue);
    @synchronized(self) {
        self.desiredValues[key]=@(value);
    }
    return value;
}

- (void)prepareActionOnQueue:(ZNNativeHookAction *)action {
    if(!action||!action.actionID)return;
    NSNumber *key=@(action.actionID);
    NSUInteger generation=0;
    @synchronized(self) {
        if([self.removedActions containsObject:key] || !self.actionsByID[key])return;
        generation=[self.lifecycleGenerations[key] unsignedIntegerValue]+1;
        self.lifecycleGenerations[key]=@(generation);
    }
    NSInteger desired=[self initialDesiredValueForAction:action];
    [self publishState:ZNNativeHookLifecycleStatePreparing actionID:action.actionID error:nil];

    NSString *error=nil;
    BOOL ok=[[ZNNativeHookRuntime sharedRuntime] installAction:action value:desired error:&error];
    if(ok){
        @synchronized(self) {
            self.retryCounts[key]=@0;
        }
        [self publishState:ZNNativeHookLifecycleStateActive actionID:action.actionID error:nil];
        [[ZNRuntimeLogger sharedLogger] log:
         [NSString stringWithFormat:@"[native-hook-scheduler] ACTIVE action=%u %@ desired=%ld permanent=YES",
          action.actionID,action.canonicalIdentity?:@"",(long)desired]];
        return;
    }

    NSUInteger retry=0;
    @synchronized(self) {
        retry=[self.retryCounts[key] unsignedIntegerValue]+1;
        self.retryCounts[key]=@(retry);
    }

    if(retry>5){
        [self publishState:ZNNativeHookLifecycleStateFailed actionID:action.actionID error:error?:@"Hook prepare failed"];
        [[ZNRuntimeLogger sharedLogger] log:
         [NSString stringWithFormat:@"[native-hook-scheduler] FAILED action=%u retries=%lu %@",
          action.actionID,(unsigned long)retry,error?:@"unknown"]];
        return;
    }

    [self publishState:ZNNativeHookLifecycleStateRetryPending actionID:action.actionID error:error?:@"Hook prepare pending"];
    NSTimeInterval delay=MIN(4.0,0.25*(1u<<(MIN((NSUInteger)4,retry-1))));
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),self.queue,^{
        typeof(self) self=weakSelf;
        if(!self)return;
        if([self stateForActionID:action.actionID]==ZNNativeHookLifecycleStateActive)return;
        ZNNativeHookAction *latest=nil;
        @synchronized(self) {
            if([self.removedActions containsObject:key] ||
               generation!=[self.lifecycleGenerations[key] unsignedIntegerValue])return;
            latest=self.actionsByID[key];
        }
        if(latest)[self prepareActionOnQueue:latest];
    });
}

- (void)reconcileActions:(NSArray<ZNNativeHookAction *> *)actions {
    NSArray<ZNNativeHookAction *> *snapshot=[actions copy]?:@[];
    __weak typeof(self) weakSelf=self;
    dispatch_async(self.queue,^{
        typeof(self) self=weakSelf;
        if(!self)return;

        NSMutableSet *incoming=[NSMutableSet set];
        for(ZNNativeHookAction *action in snapshot)if(action.actionID)[incoming addObject:@(action.actionID)];
        NSArray *oldKeys=nil;@synchronized(self){oldKeys=[self.actionsByID allKeys];}
        for(NSNumber *oldKey in oldKeys)if(![incoming containsObject:oldKey]){
            ZNNativeHookAction *old=nil;@synchronized(self){old=self.actionsByID[oldKey];}
            if(old)[self teardownAction:old];
        }
        for(ZNNativeHookAction *action in snapshot){
            if(!action.actionID)continue;
            NSNumber *key=@(action.actionID);
            @synchronized(self) {
                // Explicit teardown is a tombstone until a new desired-value command.
                if([self.removedActions containsObject:key])continue;
                ZNNativeHookAction *prior=self.actionsByID[key];
                NSString *bound=self.bindingIdentities[key];
                if(bound && ![bound isEqualToString:ZNHookBindingIdentity(action)]) {
                    if(prior)[[ZNNativeHookRuntime sharedRuntime] removeAction:prior error:nil];
                    [self publishState:ZNNativeHookLifecycleStateFailed actionID:action.actionID
                                error:@"actionID reused for a different Hook binding; use a new ID or restart"];
                    continue;
                }
                self.bindingIdentities[key]=ZNHookBindingIdentity(action);
                self.actionsByID[key]=[action copy];
                if(!self.states[key])self.states[key]=@(ZNNativeHookLifecycleStateDiscovered);
            }

            ZNNativeHookLifecycleState state=[self stateForActionID:action.actionID];
            if(state==ZNNativeHookLifecycleStateActive||
               state==ZNNativeHookLifecycleStatePreparing)continue;
            // A dyld image-added or foreground lifecycle event may make the
            // resolver/backend ready. RetryPending must not wait for the old
            // exponential timer; prepare immediately. The stale timer exits
            // once state becomes Active.
            [self prepareActionOnQueue:action];
        }
    });
}

- (void)setDesiredValue:(NSInteger)value forAction:(ZNNativeHookAction *)action {
    ZNNativeHookAction *snapshot=[action copy];
    dispatch_async(self.queue,^{[self zn_setDesiredValueOnQueue:value forAction:snapshot];});
}
- (void)zn_setDesiredValueOnQueue:(NSInteger)value forAction:(ZNNativeHookAction *)action {
    if(!action||!action.actionID)return;
    value=MIN(MAX(value,action.minValue),action.maxValue);
    NSNumber *key=@(action.actionID);

    NSUInteger epoch=0;
    BOOL needsSchedule=NO;
    @synchronized(self) {
        NSString *bound=self.bindingIdentities[key];
        if(bound && ![bound isEqualToString:ZNHookBindingIdentity(action)]) {
            [self publishState:ZNNativeHookLifecycleStateFailed actionID:action.actionID
                        error:@"actionID identity conflict; value update rejected"];
            return;
        }
        [self.removedActions removeObject:key];
        self.bindingIdentities[key]=ZNHookBindingIdentity(action);
        self.actionsByID[key]=[action copy];
        self.desiredValues[key]=@(value);
        epoch=[self.epochs[key] unsignedIntegerValue]+1;
        self.epochs[key]=@(epoch);
        if(![self.pendingUpdates containsObject:key]){
            [self.pendingUpdates addObject:key];
            needsSchedule=YES;
        }
    }
    [NSUserDefaults.standardUserDefaults setInteger:value forKey:ZNHookStorageKey(action)];
    if(!needsSchedule)return;

    __weak typeof(self) weakSelf=self;
    dispatch_async(self.queue,^{
        typeof(self) self=weakSelf;
        if(!self)return;

        for(;;){
            ZNNativeHookAction *latest=nil;
            NSInteger desired=0;
            NSUInteger beforeEpoch=0;
            @synchronized(self) {
                latest=self.actionsByID[key];
                desired=[self.desiredValues[key] integerValue];
                beforeEpoch=[self.epochs[key] unsignedIntegerValue];
            }
            if(!latest){@synchronized(self){[self.pendingUpdates removeObject:key];}break;}

            NSString *error=nil;
            BOOL ok=[[ZNNativeHookRuntime sharedRuntime] setValue:desired forAction:latest error:&error];
            if(ok){
                [self publishState:ZNNativeHookLifecycleStateActive actionID:latest.actionID error:nil];
            }else{
                [self publishState:ZNNativeHookLifecycleStateRetryPending actionID:latest.actionID error:error?:@"Hook state update failed"];
                [self prepareActionOnQueue:latest];
            }

            BOOL stable=NO;
            @synchronized(self) {
                stable=beforeEpoch==[self.epochs[key] unsignedIntegerValue];
                if(stable)[self.pendingUpdates removeObject:key];
            }
            if(stable)break;
        }
    });
}

- (void)teardownAction:(ZNNativeHookAction *)action {
    if(!action||!action.actionID)return;
    __weak typeof(self) weakSelf=self;
    dispatch_async(self.queue,^{
        typeof(self) self=weakSelf;
        if(!self)return;
        NSNumber *key=@(action.actionID);
        @synchronized(self) {
            self.lifecycleGenerations[key]=@([self.lifecycleGenerations[key] unsignedIntegerValue]+1);
            [self.removedActions addObject:key];
            [self.actionsByID removeObjectForKey:key];
            [self.desiredValues removeObjectForKey:key];
            [self.retryCounts removeObjectForKey:key];
            [self.pendingUpdates removeObject:key];
            self.epochs[key]=@([self.epochs[key] unsignedIntegerValue]+1);
        }
        NSString *error=nil;
        BOOL ok=[[ZNNativeHookRuntime sharedRuntime] removeAction:action error:&error];
        [self publishState:(ok?ZNNativeHookLifecycleStateTeardown:ZNNativeHookLifecycleStateFailed)
                  actionID:action.actionID
                     error:ok?nil:(error?:@"Hook teardown failed")];
    });
}

- (ZNNativeHookLifecycleState)stateForActionID:(uint32_t)actionID {
    @synchronized(self) {
        NSNumber *state=self.states[@(actionID)];
        return state?(ZNNativeHookLifecycleState)state.integerValue:ZNNativeHookLifecycleStateDiscovered;
    }
}

- (NSString *)lastErrorForActionID:(uint32_t)actionID {
    @synchronized(self) {
        return self.errors[@(actionID)];
    }
}

@end
