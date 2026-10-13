#pragma mark - BEGIN ZNM52ChainExecuteButton.mm
#line 1 "ZNM52ChainExecuteButton.mm"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "ZNIL2CPPInvokeEngine.h"
#import "ZNIL2CPPInstanceResolver.h"
#import "ZNIL2CPPInstanceSelectionV2.h"
#import "ZNIL2CPPResolver.h"
#import "ZNIL2CPPRuntimeCommon.h"
#import "ZNRuntimeActionModel.h"
#import "ZNNativeHookAction.h"
#import "ZNNativeHookRuntime.h"
#import "ZNIL2CPPABIMetadata.h"
#import "ZNCapabilityRegistry.h"
#import "ZNBuiltInCapabilityAdapters.h"
#import "ZNDirectNativeCallEngine.h"
#import "ZNComplexStructCodec.h"
#import "ZNComplexStructCodecResolver.h"
#import "ZNPatchCore.h"

static const void *kZNM52XActionKey = &kZNM52XActionKey;
static const void *kZNM52XIndexKey = &kZNM52XIndexKey;
static const void *kZNM52XCandidateKey = &kZNM52XCandidateKey;
static const void *kZNM613CreateModeKey = &kZNM613CreateModeKey;
static const void *kZNM613ArgCandidateKey = &kZNM613ArgCandidateKey;
static const void *kZNM613ArgIndexKey = &kZNM613ArgIndexKey;
static const void *kZNM613ArgumentStoreKey = &kZNM613ArgumentStoreKey;
static const void *kZNM613ModeStoreKey = &kZNM613ModeStoreKey;
static const void *kZNM613AnalysisKey = &kZNM613AnalysisKey;
@interface ZNRuntimeMenuControllerV040 (ZNM52ChainExecuteButton)
- (void)zn52x_renderResultsAtWidth:(CGFloat)width;
- (void)zn52x_executeChainTapped:(UIButton *)sender;
- (void)zn52x_restartChainLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)zn52x_reselectInstance:(UIButton *)sender;
- (void)zn52x_batchTestInstances:(UIButton *)sender;
- (void)zn52x_directUnavailable:(UIButton *)sender;
- (void)znm613_argumentChanged:(UITextField *)field;
- (void)znm613_argumentDone:(UITextField *)field;
- (void)znm613_selectRuntimeMode:(UIButton *)sender;
- (void)znm613_createCurrentMode:(UIButton *)sender;
- (void)znm613_testRuntime:(UIButton *)sender;
- (void)znm613_chainTapped:(UIButton *)sender;
- (void)znm613_captureLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)znm613_applyOrRestoreHook:(UIButton *)sender;
- (void)zn64_testModeTapped:(UIButton *)sender;
- (void)zn64_hookTestTapped:(UIButton *)sender;
- (void)znm660_chooseHookControlForAction:(ZNNativeHookAction *)action source:(UIView *)source;
- (void)znm660_editHookControlTapped:(UIButton *)sender;
- (void)zn64_presentHookConfigForCandidate:(NSDictionary *)candidate
                              argumentIndex:(NSUInteger)argumentIndex
                                     source:(UIButton *)source;

- (void)zn68_presentStructFieldPickerForCandidate:(NSDictionary *)candidate
                                           indices:(NSArray<NSNumber *> *)indices
                                            source:(UIButton *)source;
 - (void)zn68_presentManualStructFieldConfigForCandidate:(NSDictionary *)candidate
                                     argumentIndex:(NSUInteger)argumentIndex
                                            source:(UIButton *)source;
- (void)zn68_presentStructFieldConfigForCandidate:(NSDictionary *)candidate
                                     argumentIndex:(NSUInteger)argumentIndex
                                            source:(UIButton *)source;
@end

static NSString *ZNM52XString(id value) {
    return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSArray<NSDictionary *> *ZNM52XVisible(ZNRuntimeMenuControllerV040 *controller) {
    NSArray<NSDictionary *> *all = [controller zn60v3_candidates] ?: @[];
    NSInteger filter = [controller znm42_filter];
    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    for (NSDictionary *candidate in all) {
        if (filter < 0 || [candidate[@"argumentCount"] integerValue] == filter) [out addObject:candidate];
    }
    return out;
}

static void ZNM52XCollectChainButtons(UIView *root, NSMutableArray<UIButton *> *out) {
    for (UIView *view in root.subviews) {
        if ([view isKindOfClass:UIButton.class]) {
            NSString *title = [(UIButton *)view titleForState:UIControlStateNormal] ?: @"";
            if ([title isEqualToString:@"链式调用"] || [title isEqualToString:@"执行链"]) [out addObject:(UIButton *)view];
        }
        ZNM52XCollectChainButtons(view, out);
    }
}

static UIButton *ZNM52XButtonWithTitles(UIView *card, NSArray<NSString *> *titles) {
    for (UIView *view in card.subviews) {
        if (![view isKindOfClass:UIButton.class]) continue;
        UIButton *button=(UIButton *)view;
        NSString *title=[button titleForState:UIControlStateNormal] ?: @"";
        if ([titles containsObject:title]) return button;
    }
    return nil;
}


static BOOL ZNM52XBatchSafe(NSDictionary *candidate) {
    if([candidate[@"argumentCount"] unsignedIntegerValue]!=0)return NO;
    NSString *method=ZNM52XString(candidate[@"method"]).lowercaseString;
    return [method hasPrefix:@"get_"] || [method hasPrefix:@"is"] ||
           [method hasPrefix:@"has"] || [method hasPrefix:@"can"];
}

static void ZNM52XStyleGridButton(UIButton *button,CGFloat x,CGFloat y,CGFloat w,CGFloat h) {
    if(!button)return;
    button.frame=CGRectMake(x,y,w,h);
    button.titleLabel.font=[UIFont systemFontOfSize:8.1 weight:UIFontWeightSemibold];
    button.titleLabel.adjustsFontSizeToFitWidth=YES;
    button.titleLabel.minimumScaleFactor=.65;
}

static BOOL ZNM52XCandidateMatches(NSDictionary *candidate, ZNRuntimeMethodAction *action) {
    NSDictionary *chain = [action.immediateChain isKindOfClass:NSDictionary.class] ? action.immediateChain : @{};
    NSArray *nodes = [chain[@"nodes"] isKindOfClass:NSArray.class] ? chain[@"nodes"] : nil;
    if ([chain[@"version"] integerValue] != 2 || !nodes.count) return NO;
    NSString *assembly = ZNM52XString(candidate[@"assembly"]); if (!assembly.length) assembly = @"Assembly-CSharp.dll";
    return [action.assembly isEqualToString:assembly] &&
           [(action.namespaceName ?: @"") isEqualToString:ZNM52XString(candidate[@"namespace"])] &&
           [action.className isEqualToString:ZNM52XString(candidate[@"class"])] &&
           [action.methodName isEqualToString:ZNM52XString(candidate[@"method"])] &&
           action.argumentCount == [candidate[@"argumentCount"] unsignedIntegerValue];
}

static NSInteger ZNM52XFindChain(NSDictionary *candidate, ZNRuntimeMethodAction **outAction) {
    NSArray<ZNRuntimeMethodAction *> *actions = [[ZNRuntimeActionStore sharedStore] actionsSnapshot];
    for (NSInteger i = (NSInteger)actions.count - 1; i >= 0; i--) {
        ZNRuntimeMethodAction *action = actions[(NSUInteger)i];
        if (ZNM52XCandidateMatches(candidate, action)) {
            if (outAction) *outAction = action;
            return i;
        }
    }
    return NSNotFound;
}

static UIViewController *ZNM52XTop(UIWindow *window) {
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

static NSString *ZNM52XTrace(NSDictionary *result) {
    NSArray *trace = [result[@"chainTrace"] isKindOfClass:NSArray.class] ? result[@"chainTrace"] : @[];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSDictionary *level in trace) {
        NSString *identity = ZNM52XString(level[@"identity"]);
        [lines addObject:[NSString stringWithFormat:@"L%@ %@ → %@", level[@"level"] ?: @"?", identity.length ? identity : @"?", level[@"returnValue"] ?: @"?"]];
    }
    return [lines componentsJoinedByString:@"\n"];
}


static NSString *ZNM613CandidateIdentity(NSDictionary *candidate) {
    NSString *canonical=ZNM52XString(candidate[@"canonical"]);
    if(canonical.length)return canonical;
    return [NSString stringWithFormat:@"%@!%@.%@::%@/%@",
            ZNM52XString(candidate[@"assembly"]),ZNM52XString(candidate[@"namespace"]),
            ZNM52XString(candidate[@"class"]),ZNM52XString(candidate[@"method"]),
            candidate[@"argumentCount"]?:@0];
}

static NSMutableDictionary *ZNM613ArgumentStore(ZNRuntimeMenuControllerV040 *self) {
    NSMutableDictionary *store=objc_getAssociatedObject(self,kZNM613ArgumentStoreKey);
    if(!store){store=[NSMutableDictionary dictionary];objc_setAssociatedObject(self,kZNM613ArgumentStoreKey,store,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
    return store;
}

static NSString *ZNM613ArgumentStoreKey(NSDictionary *candidate,NSUInteger index) {
    return [NSString stringWithFormat:@"%@#%lu",ZNM613CandidateIdentity(candidate),(unsigned long)index];
}

static NSArray<NSString *> *ZNM613ArgumentValues(ZNRuntimeMenuControllerV040 *self,NSDictionary *candidate) {
    NSUInteger argc=[candidate[@"argumentCount"] unsignedIntegerValue];
    NSMutableArray *values=[NSMutableArray arrayWithCapacity:argc];
    NSMutableDictionary *store=ZNM613ArgumentStore(self);
    for(NSUInteger i=0;i<argc;i++){
        NSString *key=ZNM613ArgumentStoreKey(candidate,i);
        NSString *value=[store[key] isKindOfClass:NSString.class]?store[key]:@"";
        [values addObject:value];
    }
    return values;
}

static NSString *ZNM613ParamAutoLabel(NSDictionary *param) {
    NSString *type=[param[@"name"] isKindOfClass:NSString.class]?param[@"name"]:@"?";
    NSString *codec=ZNComplexStructCodecKeyForManagedType(type);
    if([codec isEqualToString:ZNComplexStructCodecObscuredInt])return @"ObscuredInt Codec · ARM64 indirect struct";
    if([codec isEqualToString:ZNComplexStructCodecSecureLongWholeAccessor])return @"Complex Struct · SecureLong Codec";
    ZNIL2CPPABIValueKind kind=(ZNIL2CPPABIValueKind)[param[@"kind"] integerValue];
    switch(kind){
        case ZNIL2CPPABIValueKindBool:return @"Bool";
        case ZNIL2CPPABIValueKindSigned32:return @"Int32";
        case ZNIL2CPPABIValueKindUnsigned32:return @"UInt32";
        case ZNIL2CPPABIValueKindSigned64:return @"Int64";
        case ZNIL2CPPABIValueKindUnsigned64:return @"UInt64";
        case ZNIL2CPPABIValueKindPointer:return @"Pointer";
        case ZNIL2CPPABIValueKindObjectReference:return @"Object Reference";
        case ZNIL2CPPABIValueKindComplexValueType:return @"Complex Struct · Unsupported Codec";
        default:return type.length?type:@"Unknown";
    }
}

static BOOL ZNM613GPRKind(ZNIL2CPPABIValueKind kind) {
    return kind==ZNIL2CPPABIValueKindBool||
           kind==ZNIL2CPPABIValueKindSigned32||kind==ZNIL2CPPABIValueKindUnsigned32||
           kind==ZNIL2CPPABIValueKindSigned64||kind==ZNIL2CPPABIValueKindUnsigned64||
           kind==ZNIL2CPPABIValueKindPointer||kind==ZNIL2CPPABIValueKindObjectReference;
}

static NSDictionary *ZNM613HookPlanFromABI(NSDictionary *candidate,NSDictionary *abi,NSString **error) {
    NSArray<NSDictionary *> *params=[abi[@"parameters"] isKindOfClass:NSArray.class]?abi[@"parameters"]:@[];
    NSDictionary *ret=[abi[@"return"] isKindOfClass:NSDictionary.class]?abi[@"return"]:@{};
    NSUInteger argc=[candidate[@"argumentCount"] unsignedIntegerValue];

    if(![abi[@"available"] boolValue]||params.count!=argc){
        if(error)*error=[abi[@"reason"] isKindOfClass:NSString.class]?abi[@"reason"]:@"参数 ABI 不完整";
        return nil;
    }
    if([abi[@"generic"] boolValue]||[abi[@"inflated"] boolValue]){
        if(error)*error=@"Native Hook 自动模式不支持 generic/inflated";
        return nil;
    }

    BOOL instanceKnown=[abi[@"instanceKnown"] boolValue];
    BOOL instance=[abi[@"instance"] boolValue];
    NSUInteger gprBase=instance?1u:0u;

    NSMutableArray<NSNumber *> *intArgs=[NSMutableArray array];
    NSMutableArray<NSNumber *> *cbArgs=[NSMutableArray array];
    NSMutableArray<NSNumber *> *structArgs=[NSMutableArray array];
    BOOL allGPR=YES,allReturnSafe=YES;

    for(NSUInteger i=0;i<params.count;i++){
        NSDictionary *p=params[i];
        ZNIL2CPPABIValueKind kind=(ZNIL2CPPABIValueKind)[p[@"kind"] integerValue];
        BOOL byRef=[p[@"byRef"] boolValue];
        NSString *type=[p[@"name"] isKindOfClass:NSString.class]?p[@"name"]:@"";
        NSString *lower=type.lowercaseString;

        if(kind==ZNIL2CPPABIValueKindSigned32&&!byRef&&gprBase+i<8)[intArgs addObject:@(i)];

        BOOL callback=(kind==ZNIL2CPPABIValueKindObjectReference&&
                       [lower containsString:@"system.action"]&&
                       [lower containsString:@"system.boolean"]);
        if(callback&&gprBase+i<8)[cbArgs addObject:@(i)];

        NSString *codec=ZNComplexStructCodecKeyForManagedType(type);
        BOOL complex=(kind==ZNIL2CPPABIValueKindComplexValueType)||byRef;
        if(complex&&codec.length&&instanceKnown&&gprBase+i<8)[structArgs addObject:@(i)];

        if(!ZNM613GPRKind(kind))allGPR=NO;
        if(!ZNM613GPRKind(kind)||byRef)allReturnSafe=NO;
    }

    BOOL callbackOK=((ZNIL2CPPABIValueKind)[ret[@"kind"] integerValue]==ZNIL2CPPABIValueKindVoid)&&
                    allGPR&&gprBase+argc<=7u&&cbArgs.count>0;
    if(!callbackOK)[cbArgs removeAllObjects];

    BOOL returnBool=((ZNIL2CPPABIValueKind)[ret[@"kind"] integerValue]==ZNIL2CPPABIValueKindBool)&&
                    allReturnSafe&&gprBase+argc<=7u;

    NSUInteger alternatives=(intArgs.count?1:0)+(cbArgs.count?1:0)+(returnBool?1:0)+(structArgs.count?1:0);
    if(alternatives==0){
        if(error)*error=@"没有唯一且 ABI-safe 的 Native Hook 自动方案";
        return nil;
    }
    if(alternatives>1){
        if(error)*error=@"检测到多个 Native Hook 方案；自动模式拒绝猜测";
        return nil;
    }
    if(structArgs.count){
        if(structArgs.count!=1){if(error)*error=@"存在多个可识别 Complex Struct 参数；自动模式拒绝猜测";return nil;}
        NSUInteger idx=structArgs.firstObject.unsignedIntegerValue;
        NSString *type=[params[idx][@"name"] isKindOfClass:NSString.class]?params[idx][@"name"]:@"";
        return @{@"kind":@"complex",@"index":@(idx),@"type":type,
                 @"codec":ZNComplexStructCodecKeyForManagedType(type)?:@""};
    }
    if(intArgs.count){
        if(intArgs.count!=1){if(error)*error=@"存在多个 Int32 参数；自动模式拒绝猜测";return nil;}
        return @{@"kind":@"int32",@"index":intArgs.firstObject};
    }
    if(cbArgs.count){
        if(cbArgs.count!=1){if(error)*error=@"存在多个 Bool Callback 参数；自动模式拒绝猜测";return nil;}
        return @{@"kind":@"callback",@"index":cbArgs.firstObject};
    }
    if(returnBool)return @{@"kind":@"return-bool"};
    return nil;
}

static NSCache<NSString *,NSDictionary *> *ZNM613AnalysisCache(void) {
    static NSCache<NSString *,NSDictionary *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{cache=[NSCache new];cache.countLimit=512;});
    return cache;
}

static NSDictionary *ZNM613AnalyzeCandidate(NSDictionary *candidate) {
    NSString *key=[NSString stringWithFormat:@"%@|mi:%llX|mp:%llX",
                   ZNM613CandidateIdentity(candidate),
                   (unsigned long long)[candidate[@"methodInfo"] unsignedLongLongValue],
                   (unsigned long long)[candidate[@"methodPointer"] unsignedLongLongValue]];
    NSDictionary *cached=[ZNM613AnalysisCache() objectForKey:key];
    if(cached)return cached;

    NSDictionary *abi=ZNIL2CPPDescribeMethodABI(candidate)?:@{};
    NSArray<NSDictionary *> *params=[abi[@"parameters"] isKindOfClass:NSArray.class]?abi[@"parameters"]:@[];
    NSUInteger argc=[candidate[@"argumentCount"] unsignedIntegerValue];

    BOOL metadataOK=[abi[@"available"] boolValue]&&params.count==argc&&argc<=ZN_RUNTIME_ACTION_MAX_ARGUMENTS;
    BOOL runtimeOK=metadataOK;
    if(runtimeOK){
        for(NSDictionary *p in params)if(ZNM54UnsupportedReason(p).length){runtimeOK=NO;break;}
    }

    NSString *directReason=nil;
    BOOL directOK=metadataOK && [[ZNDirectNativeCallEngine sharedEngine] supportsCandidate:candidate reason:&directReason];

    NSString *hookError=nil;
    NSDictionary *hookPlan=ZNM613HookPlanFromABI(candidate,abi,&hookError);

    BOOL instanceKnown=[abi[@"instanceKnown"] boolValue];
    BOOL instance=instanceKnown&&[abi[@"instance"] boolValue];
    uintptr_t methodPointer=[candidate[@"methodPointer"] unsignedLongLongValue];
    BOOL canCapture=instanceKnown&&instance&&methodPointer&&((methodPointer&3ULL)==0);

    NSDictionary *analysis=@{
        @"abi":abi,
        @"params":params,
        @"runtimeOK":@(runtimeOK),
        @"directOK":@(directOK),
        @"directReason":directReason?:@"",
        @"hookPlan":hookPlan?:@{},
        @"hookError":hookError?:@"",
        @"hookOK":@(hookPlan!=nil),
        @"instanceKnown":@(instanceKnown),
        @"instance":@(instance),
        @"canCapture":@(canCapture)
    };
    [ZNM613AnalysisCache() setObject:analysis forKey:key];
    return analysis;
}

static NSDictionary *ZNM613HookPlan(NSDictionary *candidate,NSString **error) {
    NSDictionary *analysis=ZNM613AnalyzeCandidate(candidate);
    NSDictionary *plan=[analysis[@"hookPlan"] isKindOfClass:NSDictionary.class]?analysis[@"hookPlan"]:@{};
    if(!plan.count&&error)*error=[analysis[@"hookError"] isKindOfClass:NSString.class]?analysis[@"hookError"]:@"Native Hook 自动方案不可用";
    return plan.count?plan:nil;
}
static NSMutableDictionary *ZNM613ModeStore(ZNRuntimeMenuControllerV040 *self) {
    NSMutableDictionary *store=objc_getAssociatedObject(self,kZNM613ModeStoreKey);
    if(!store){
        store=[NSMutableDictionary dictionary];
        objc_setAssociatedObject(self,kZNM613ModeStoreKey,store,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return store;
}

static NSString *ZNM613ModeForCandidate(ZNRuntimeMenuControllerV040 *self,NSDictionary *candidate) {
    NSString *mode=ZNM613ModeStore(self)[ZNM613CandidateIdentity(candidate)];
    return [mode isKindOfClass:NSString.class]&&mode.length?mode:@"runtime";
}

static void ZNM613StyleModeButton(UIButton *button,BOOL selected,ZNTheme *theme) {
    if(!button)return;
    button.backgroundColor=selected?[theme.accentColor colorWithAlphaComponent:0.30]:theme.controlColor;
    button.layer.borderColor=(selected?theme.accentColor:theme.borderColor).CGColor;
}

static void ZNM613ApplyModeVisual(ZNRuntimeMenuControllerV040 *self,UIView *card,NSDictionary *candidate,NSString *mode) {
    if(!card||!candidate)return;
    UIButton *create=ZNM52XButtonWithTitles(card,@[@"创建方法"]);
    UIButton *direct=ZNM52XButtonWithTitles(card,@[@"Native Call"]);
    UIButton *hook=ZNM52XButtonWithTitles(card,@[@"Native Hook"]);
    NSDictionary *analysis=objc_getAssociatedObject(card,kZNM613AnalysisKey);
    if(![analysis isKindOfClass:NSDictionary.class])analysis=ZNM613AnalyzeCandidate(candidate);
    BOOL runtimeOK=[analysis[@"runtimeOK"] boolValue];
    BOOL directOK=[analysis[@"directOK"] boolValue];
    BOOL hookOK=[analysis[@"hookOK"] boolValue];

    ZNM613StyleModeButton(direct,[mode isEqualToString:@"direct"],self.theme);
    ZNM613StyleModeButton(hook,[mode isEqualToString:@"hook"],self.theme);

    if(create){
        BOOL canCreate=[mode isEqualToString:@"direct"]?directOK:([mode isEqualToString:@"hook"]?hookOK:runtimeOK);
        create.enabled=canCreate;
        create.alpha=canCreate?1.0:.48;
        objc_setAssociatedObject(create,kZNM613CreateModeKey,mode,OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
}

static void ZNM613SetModeForCard(ZNRuntimeMenuControllerV040 *self,UIView *card,NSDictionary *candidate,NSString *mode) {
    if(!candidate||!mode.length)return;
    ZNM613ModeStore(self)[ZNM613CandidateIdentity(candidate)]=mode;
    ZNM613ApplyModeVisual(self,card,candidate,mode);
}

@implementation ZNRuntimeMenuControllerV040 (ZNM52ChainExecuteButton)

- (void)zn68_presentStructFieldPickerForCandidate:(NSDictionary *)candidate
                                           indices:(NSArray<NSNumber *> *)indices
                                            source:(UIButton *)source {
    NSDictionary *abi=ZNIL2CPPDescribeMethodABI(candidate);
    NSArray *params=[abi[@"parameters"] isKindOfClass:NSArray.class]?abi[@"parameters"]:@[];
    if(indices.count==1){
        [self zn68_presentStructFieldConfigForCandidate:candidate argumentIndex:indices.firstObject.unsignedIntegerValue source:source];
        return;
    }
    UIAlertController *picker=[UIAlertController alertControllerWithTitle:@"选择 Struct 参数"
                                                                   message:@"ComplexStructTransform V1 · whole struct codec · 无需 Field Offset"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf=self;
    for(NSNumber *n in indices){
        NSUInteger idx=n.unsignedIntegerValue;
        NSDictionary *p=idx<params.count?params[idx]:@{};
        NSString *pn=[p[@"paramName"] isKindOfClass:NSString.class]?p[@"paramName"]:@"";
        NSString *tn=[p[@"name"] isKindOfClass:NSString.class]?p[@"name"]:@"complex value";
        NSString *title=pn.length?[NSString stringWithFormat:@"参数%lu · %@ · %@",(unsigned long)idx+1,pn,tn]:
                                  [NSString stringWithFormat:@"参数%lu · %@",(unsigned long)idx+1,tn];
        [picker addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
            [weakSelf zn68_presentStructFieldConfigForCandidate:candidate argumentIndex:idx source:source];
        }]];
    }
    [picker addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *top=ZNM52XTop(self.hostWindow);
    if(!top)return;
    UIPopoverPresentationController *popover=picker.popoverPresentationController;
    if(popover){popover.sourceView=source;popover.sourceRect=source.bounds;popover.permittedArrowDirections=UIPopoverArrowDirectionAny;}
    [top presentViewController:picker animated:YES completion:nil];
}

- (void)zn68_presentStructFieldConfigForCandidate:(NSDictionary *)candidate
                                     argumentIndex:(NSUInteger)argumentIndex
                                            source:(UIButton *)source {
    (void)source;
    NSString *method=ZNM52XString(candidate[@"method"]);
    NSDictionary *abi=ZNIL2CPPDescribeMethodABI(candidate);
    NSArray *params=[abi[@"parameters"] isKindOfClass:NSArray.class]?abi[@"parameters"]:@[];
    NSDictionary *param=argumentIndex<params.count?params[argumentIndex]:@{};
    NSString *pn=[param[@"paramName"] isKindOfClass:NSString.class]?param[@"paramName"]:@"";
    NSString *tn=[param[@"name"] isKindOfClass:NSString.class]?param[@"name"]:@"complex value";
    NSString *codecKey=ZNComplexStructCodecKeyForManagedType(tn);
    NSString *codecDisplay=[codecKey isEqualToString:ZNComplexStructCodecObscuredInt]?@"ObscuredInt Codec":
                           ([codecKey isEqualToString:ZNComplexStructCodecSecureLongWholeAccessor]?@"SecureLong Codec":@"Unsupported");
    NSString *codecError=nil;
    NSDictionary *resolvedCodec=codecKey.length?[[ZNComplexStructCodecResolver sharedResolver] resolveManagedType:tn error:&codecError]:nil;
    NSString *diag=[[ZNNativeHookRuntime sharedRuntime] diagnosticsForCandidate:candidate];
    NSString *message=[NSString stringWithFormat:@"目标：%@::%@/%@\n参数：%lu%@ · %@\n模式：whole struct decode → transform → encode\nCodec：%@\n状态：%@\nField Offset：不需要\n\n%@",
                       ZNM52XString(candidate[@"class"]),method,candidate[@"argumentCount"]?:@0,
                       (unsigned long)argumentIndex+1,pn.length?[NSString stringWithFormat:@" · %@",pn]:@"",tn,
                       codecDisplay,resolvedCodec?@"ready":(codecError?:@"unsupported"),diag?:@""];

    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Complex Struct Transform 测试"
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){
        field.placeholder=@"测试倍率，例如 5";
        field.text=@"5";
        field.keyboardType=UIKeyboardTypeNumberPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){
        field.placeholder=@"创建后的 Slider Max，例如 20";
        field.text=@"20";
        field.keyboardType=UIKeyboardTypeNumberPad;
    }];

    __weak typeof(self) weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:@"安装 / 更新测试 Hook" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
        NSInteger multiplier=MAX(1,alert.textFields[0].text.integerValue);
        NSString *error=nil;
        BOOL ok=[[ZNNativeHookRuntime sharedRuntime] installTemporaryComplexStructTransformForCandidate:candidate
                                                                                         argumentIndex:argumentIndex
                                                                                          codecAssembly:@""
                                                                                         codecNamespace:@""
                                                                                             codecClass:@""
                                                                                          getterMethod:@""
                                                                                          setterMethod:@""
                                                                                            multiplier:multiplier
                                                                                                 error:&error];
        [weakSelf zn60v3_setStatus:ok
            ? [NSString stringWithFormat:@"ComplexStructTransform 已安装 · %@ · %@ arg%lu ×%ld",
               codecDisplay,method,(unsigned long)argumentIndex+1,(long)multiplier]
            : (error?:@"ComplexStructTransform 安装失败")];
        [weakSelf renderPage];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"恢复原方法" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a){
        NSString *error=nil;
        BOOL ok=[[ZNNativeHookRuntime sharedRuntime] removeTemporaryHookForCandidate:candidate error:&error];
        [weakSelf zn60v3_setStatus:ok?@"ComplexStructTransform 已移除，目标已恢复":(error?:@"恢复原方法失败")];
        [weakSelf renderPage];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"创建 Hook 方法" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
        NSInteger multiplier=MAX(1,alert.textFields[0].text.integerValue);
        NSInteger maxValue=MAX(multiplier,alert.textFields[1].text.integerValue);
        maxValue=MIN(MAX(maxValue,1),1000);
        NSString *error=nil;
        NSString *title=[NSString stringWithFormat:@"%@ Struct Multiplier",method.length?method:@"Native Hook"];
        ZNNativeHookAction *created=[[ZNNativeHookStore sharedStore] addComplexStructTransformCandidate:candidate
                                                                                                 title:title
                                                                                         argumentIndex:argumentIndex
                                                                                          codecAssembly:@""
                                                                                         codecNamespace:@""
                                                                                             codecClass:@""
                                                                                          getterMethod:@""
                                                                                          setterMethod:@""
                                                                                                   min:1
                                                                                                   max:maxValue
                                                                                          defaultValue:1
                                                                                                 error:&error];
        [weakSelf zn60v3_setStatus:created
            ? [NSString stringWithFormat:@"已创建 ComplexStructTransform：%@ · %@ · Slider 1~%ld",
               created.title,codecDisplay,(long)maxValue]
            : (error?:@"创建 ComplexStructTransform 失败")];
        if(created)[weakSelf znm660_chooseHookControlForAction:created source:weakSelf.contentView];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *top=ZNM52XTop(self.hostWindow);
    if(top)[top presentViewController:alert animated:YES completion:nil];
}

- (void)zn52x_renderResultsAtWidth:(CGFloat)width {
    [self znm65_stopLiveHookStatusTimer];
    // M6.13.1: this method is the sole Result Card renderer.
    // Do NOT call the pre-swizzle renderer and then append views.
    NSArray<NSDictionary *> *all=[self zn60v3_candidates]?:@[];
    NSArray<NSDictionary *> *visible=ZNM52XVisible(self);

    NSMutableSet<NSNumber *> *aritySet=[NSMutableSet set];
    for(NSDictionary *candidate in all){
        if([candidate[@"argumentCount"] respondsToSelector:@selector(integerValue)])
            [aritySet addObject:@([candidate[@"argumentCount"] integerValue])];
    }
    NSArray<NSNumber *> *arities=[[aritySet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    NSInteger filter=[self znm42_filter];
    if(filter>=0&&![aritySet containsObject:@(filter)]){
        filter=-1;
        [self znm42_setFilter:-1];
        visible=ZNM52XVisible(self);
    }

    CGFloat y=9.0;
    UIView *header=[self cardAtY:y height:48 width:width compact:NO];
    UIButton *back=[self zn60v3_plainButton:@"‹ 搜索" selector:@selector(zn60v3_backToSearch:) frame:CGRectMake(10,8,70,31)];
    [header addSubview:back];
    NSString *countText=filter<0
        ? [NSString stringWithFormat:@"搜索结果（%lu）",(unsigned long)all.count]
        : [NSString stringWithFormat:@"搜索结果（%lu/%lu）",(unsigned long)visible.count,(unsigned long)all.count];
    UILabel *title=[self label:countText size:11.8 weight:UIFontWeightSemibold color:self.theme.primaryTextColor];
    title.frame=CGRectMake(88,8,header.bounds.size.width-100,31);
    [header addSubview:title];
    [self.contentView addSubview:header];
    y+=56.0;

    UIView *filterCard=[self cardAtY:y height:44 width:width compact:NO];
    UIScrollView *filterScroll=[[UIScrollView alloc]initWithFrame:CGRectMake(10,5,filterCard.bounds.size.width-20,34)];
    filterScroll.showsHorizontalScrollIndicator=NO;
    CGFloat bx=0.0;
    NSMutableArray<NSNumber *> *filterValues=[NSMutableArray arrayWithObject:@(-1)];
    [filterValues addObjectsFromArray:arities];
    for(NSNumber *number in filterValues){
        NSInteger value=number.integerValue;
        CGFloat bw=value<0?54.0:38.0;
        UIButton *button=[self zn40_button:(value<0?@"全部":number.stringValue)
                                  selector:@selector(znm54_filterTapped:)
                                     frame:CGRectMake(bx,2,bw,30)];
        objc_setAssociatedObject(button,kZNM54FilterKey,number,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        BOOL selected=(filter==value);
        button.backgroundColor=selected?[self.theme.accentColor colorWithAlphaComponent:0.26]:self.theme.controlColor;
        button.layer.borderColor=(selected?self.theme.accentColor:self.theme.borderColor).CGColor;
        [filterScroll addSubview:button];
        bx+=bw+7.0;
    }
    filterScroll.contentSize=CGSizeMake(MAX(filterScroll.bounds.size.width+1,bx),34);
    [filterCard addSubview:filterScroll];
    [self.contentView addSubview:filterCard];
    y+=52.0;

    NSString *liveHookText=[[ZNNativeHookRuntime sharedRuntime] liveTestStatus];
    NSString *pageStatus=liveHookText.length?liveHookText:[self zn60v3_status];
    if(pageStatus.length){
        BOOL live=liveHookText.length>0;
        CGFloat statusH=live?88.0:48.0;
        UIView *statusCard=[self cardAtY:y height:statusH width:width compact:NO];
        UILabel *status=[self label:pageStatus size:(live?8.0:8.1) weight:UIFontWeightRegular
                             color:(live?self.theme.primaryTextColor:self.theme.secondaryTextColor)];
        status.tag=kZNM65LiveHookStatusTag;
        status.frame=CGRectMake(13,6,statusCard.bounds.size.width-26,statusH-12);
        status.numberOfLines=live?6:2;
        if(live)status.font=[UIFont monospacedSystemFontOfSize:7.9 weight:UIFontWeightRegular];
        [statusCard addSubview:status];
        [self.contentView addSubview:statusCard];
        y+=statusH+8.0;
    }
    [self znm65_startLiveHookStatusTimer];

    for(NSUInteger row=0;row<visible.count;row++){
        NSDictionary *candidate=visible[row];
        NSDictionary *analysis=ZNM613AnalyzeCandidate(candidate);
        NSArray<NSDictionary *> *params=[analysis[@"params"] isKindOfClass:NSArray.class]?analysis[@"params"]:@[];
        NSUInteger argc=[candidate[@"argumentCount"] unsignedIntegerValue];
        BOOL runtimeOK=[analysis[@"runtimeOK"] boolValue];
        BOOL directOK=[analysis[@"directOK"] boolValue];
        NSString *directReason=[analysis[@"directReason"] isKindOfClass:NSString.class]?analysis[@"directReason"]:@"";
        NSDictionary *hookPlan=[analysis[@"hookPlan"] isKindOfClass:NSDictionary.class]?analysis[@"hookPlan"]:@{};
        BOOL hookOK=[analysis[@"hookOK"] boolValue];
        NSString *hookError=[analysis[@"hookError"] isKindOfClass:NSString.class]?analysis[@"hookError"]:@"";
        BOOL known=[analysis[@"instanceKnown"] boolValue];
        BOOL instance=[analysis[@"instance"] boolValue];
        BOOL canCapture=[analysis[@"canCapture"] boolValue];

        const CGFloat railW=190.0;
        const CGFloat railGap=6.0;
        const CGFloat rightInset=10.0;
        const CGFloat topAreaH=140.0;
        CGFloat paramH=argc?22.0+(CGFloat)argc*62.0:0.0;
        CGFloat statusBlockH=52.0;
        CGFloat cardH=topAreaH+paramH+statusBlockH+8.0;
        UIView *card=[self cardAtY:y height:cardH width:width compact:NO];
        objc_setAssociatedObject(card,kZNM613AnalysisKey,analysis,OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        CGFloat leftW=MAX(120.0,CGRectGetWidth(card.bounds)-railW-rightInset-23.0);
        UIButton *detail=[UIButton buttonWithType:UIButtonTypeCustom];
        detail.frame=CGRectMake(0,0,leftW+12.0,topAreaH-6.0);
        objc_setAssociatedObject(detail,kZNM54CandidateKey,candidate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [detail addTarget:self action:@selector(znm54_openDetail:) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:detail];

        NSString *method=ZNM52XString(candidate[@"method"]);
        UILabel *name=[self label:[NSString stringWithFormat:@"%@/%lu",method.length?method:@"Method",(unsigned long)argc]
                              size:10.8 weight:UIFontWeightSemibold color:self.theme.primaryTextColor];
        name.frame=CGRectMake(13,8,leftW-8,20);
        name.adjustsFontSizeToFitWidth=YES;
        name.minimumScaleFactor=.65;
        [card addSubview:name];

        UILabel *owner=[self label:ZNM52XString(candidate[@"class"]) size:8.7 weight:UIFontWeightRegular color:self.theme.secondaryTextColor];
        owner.frame=CGRectMake(13,32,leftW-8,17);
        owner.lineBreakMode=NSLineBreakByTruncatingMiddle;
        [card addSubview:owner];

        NSString *assembly=ZNM54AssemblyDisplay(ZNM52XString(candidate[@"assembly"]));
        UILabel *asmLabel=[self label:assembly size:8.0 weight:UIFontWeightRegular color:self.theme.secondaryTextColor];
        asmLabel.frame=CGRectMake(13,52,leftW-8,16);
        asmLabel.lineBreakMode=NSLineBreakByTruncatingTail;
        [card addSubview:asmLabel];

        UILabel *address=[self label:[NSString stringWithFormat:@"RVA %@ · %@",candidate[@"rvaText"]?:@"—",candidate[@"pointerKind"]?:@"?"]
                                  size:7.6 weight:UIFontWeightRegular color:self.theme.secondaryTextColor];
        address.frame=CGRectMake(13,72,leftW-8,16);
        address.lineBreakMode=NSLineBreakByTruncatingMiddle;
        [card addSubview:address];

        NSString *mode=ZNM613ModeForCandidate(self,candidate);
        UILabel *modeLabel=[self label:[NSString stringWithFormat:@"当前模式：%@",[mode isEqualToString:@"direct"]?@"Direct Native Call":([mode isEqualToString:@"hook"]?@"Native Hook":@"Runtime Method")]
                                    size:7.8 weight:UIFontWeightSemibold color:self.theme.accentColor];
        modeLabel.frame=CGRectMake(13,96,leftW-8,18);
        [card addSubview:modeLabel];

        CGFloat colW=(railW-railGap)/2.0;
        CGFloat x0=CGRectGetWidth(card.bounds)-rightInset-railW;
        CGFloat x1=x0+colW+railGap;

        UIButton *test=[self zn40_button:(canCapture?@"测试/捕获":@"测试执行")
                                selector:@selector(znm613_testRuntime:)
                                   frame:CGRectMake(x0,7,colW,27)];
        objc_setAssociatedObject(test,ZNNativeHookCandidateAssociationKey,candidate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        test.enabled=runtimeOK||canCapture;
        test.alpha=test.enabled?1.0:.48;
        [card addSubview:test];
        if(canCapture){
            UILongPressGestureRecognizer *capture=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(znm613_captureLongPress:)];
            capture.minimumPressDuration=.65;
            capture.cancelsTouchesInView=YES;
            objc_setAssociatedObject(capture,kZNM47CaptureCandidateKey,candidate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [test addGestureRecognizer:capture];
        }

        NSString *diag=[[ZNNativeHookRuntime sharedRuntime] diagnosticsForCandidate:candidate]?:@"";
        BOOL installed=[diag containsString:@"已安装"];
        UIButton *apply=[self zn40_button:(installed?@"恢复 Hook":@"应用 Hook")
                                 selector:@selector(znm613_applyOrRestoreHook:)
                                    frame:CGRectMake(x1,7,colW,27)];
        objc_setAssociatedObject(apply,ZNNativeHookCandidateAssociationKey,candidate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        apply.enabled=installed||hookOK;
        apply.alpha=apply.enabled?1.0:.48;
        [card addSubview:apply];

        UIButton *create=[self zn40_button:@"创建方法"
                                  selector:@selector(znm613_createCurrentMode:)
                                     frame:CGRectMake(x0,39,colW,27)];
        objc_setAssociatedObject(create,ZNNativeHookCandidateAssociationKey,candidate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [card addSubview:create];

        ZNRuntimeMethodAction *chainAction=nil;
        NSInteger chainIndex=ZNM52XFindChain(candidate,&chainAction);
        UIButton *chain=[self zn40_button:(chainAction?@"执行链":@"链式调用")
                                 selector:(chainAction?@selector(zn52x_executeChainTapped:):@selector(znm613_chainTapped:))
                                    frame:CGRectMake(x1,39,colW,27)];
        if(chainAction){
            objc_setAssociatedObject(chain,kZNM52XActionKey,chainAction,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(chain,kZNM52XIndexKey,@(chainIndex),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            UILongPressGestureRecognizer *restart=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(zn52x_restartChainLongPress:)];
            restart.minimumPressDuration=.65;
            [chain addGestureRecognizer:restart];
        }else{
            objc_setAssociatedObject(chain,kZN51CandidateKey,candidate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [card addSubview:chain];

        UIButton *reselect=[self zn40_button:@"重新选择实例"
                                    selector:@selector(zn52x_reselectInstance:)
                                       frame:CGRectMake(x0,71,colW,27)];
        objc_setAssociatedObject(reselect,kZNM52XCandidateKey,candidate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        reselect.enabled=known&&instance;
        reselect.alpha=reselect.enabled?1.0:.48;
        [card addSubview:reselect];

        UIButton *batch=[self zn40_button:@"批量测试实例"
                                 selector:@selector(zn52x_batchTestInstances:)
                                    frame:CGRectMake(x1,71,colW,27)];
        objc_setAssociatedObject(batch,kZNM52XCandidateKey,candidate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        batch.enabled=known&&instance&&ZNM52XBatchSafe(candidate);
        batch.alpha=batch.enabled?1.0:.48;
        [card addSubview:batch];

        UIButton *direct=[self zn40_button:@"Native Call"
                                  selector:@selector(zn52x_directUnavailable:)
                                     frame:CGRectMake(x0,103,colW,27)];
        objc_setAssociatedObject(direct,ZNNativeHookCandidateAssociationKey,candidate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        direct.accessibilityHint=directOK?@"Direct Native Call ABI supported":(directReason?:@"Direct Native Call unsupported");
        [card addSubview:direct];

        UIButton *hook=[self zn40_button:@"Native Hook"
                                selector:@selector(zn64_hookTestTapped:)
                                   frame:CGRectMake(x1,103,colW,27)];
        objc_setAssociatedObject(hook,ZNNativeHookCandidateAssociationKey,candidate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        hook.accessibilityHint=hookOK?@"Native Hook plan ready":(hookError?:@"Native Hook unsupported");
        [card addSubview:hook];

        for(UIButton *b in @[test,apply,create,chain,reselect,batch,direct,hook])
            ZNM52XStyleGridButton(b,b.frame.origin.x,b.frame.origin.y,b.frame.size.width,b.frame.size.height);

        ZNM613ApplyModeVisual(self,card,candidate,mode);

        CGFloat py=topAreaH;
        if(argc){
            UILabel *paramHeader=[self label:@"参数" size:8.9 weight:UIFontWeightSemibold color:self.theme.secondaryTextColor];
            paramHeader.frame=CGRectMake(13,py,width-26,18);
            [card addSubview:paramHeader];
            py+=22.0;
        }

        NSMutableDictionary *argStore=ZNM613ArgumentStore(self);
        for(NSUInteger arg=0;arg<argc;arg++){
            NSDictionary *p=arg<params.count?params[arg]:@{};
            NSString *type=[p[@"name"] isKindOfClass:NSString.class]?p[@"name"]:@"?";
            UILabel *pl=[self label:[NSString stringWithFormat:@"参数 %lu  %@",(unsigned long)arg+1,type]
                                size:7.9 weight:UIFontWeightRegular color:self.theme.primaryTextColor];
            pl.frame=CGRectMake(13,py,width-26,16);
            pl.lineBreakMode=NSLineBreakByTruncatingMiddle;
            [card addSubview:pl];
            py+=17.0;

            UITextField *field=ZNM54Field(CGRectMake(13,py,width-26,25),self.theme,[UIFont monospacedDigitSystemFontOfSize:8.7 weight:UIFontWeightMedium]);
            NSString *storeKey=ZNM613ArgumentStoreKey(candidate,arg);
            field.text=[argStore[storeKey] isKindOfClass:NSString.class]?argStore[storeKey]:@"";
            field.placeholder=type;
            field.keyboardType=UIKeyboardTypeNumbersAndPunctuation;
            field.returnKeyType=UIReturnKeyDone;
            objc_setAssociatedObject(field,kZNM613ArgCandidateKey,candidate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(field,kZNM613ArgIndexKey,@(arg),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [field addTarget:self action:@selector(znm613_argumentChanged:) forControlEvents:UIControlEventEditingChanged|UIControlEventEditingDidEnd];
            [field addTarget:self action:@selector(znm613_argumentDone:) forControlEvents:UIControlEventEditingDidEndOnExit];
            [card addSubview:field];
            py+=27.0;

            UILabel *autoLabel=[self label:[@"自动识别：" stringByAppendingString:ZNM613ParamAutoLabel(p)]
                                      size:7.4 weight:UIFontWeightRegular color:self.theme.secondaryTextColor];
            autoLabel.frame=CGRectMake(13,py,width-26,14);
            [card addSubview:autoLabel];
            py+=18.0;
        }

        NSString *hookSummary=hookOK
            ? [NSString stringWithFormat:@"ready · %@",hookPlan[@"kind"]?:@"plan"]
            : (hookError?:@"unsupported");
        NSString *directSummary=directOK?@"ABI supported":(directReason?:@"unsupported");
        UILabel *statusLabel=[self label:[NSString stringWithFormat:@"状态  Native Hook：%@\nDirect Call：%@",hookSummary,directSummary]
                                    size:7.5 weight:UIFontWeightRegular color:self.theme.secondaryTextColor];
        statusLabel.frame=CGRectMake(13,py+3,width-26,40);
        statusLabel.numberOfLines=2;
        [card addSubview:statusLabel];

        [self.contentView addSubview:card];
        y+=cardH+8.0;
    }

    [self zn40_updateContentHeight:y];
}

- (void)zn52x_executeChainTapped:(UIButton *)sender {
    ZNRuntimeMethodAction *action = objc_getAssociatedObject(sender, kZNM52XActionKey);
    if (!action) return;
    NSString *error = nil;
    NSDictionary *result = [[ZNIL2CPPInvokeEngine sharedEngine] executeAction:action error:&error];
    if (!result) {
        NSString *message = error.length ? error : @"未知错误";
        [self zn60v3_setStatus:[NSString stringWithFormat:@"执行链失败：%@", message]];
        UIViewController *top = ZNM52XTop(self.hostWindow);
        if (top) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"执行链失败" message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [top presentViewController:alert animated:YES completion:nil];
        }
        [self renderPage];
        return;
    }
    NSString *type = ZNM52XString(result[@"returnType"]);
    NSString *value = [result[@"returnValue"] description] ?: @"?";
    NSString *trace = ZNM52XTrace(result);
    [self zn60v3_setStatus:[NSString stringWithFormat:@"执行链成功 · %@ = %@", type.length ? type : @"return", value]];
    [[ZNRuntimeLogger sharedLogger] log:[NSString stringWithFormat:@"[m5.2-chain-ui] %@ = %@\n%@", type.length ? type : @"return", value, trace ?: @""]];
    UIViewController *top = ZNM52XTop(self.hostWindow);
    if (top) {
        NSString *message = trace.length ? [NSString stringWithFormat:@"最终返回：%@ = %@\n\n%@", type.length ? type : @"return", value, trace] : [NSString stringWithFormat:@"最终返回：%@ = %@", type.length ? type : @"return", value];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"执行链结果" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [top presentViewController:alert animated:YES completion:nil];
    }
    [self renderPage];
}

- (void)znm613_argumentChanged:(UITextField *)field {
    NSDictionary *candidate=objc_getAssociatedObject(field,kZNM613ArgCandidateKey);
    NSNumber *index=objc_getAssociatedObject(field,kZNM613ArgIndexKey);
    if(!candidate||!index)return;
    ZNM613ArgumentStore(self)[ZNM613ArgumentStoreKey(candidate,index.unsignedIntegerValue)]=field.text?:@"";
    if(field.editing==NO)[field resignFirstResponder];
}

- (void)znm613_argumentDone:(UITextField *)field {
    [self znm613_argumentChanged:field];
    [field resignFirstResponder];
}

- (void)znm613_selectRuntimeMode:(UIButton *)sender {
    ZNM613SetModeForCard(self,sender.superview,objc_getAssociatedObject(sender,ZNNativeHookCandidateAssociationKey),@"runtime");
}

- (void)znm613_testRuntime:(UIButton *)sender {
    NSDictionary *candidate=objc_getAssociatedObject(sender,ZNNativeHookCandidateAssociationKey);
    if(!candidate)return;
    ZNM613SetModeForCard(self,sender.superview,candidate,@"runtime");

    BOOL runtimeOK=[ZNM613AnalyzeCandidate(candidate)[@"runtimeOK"] boolValue];
    if(!runtimeOK){
        [self zn60v3_setStatus:@"Runtime Method：当前 ABI 不支持直接执行；实例方法可长按“测试/捕获”捕获 receiver"];
        [self renderPage];
        return;
    }

    NSUInteger argc=[candidate[@"argumentCount"] unsignedIntegerValue];
    NSArray<NSString *> *values=ZNM613ArgumentValues(self,candidate);
    if(values.count!=argc){
        [self zn60v3_setStatus:@"Runtime Method：参数数量不匹配"];
        [self renderPage];
        return;
    }
    NSString *error=nil;
    NSDictionary *result=[[ZNIL2CPPInvokeEngine sharedEngine]
        executeAssembly:([candidate[@"assembly"] isKindOfClass:NSString.class]?candidate[@"assembly"]:@"Assembly-CSharp.dll")
              namespace:([candidate[@"namespace"] isKindOfClass:NSString.class]?candidate[@"namespace"]:@"")
              className:([candidate[@"class"] isKindOfClass:NSString.class]?candidate[@"class"]:@"")
                 method:([candidate[@"method"] isKindOfClass:NSString.class]?candidate[@"method"]:@"")
          argumentCount:argc
         argumentValues:values
                  error:&error];
    [self zn60v3_setStatus:result
        ? [NSString stringWithFormat:@"Runtime Invoke SUCCESS：%@ args=%@",ZNM52XString(candidate[@"method"]),values]
        : (error?:@"Runtime Invoke FAILED")];
    [self renderPage];
}

- (void)znm613_chainTapped:(UIButton *)sender {
    NSDictionary *candidate=objc_getAssociatedObject(sender,kZN51CandidateKey);
    if(!candidate){
        [self zn60v3_setStatus:@"链式调用：candidate 绑定丢失"];
        [self renderPage];
        return;
    }

    NSDictionary *analysis=ZNM613AnalyzeCandidate(candidate);
    NSDictionary *abi=[analysis[@"abi"] isKindOfClass:NSDictionary.class]?analysis[@"abi"]:@{};
    NSDictionary *ret=[abi[@"return"] isKindOfClass:NSDictionary.class]?abi[@"return"]:@{};
    NSString *returnType=[ret[@"name"] isKindOfClass:NSString.class]?ret[@"name"]:@"";
    if((ZNIL2CPPABIValueKind)[ret[@"kind"] integerValue]!=ZNIL2CPPABIValueKindObjectReference){
        [self zn60v3_setStatus:[NSString stringWithFormat:@"链式调用需要 managed-reference 返回值；当前=%@",returnType.length?returnType:@"?"]];
        [self renderPage];
        return;
    }

    NSString *targetNS=@"";
    NSString *targetClass=returnType;
    NSRange dot=[returnType rangeOfString:@"." options:NSBackwardsSearch];
    if(dot.location!=NSNotFound){
        targetNS=[returnType substringToIndex:dot.location];
        targetClass=[returnType substringFromIndex:dot.location+1];
    }

    UIViewController *top=ZNM52XTop(self.hostWindow);
    if(!top){
        [self zn60v3_setStatus:@"链式调用：找不到可展示配置页的 UIViewController"];
        [self renderPage];
        return;
    }

    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"返回对象 → 立即调用方法"
        message:[NSString stringWithFormat:@"%@::%@/%@\n返回类型：%@\n链式目标 V1 使用 argc=0。",
                 candidate[@"class"]?:@"?",candidate[@"method"]?:@"?",candidate[@"argumentCount"]?:@0,
                 returnType.length?returnType:@"?"]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.placeholder=@"Namespace（可空）";field.text=targetNS;}];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.placeholder=@"Class";field.text=targetClass;}];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.placeholder=@"Method";field.text=@"ToString";}];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    __weak typeof(self) weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:@"创建链式方法" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){
        __strong typeof(weakSelf) selfRef=weakSelf;
        if(!selfRef)return;
        NSString *ns=alert.textFields.count>0?alert.textFields[0].text:@"";
        NSString *cls=alert.textFields.count>1?alert.textFields[1].text:@"";
        NSString *method=alert.textFields.count>2?alert.textFields[2].text:@"";
        if(!cls.length||!method.length){
            [selfRef zn60v3_setStatus:@"链式 Class/Method 不能为空"];
            [selfRef renderPage];
            return;
        }

        NSArray<NSString *> *values=ZNM613ArgumentValues(selfRef,candidate);
        NSString *error=nil;
        ZNRuntimeMethodAction *created=[[ZNRuntimeActionStore sharedStore] addMethodCandidate:candidate
                                                                                       title:candidate[@"method"]
                                                                              argumentValues:values
                                                                                       error:&error];
        if(!created){
            [selfRef zn60v3_setStatus:error?:@"创建主 Runtime Method 失败"];
            [selfRef renderPage];
            return;
        }

        NSArray<ZNRuntimeMethodAction *> *actions=[[ZNRuntimeActionStore sharedStore] actionsSnapshot];
        NSUInteger index=NSNotFound;
        for(NSUInteger i=0;i<actions.count;i++){
            if(actions[i].actionID==created.actionID){index=i;break;}
        }
        NSDictionary *chain=@{@"assembly":candidate[@"assembly"]?:@"Assembly-CSharp.dll",
                              @"namespace":ns?:@"",
                              @"class":cls,
                              @"method":method,
                              @"argumentCount":@0,
                              @"argumentValues":@[]};
        if(index==NSNotFound||![[ZNRuntimeActionStore sharedStore] updateImmediateChain:chain atIndex:index error:&error]){
            [selfRef zn60v3_setStatus:error?:@"保存 Immediate Chain 失败"];
            [selfRef renderPage];
            return;
        }
        [selfRef zn60v3_setStatus:[NSString stringWithFormat:@"已创建链式方法：%@ → %@::%@/0",created.canonicalIdentity,cls,method]];
        [selfRef renderPage];
    }]];

    [top presentViewController:alert animated:YES completion:nil];
}

- (void)znm613_captureLongPress:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state!=UIGestureRecognizerStateBegan)return;
    NSDictionary *candidate=objc_getAssociatedObject(gesture,kZNM47CaptureCandidateKey);
    if(!candidate)return;

    NSDictionary *analysis=ZNM613AnalyzeCandidate(candidate);
    if(![analysis[@"canCapture"] boolValue]){
        [self zn60v3_setStatus:@"Receiver Capture：当前方法不是可捕获的实例方法"];
        [self renderPage];
        return;
    }
    if(ZNM47ReceiverCaptureBusy()){
        [self zn60v3_setStatus:@"Receiver Capture：已有捕获任务运行中"];
        [self renderPage];
        return;
    }

    NSString *assembly=[candidate[@"assembly"] isKindOfClass:NSString.class]?candidate[@"assembly"]:@"Assembly-CSharp.dll";
    NSString *namespaceName=[candidate[@"namespace"] isKindOfClass:NSString.class]?candidate[@"namespace"]:@"";
    NSString *className=[candidate[@"class"] isKindOfClass:NSString.class]?candidate[@"class"]:@"";
    NSString *methodName=[candidate[@"method"] isKindOfClass:NSString.class]?candidate[@"method"]:@"Method";

    __weak typeof(self) weakSelf=self;
    NSString *startError=nil;
    BOOL started=ZNM47StartReceiverCapture(candidate,5.0,^(uintptr_t receiver,NSString *captureError){
        __strong typeof(weakSelf) strong=weakSelf;
        if(!strong)return;
        if(!receiver){
            [strong zn60v3_setStatus:captureError?:@"Receiver Capture：未捕获到实例"];
            [strong renderPage];
            return;
        }

        ZNIL2CPPInstanceResolver *resolver=[ZNIL2CPPInstanceResolver sharedResolver];
        NSString *validationError=nil;
        if(![resolver znm44_validateInstanceAddress:receiver
                                           assembly:assembly
                                          namespace:namespaceName
                                          className:className
                                              error:&validationError]){
            [strong zn60v3_setStatus:[NSString stringWithFormat:@"捕获到 x0=0x%llX，但类型验证失败：%@",
                                      (unsigned long long)receiver,validationError?:@"unknown"]];
            [strong renderPage];
            return;
        }

        NSString *selectionError=nil;
        if(![resolver znm44_selectInstanceAddress:receiver
                                         assembly:assembly
                                        namespace:namespaceName
                                        className:className
                                            error:&selectionError]){
            [strong zn60v3_setStatus:selectionError?:@"Receiver Capture：保存 receiver 失败"];
            [strong renderPage];
            return;
        }

        [strong zn60v3_setStatus:[NSString stringWithFormat:@"Receiver Capture 成功：%@.%@ receiver=0x%llX",
                                  className.length?className:@"?",methodName,(unsigned long long)receiver]];
        [strong renderPage];
    },&startError);

    if(!started){
        [self zn60v3_setStatus:startError?:@"Receiver Capture 启动失败"];
        [self renderPage];
        return;
    }
    [self zn60v3_setStatus:[NSString stringWithFormat:@"Receiver Capture 中（5 秒）：请在游戏里触发 %@.%@",className.length?className:@"?",methodName]];
    [self renderPage];
}
- (void)znm613_createCurrentMode:(UIButton *)sender {
    NSDictionary *candidate=objc_getAssociatedObject(sender,ZNNativeHookCandidateAssociationKey);
    if(!candidate)return;
    NSString *mode=objc_getAssociatedObject(sender,kZNM613CreateModeKey)?:@"runtime";
    NSArray<NSString *> *values=ZNM613ArgumentValues(self,candidate);
    NSUInteger argc=[candidate[@"argumentCount"] unsignedIntegerValue];
    while(values.count<argc){
        NSMutableArray *m=[values mutableCopy];[m addObject:@""];values=[m copy];
    }
    NSString *error=nil;
    if([mode isEqualToString:@"direct"]){
        NSString *why=nil;
        if(![[ZNDirectNativeCallEngine sharedEngine] supportsCandidate:candidate reason:&why]){
            [self zn60v3_setStatus:why?:@"Direct Native Call ABI 不支持"];return;
        }
        ZNRuntimeMethodAction *created=[[ZNRuntimeActionStore sharedStore] addDirectNativeCallCandidate:candidate
                                                                                                  title:candidate[@"method"]
                                                                                         argumentValues:values
                                                                                                  error:&error];
        [self zn60v3_setStatus:created?[NSString stringWithFormat:@"已创建 Direct Native Call：%@",created.canonicalIdentity]:(error?:@"创建 Direct Native Call 失败")];
        return;
    }
    if([mode isEqualToString:@"hook"]){
        NSDictionary *plan=ZNM613HookPlan(candidate,&error);
        if(!plan){[self zn60v3_setStatus:error?:@"Native Hook 自动方案不可用"];[self renderPage];return;}
        NSString *kind=plan[@"kind"];
        ZNNativeHookAction *created=nil;
        NSString *title=[NSString stringWithFormat:@"%@ Hook",ZNM52XString(candidate[@"method"])];
        if([kind isEqualToString:@"complex"]){
            NSUInteger idx=[plan[@"index"] unsignedIntegerValue];
            NSInteger v=(idx<values.count)?MAX(1,[values[idx] integerValue]):5;
            NSInteger max=MIN(MAX(v,20),1000);
            created=[[ZNNativeHookStore sharedStore] addComplexStructTransformCandidate:candidate title:title argumentIndex:idx
                                                                          codecAssembly:@"" codecNamespace:@"" codecClass:@""
                                                                           getterMethod:@"" setterMethod:@"" min:1 max:max defaultValue:1 error:&error];
        }else if([kind isEqualToString:@"int32"]){
            NSUInteger idx=[plan[@"index"] unsignedIntegerValue];
            NSInteger v=(idx<values.count)?MAX(1,[values[idx] integerValue]):5;
            created=[[ZNNativeHookStore sharedStore] addArgScaleInt32Candidate:candidate title:title argumentIndex:idx min:1 max:MIN(MAX(v,20),1000) defaultValue:1 error:&error];
        }else if([kind isEqualToString:@"callback"]){
            created=[[ZNNativeHookStore sharedStore] addManagedCallbackShortCircuitCandidate:candidate title:title callbackArgumentIndex:[plan[@"index"] unsignedIntegerValue] callbackValue:YES skipOriginal:YES error:&error];
        }else if([kind isEqualToString:@"return-bool"]){
            created=[[ZNNativeHookStore sharedStore] addReturnBoolOverrideCandidate:candidate title:title value:YES error:&error];
        }
        [self zn60v3_setStatus:created?[NSString stringWithFormat:@"已创建 Native Hook：%@",created.canonicalIdentity]:(error?:@"创建 Native Hook 失败")];
        if(created)[self znm660_chooseHookControlForAction:created source:sender];

        return;
    }

    ZNRuntimeMethodAction *created=[[ZNRuntimeActionStore sharedStore] addMethodCandidate:candidate
                                                                                    title:candidate[@"method"]
                                                                           argumentValues:values
                                                                                    error:&error];
    [self zn60v3_setStatus:created?[NSString stringWithFormat:@"已创建 Runtime Method：%@",created.canonicalIdentity]:(error?:@"创建 Runtime Method 失败")];
}

- (void)znm613_applyOrRestoreHook:(UIButton *)sender {
    NSDictionary *candidate=objc_getAssociatedObject(sender,ZNNativeHookCandidateAssociationKey);
    if(!candidate)return;
    NSString *diag=[[ZNNativeHookRuntime sharedRuntime] diagnosticsForCandidate:candidate]?:@"";
    if([diag containsString:@"已安装"]){
        NSString *error=nil;
        BOOL ok=[[ZNNativeHookRuntime sharedRuntime] removeTemporaryHookForCandidate:candidate error:&error];
        [self zn60v3_setStatus:ok?@"Native Hook 已恢复原方法":(error?:@"恢复 Hook 失败")];
        [self renderPage];
        return;
    }

    NSString *error=nil;NSDictionary *plan=ZNM613HookPlan(candidate,&error);
    if(!plan){[self zn60v3_setStatus:error?:@"Native Hook 自动方案不可用"];return;}
    NSArray<NSString *> *values=ZNM613ArgumentValues(self,candidate);
    NSString *kind=plan[@"kind"];
    BOOL ok=NO;
    if([kind isEqualToString:@"complex"]){
        NSUInteger idx=[plan[@"index"] unsignedIntegerValue];
        NSInteger multiplier=(idx<values.count)?MAX(1,[values[idx] integerValue]):5;
        ok=[[ZNNativeHookRuntime sharedRuntime] installTemporaryComplexStructTransformForCandidate:candidate
                                                                                     argumentIndex:idx
                                                                                      codecAssembly:@""
                                                                                     codecNamespace:@""
                                                                                         codecClass:@""
                                                                                      getterMethod:@""
                                                                                      setterMethod:@""
                                                                                        multiplier:MIN(multiplier,1000)
                                                                                             error:&error];
    }else if([kind isEqualToString:@"int32"]){
        NSUInteger idx=[plan[@"index"] unsignedIntegerValue];
        NSInteger multiplier=(idx<values.count)?MAX(1,[values[idx] integerValue]):5;
        ok=[[ZNNativeHookRuntime sharedRuntime] installTemporaryArgScaleInt32ForCandidate:candidate argumentIndex:idx multiplier:MIN(multiplier,1000) error:&error];
    }else if([kind isEqualToString:@"callback"]){
        ok=[[ZNNativeHookRuntime sharedRuntime] installTemporaryManagedCallbackShortCircuitForCandidate:candidate argumentIndex:[plan[@"index"] unsignedIntegerValue] callbackValue:YES error:&error];
    }else if([kind isEqualToString:@"return-bool"]){
        ok=[[ZNNativeHookRuntime sharedRuntime] installTemporaryReturnBoolOverrideForCandidate:candidate value:YES error:&error];
    }
    [self zn60v3_setStatus:ok?[NSString stringWithFormat:@"Native Hook 已应用 · %@",kind]:(error?:@"应用 Hook 失败")];
    [self renderPage];
}


- (void)zn52x_directUnavailable:(UIButton *)sender {
    NSDictionary *candidate=objc_getAssociatedObject(sender,ZNNativeHookCandidateAssociationKey);
    if(!candidate){[self zn60v3_setStatus:@"Direct Native Call：candidate 为空"];return;}
    NSUInteger argc=[candidate[@"argumentCount"] unsignedIntegerValue];
    NSArray<NSString *> *values=ZNM613ArgumentValues(self,candidate);
    NSDictionary *analysis=ZNM613AnalyzeCandidate(candidate);
    NSString *reason=[analysis[@"directReason"] isKindOfClass:NSString.class]?analysis[@"directReason"]:@"";
    if(![analysis[@"directOK"] boolValue]){
        [self zn60v3_setStatus:reason.length?reason:@"Direct Native Call：当前 ABI 不受支持"];
        [self renderPage];
        return;
    }
    ZNM613SetModeForCard(self,sender.superview,candidate,@"direct");
    if(values.count!=argc){
        [self zn60v3_setStatus:[NSString stringWithFormat:@"Direct Native Call V1：当前结果卡仅支持 /0 或 /1 参数输入；方法需要 /%lu",(unsigned long)argc]];
        return;
    }
    NSString *error=nil;
    id<ZNRuntimeCapabilityAdapter> adapter=[[ZNCapabilityRegistry sharedRegistry] adapterForIdentifier:ZNCapabilityDirectNativeCallIdentifier];
    BOOL ok=[adapter respondsToSelector:@selector(activateItem:value:error:)] &&
            [adapter activateItem:candidate value:values error:&error];
    NSDictionary *result=[ZNDirectNativeCallEngine sharedEngine].lastResult;
    [self zn60v3_setStatus:ok
        ? [NSString stringWithFormat:@"Direct Native Call SUCCESS · %@ = %@",
           result[@"returnType"]?:@"return",result[@"returnValue"]?:@"void"]
        : (error?:@"Direct Native Call FAILED")];
    [self renderPage];
}

- (void)zn64_testModeTapped:(UIButton *)sender {
    NSDictionary *candidate=objc_getAssociatedObject(sender,ZNNativeHookCandidateAssociationKey);
    if(!candidate)return;

    NSString *reason=nil,*callbackReason=nil,*returnReason=nil,*structReason=nil;
    NSArray<NSNumber *> *hookArgs=[[ZNNativeHookRuntime sharedRuntime] supportedInt32ArgumentIndicesForCandidate:candidate reason:&reason];
    NSArray<NSNumber *> *callbackArgs=[[ZNNativeHookRuntime sharedRuntime] supportedManagedBoolCallbackArgumentIndicesForCandidate:candidate reason:&callbackReason];
    BOOL returnBool=[[ZNNativeHookRuntime sharedRuntime] supportsReturnBoolOverrideForCandidate:candidate reason:&returnReason];
    NSArray<NSNumber *> *structArgs=[[ZNNativeHookRuntime sharedRuntime] supportedStructFieldArgumentIndicesForCandidate:candidate reason:&structReason];
    UIAlertController *picker=[UIAlertController alertControllerWithTitle:@"测试方式"
                                                                   message:@"Runtime Call 保持左侧测试/捕获；这里选择 Direct 或 IL2CPP Native Hook"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf=self;
    [picker addAction:[UIAlertAction actionWithTitle:@"Direct Native Call" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
        [weakSelf zn52x_directUnavailable:sender];
    }]];
    UIAlertAction *hook=[UIAlertAction actionWithTitle:@"IL2CPP Native Hook" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
        [weakSelf zn64_hookTestTapped:sender];
    }];
    hook.enabled=(hookArgs.count>0||callbackArgs.count>0||returnBool||structArgs.count>0);
    [picker addAction:hook];
    if(!hook.enabled){
        NSString *detail=structReason.length?structReason:(returnReason.length?returnReason:(callbackReason.length?callbackReason:reason));
        if(detail.length)picker.message=[picker.message stringByAppendingFormat:@"\nNative Hook：%@",detail];
    }
    [picker addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    UIViewController *top=ZNM52XTop(self.hostWindow);
    if(!top)return;
    UIPopoverPresentationController *popover=picker.popoverPresentationController;
    if(popover){popover.sourceView=sender;popover.sourceRect=sender.bounds;popover.permittedArrowDirections=UIPopoverArrowDirectionAny;}
    [top presentViewController:picker animated:YES completion:nil];
}

- (void)zn68_presentManualStructFieldConfigForCandidate:(NSDictionary *)candidate
                                     argumentIndex:(NSUInteger)argumentIndex
                                            source:(UIButton *)source {
    (void)source;
    NSString *method=ZNM52XString(candidate[@"method"]);
    NSDictionary *abi=ZNIL2CPPDescribeMethodABI(candidate);
    NSArray *params=[abi[@"parameters"] isKindOfClass:NSArray.class]?abi[@"parameters"]:@[];
    NSDictionary *param=argumentIndex<params.count?params[argumentIndex]:@{};
    NSString *pn=[param[@"paramName"] isKindOfClass:NSString.class]?param[@"paramName"]:@"";
    NSString *tn=[param[@"name"] isKindOfClass:NSString.class]?param[@"name"]:@"complex value";
    NSString *diag=[[ZNNativeHookRuntime sharedRuntime] diagnosticsForCandidate:candidate];
    NSString *message=[NSString stringWithFormat:@"目标：%@::%@/%@\n参数：%lu%@ · %@\n模式：indirect-pointer\nCodec：SecureLong accessor\nAccessor：get_Value/0 + set_Value/1\n\n%@",
                       ZNM52XString(candidate[@"class"]),method,candidate[@"argumentCount"]?:@0,
                       (unsigned long)argumentIndex+1,pn.length?[NSString stringWithFormat:@" · %@",pn]:@"",tn,diag?:@""];

    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Struct Field Transform 测试"
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){
        field.placeholder=@"Field Offset，例如 0x48";
        field.text=@"0x48";
        field.autocapitalizationType=UITextAutocapitalizationTypeNone;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){
        field.placeholder=@"测试倍率，例如 5";
        field.text=@"5";
        field.keyboardType=UIKeyboardTypeNumberPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){
        field.placeholder=@"创建后的 Slider Max，例如 20";
        field.text=@"20";
        field.keyboardType=UIKeyboardTypeNumberPad;
    }];

    __weak typeof(self) weakSelf=self;
    uint64_t (^parseOffset)(NSString *) = ^uint64_t(NSString *raw){
        NSString *s=[[raw?:@"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
        unsigned long long value=0;
        NSScanner *scanner=[NSScanner scannerWithString:s];
        if([s hasPrefix:@"0x"]){scanner.scanLocation=2;[scanner scanHexLongLong:&value];}
        else [scanner scanUnsignedLongLong:&value];
        return (uint64_t)value;
    };

    [alert addAction:[UIAlertAction actionWithTitle:@"安装 / 更新测试 Hook" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
        uint64_t offset=parseOffset(alert.textFields[0].text);
        NSInteger multiplier=alert.textFields[1].text.integerValue;
        NSString *error=nil;
        BOOL ok=[[ZNNativeHookRuntime sharedRuntime] installTemporaryStructFieldTransformForCandidate:candidate
                                                                                        argumentIndex:argumentIndex
                                                                                         argumentMode:@"indirect-pointer"
                                                                                          fieldOffset:offset
                                                                                           fieldCodec:@"secure-long-accessor"
                                                                                        codecAssembly:@"Percent.Scripting.Stdlib.dll"
                                                                                       codecNamespace:@"Percent.Scripting.Stdlib.SecureValue"
                                                                                           codecClass:@"SecureLong"
                                                                                          getterMethod:@"get_Value"
                                                                                          setterMethod:@"set_Value"
                                                                                           multiplier:multiplier
                                                                                                error:&error];
        [weakSelf zn60v3_setStatus:ok
            ? [NSString stringWithFormat:@"StructFieldTransform 已安装 · %@ arg%lu +0x%llX ×%ld；触发伤害后看实时状态",
               method,(unsigned long)argumentIndex,(unsigned long long)offset,(long)multiplier]
            : (error?:@"StructFieldTransform 安装失败")];
        [weakSelf renderPage];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"恢复原方法" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a){
        NSString *error=nil;
        BOOL ok=[[ZNNativeHookRuntime sharedRuntime] removeTemporaryHookForCandidate:candidate error:&error];
        [weakSelf zn60v3_setStatus:ok?@"StructFieldTransform 已移除，目标已恢复":(error?:@"恢复原方法失败")];
        [weakSelf renderPage];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"创建 Hook 方法" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
        uint64_t offset=parseOffset(alert.textFields[0].text);
        NSInteger multiplier=MAX(1,alert.textFields[1].text.integerValue);
        NSInteger maxValue=MAX(multiplier,alert.textFields[2].text.integerValue);
        maxValue=MIN(MAX(maxValue,1),1000);
        NSString *error=nil;
        NSString *title=[NSString stringWithFormat:@"%@ Field Multiplier",method.length?method:@"Native Hook"];
        ZNNativeHookAction *created=[[ZNNativeHookStore sharedStore] addStructFieldTransformCandidate:candidate
                                                                                              title:title
                                                                                      argumentIndex:argumentIndex
                                                                                       argumentMode:@"indirect-pointer"
                                                                                        fieldOffset:offset
                                                                                         fieldCodec:@"secure-long-accessor"
                                                                                      codecAssembly:@"Percent.Scripting.Stdlib.dll"
                                                                                     codecNamespace:@"Percent.Scripting.Stdlib.SecureValue"
                                                                                         codecClass:@"SecureLong"
                                                                                        getterMethod:@"get_Value"
                                                                                        setterMethod:@"set_Value"
                                                                                              min:1
                                                                                              max:maxValue
                                                                                     defaultValue:1
                                                                                            error:&error];
        [weakSelf zn60v3_setStatus:created
            ? [NSString stringWithFormat:@"已创建 StructFieldTransform：%@ · +0x%llX · Slider 1~%ld",
               created.title,(unsigned long long)offset,(long)maxValue]
            : (error?:@"创建 StructFieldTransform 失败")];
        if(created)[weakSelf znm660_chooseHookControlForAction:created source:weakSelf.contentView];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *top=ZNM52XTop(self.hostWindow);
    if(top)[top presentViewController:alert animated:YES completion:nil];
}


- (void)znm660_chooseHookControlForAction:(ZNNativeHookAction *)action source:(UIView *)source {
    if(!action)return;
    NSArray<ZNNativeHookAction *> *actions=[[ZNNativeHookStore sharedStore] actionsSnapshot];
    NSUInteger actionIndex=NSNotFound;
    for(NSUInteger i=0;i<actions.count;i++)if(actions[i].actionID==action.actionID){actionIndex=i;break;}
    if(actionIndex==NSNotFound){[self zn60v3_setStatus:@"Native Hook Action 未找到"];return;}

    BOOL booleanTemplate=action.templateKind==ZNNativeHookTemplateManagedCallbackShortCircuit||
                         action.templateKind==ZNNativeHookTemplateReturnBoolOverride;
    NSString *selected=action.controlTypeKey.length?action.controlTypeKey:(booleanTemplate?@"switch":@"slider");
    UIAlertController *editor=[UIAlertController alertControllerWithTitle:@"Native Hook 功能配置"
        message:@"统一设置功能名称、说明和客户端控件。Hook ABI、Codec、Field Offset 仅保存在内部配置。"
        preferredStyle:UIAlertControllerStyleAlert];
    [editor addTextFieldWithConfigurationHandler:^(UITextField *field){
        field.placeholder=@"功能名称";
        field.text=action.title.length?action.title:action.methodName;
    }];
    [editor addTextFieldWithConfigurationHandler:^(UITextField *field){
        field.placeholder=@"功能说明（可留空）";
        field.text=action.featureDescription?:@"";
    }];
    __weak typeof(self) weakSelf=self;
    for(NSString *type in (booleanTemplate?@[@"switch",@"button"]:@[@"slider",@"number",@"switch",@"button"])){
        NSString *display=ZNRuntimeArgumentControlTypeName(ZNRuntimeArgumentControlTypeFromKey(type));
        NSString *label=[NSString stringWithFormat:@"%@%@",[type isEqualToString:selected]?@"✓ ":@"",display];
        [editor addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *choice){
            NSString *title=[editor.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if(!title.length){[weakSelf zn60v3_setStatus:@"Native Hook 功能名称不能为空"];return;}
            BOOL controlOK=[[ZNNativeHookStore sharedStore] updatePresentationForActionID:action.actionID
                title:title description:editor.textFields[1].text?:@"" controlType:type];
            [weakSelf zn60v3_setStatus:controlOK?[NSString stringWithFormat:@"Native Hook 已保存：%@ · %@",title,display]:@"Native Hook 功能配置保存失败"];
            [weakSelf renderPage];
        }]];
    }
    [editor addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *top=ZNM52XTop(self.hostWindow);
    if(top)[top presentViewController:editor animated:YES completion:nil];
}

- (void)znm660_editHookControlTapped:(UIButton *)sender {
    NSInteger index=sender.tag-kZNNativeHookDeleteTagBase;
    NSArray<ZNNativeHookAction *> *hooks=[[ZNNativeHookStore sharedStore] actionsSnapshot];
    if(index<0||(NSUInteger)index>=hooks.count)return;
    [self znm660_chooseHookControlForAction:hooks[(NSUInteger)index] source:sender];
}

- (void)zn64_hookTestTapped:(UIButton *)sender {
    NSDictionary *candidate=objc_getAssociatedObject(sender,ZNNativeHookCandidateAssociationKey);
    if(!candidate)return;

    NSString *planError=nil;
    NSDictionary *plan=ZNM613HookPlan(candidate,&planError);
    NSString *intReason=nil,*structReason=nil;
    NSArray<NSNumber *> *intArgs=[[ZNNativeHookRuntime sharedRuntime] supportedInt32ArgumentIndicesForCandidate:candidate reason:&intReason];
    NSArray<NSNumber *> *structArgs=[[ZNNativeHookRuntime sharedRuntime] supportedStructFieldArgumentIndicesForCandidate:candidate reason:&structReason];

    // Opening the selector must not depend on automatic ABI plan inference.
    // Actual installs remain guarded by each template's runtime ABI validation.
    UIAlertController *picker=[UIAlertController alertControllerWithTitle:@"Native Hook 测试"
        message:plan?@"选择测试模板；创建方法与实际安装分别验证 ABI。":
            [NSString stringWithFormat:@"自动方案不可用：%@\n可查看受支持的模板；不支持的类型不会执行 Hook。",planError?:@"unsupported"]
        preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf=self;
    if(intArgs.count){
        for(NSNumber *n in intArgs){
            NSUInteger idx=n.unsignedIntegerValue;
            [picker addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Int32 倍率 · 参数%lu",(unsigned long)idx+1]
                style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
                    [weakSelf zn64_presentHookConfigForCandidate:candidate argumentIndex:idx source:sender];
                }]];
        }
    }
    if(structArgs.count){
        [picker addAction:[UIAlertAction actionWithTitle:@"自动 · Complex Struct Codec"
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
                [weakSelf zn68_presentStructFieldPickerForCandidate:candidate indices:structArgs source:sender];
            }]];
    }
    if(structArgs.count){
        [picker addAction:[UIAlertAction actionWithTitle:@"手动 · Struct Field Offset" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){
            if(structArgs.count==1){
                [weakSelf zn68_presentManualStructFieldConfigForCandidate:candidate argumentIndex:structArgs.firstObject.unsignedIntegerValue source:sender];
                return;
            }
            UIAlertController *args=[UIAlertController alertControllerWithTitle:@"选择手动 Struct 参数" message:@"Field Offset 默认 0x48；实际修改前需要确认布局和 Codec。" preferredStyle:UIAlertControllerStyleActionSheet];
            for(NSNumber *n in structArgs){
                NSUInteger arg=n.unsignedIntegerValue;
                [args addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"参数%lu",(unsigned long)arg+1] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
                    [weakSelf zn68_presentManualStructFieldConfigForCandidate:candidate argumentIndex:arg source:sender];
                }]];
            }
            [args addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            UIViewController *vc=ZNM52XTop(weakSelf.hostWindow);
            if(args.popoverPresentationController){args.popoverPresentationController.sourceView=sender;args.popoverPresentationController.sourceRect=sender.bounds;}
            if(vc)[vc presentViewController:args animated:YES completion:nil];
        }]];
    }
    if(!intArgs.count&&!structArgs.count){
        NSString *reason=structReason.length?structReason:(intReason.length?intReason:planError);
        if(reason.length)picker.message=[picker.message stringByAppendingFormat:@"\n诊断：%@",reason];
    }
    [picker addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *top=ZNM52XTop(self.hostWindow);
    if(!top)return;
    UIPopoverPresentationController *popover=picker.popoverPresentationController;
    if(popover){popover.sourceView=sender;popover.sourceRect=sender.bounds;popover.permittedArrowDirections=UIPopoverArrowDirectionAny;}
    [top presentViewController:picker animated:YES completion:nil];
}

- (void)zn64_presentHookConfigForCandidate:(NSDictionary *)candidate
                              argumentIndex:(NSUInteger)argumentIndex
                                     source:(UIButton *)source {
    NSString *method=ZNM52XString(candidate[@"method"]);
    NSDictionary *abi=ZNIL2CPPDescribeMethodABI(candidate);
    NSArray *params=[abi[@"parameters"] isKindOfClass:NSArray.class]?abi[@"parameters"]:@[];
    NSDictionary *param=argumentIndex<params.count?params[argumentIndex]:@{};
    NSString *paramName=[param[@"paramName"] isKindOfClass:NSString.class]?param[@"paramName"]:@"";
    NSString *diag=[[ZNNativeHookRuntime sharedRuntime] diagnosticsForCandidate:candidate];
    NSString *message=[NSString stringWithFormat:@"目标：%@::%@/%@\n参数：%lu%@\n模板：ArgScaleInt32\n\n%@",
                       ZNM52XString(candidate[@"class"]),method,candidate[@"argumentCount"]?:@0,
                       (unsigned long)argumentIndex+1,
                       paramName.length?[NSString stringWithFormat:@" · %@",paramName]:@"",
                       diag?:@""];

    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"IL2CPP Native Hook 测试"
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){
        field.placeholder=@"测试倍率，例如 5";
        field.text=@"5";
        field.keyboardType=UIKeyboardTypeNumberPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){
        field.placeholder=@"创建后的 Slider Max，例如 20";
        field.text=@"20";
        field.keyboardType=UIKeyboardTypeNumberPad;
    }];

    __weak typeof(self) weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:@"安装 / 更新测试 Hook" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
        NSInteger multiplier=alert.textFields.firstObject.text.integerValue;
        NSString *error=nil;
        BOOL ok=[[ZNNativeHookRuntime sharedRuntime] installTemporaryArgScaleInt32ForCandidate:candidate
                                                                                argumentIndex:argumentIndex
                                                                                   multiplier:multiplier
                                                                                        error:&error];
        [weakSelf zn60v3_setStatus:ok
            ? [NSString stringWithFormat:@"Native Hook 已安装 · %@ arg%lu ×%ld；实时状态见筛选栏下方",
               method,(unsigned long)argumentIndex,(long)multiplier]
            : (error?:@"Native Hook 安装失败")];
        [weakSelf renderPage];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"恢复原方法" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a){
        NSString *error=nil;
        BOOL ok=[[ZNNativeHookRuntime sharedRuntime] removeTemporaryHookForCandidate:candidate error:&error];
        [weakSelf zn60v3_setStatus:ok?@"Native Hook 已移除，目标已恢复":(error?:@"恢复原方法失败")];
        [weakSelf renderPage];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"创建 Hook 方法" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
        NSInteger multiplier=MAX(1,alert.textFields.firstObject.text.integerValue);
        NSInteger maxValue=MAX(multiplier,alert.textFields.count>1?alert.textFields[1].text.integerValue:20);
        maxValue=MIN(MAX(maxValue,1),1000);
        NSString *error=nil;
        NSString *title=[NSString stringWithFormat:@"%@ Multiplier",method.length?method:@"Native Hook"];
        ZNNativeHookAction *created=[[ZNNativeHookStore sharedStore] addArgScaleInt32Candidate:candidate
                                                                                       title:title
                                                                               argumentIndex:argumentIndex
                                                                                         min:1
                                                                                         max:maxValue
                                                                                defaultValue:1
                                                                                       error:&error];
        [weakSelf zn60v3_setStatus:created
            ? [NSString stringWithFormat:@"已创建 Native Hook：%@ · Slider 1~%ld",created.title,(long)maxValue]
            : (error?:@"创建 Native Hook 失败")];
        if(created)[weakSelf znm660_chooseHookControlForAction:created source:weakSelf.contentView];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *top=ZNM52XTop(self.hostWindow);
    if(top)[top presentViewController:alert animated:YES completion:nil];
}


- (void)zn52x_reselectInstance:(UIButton *)sender {
    NSDictionary *candidate=objc_getAssociatedObject(sender,kZNM52XCandidateKey);
    if(!candidate)return;
    NSString *assembly=ZNM52XString(candidate[@"assembly"]); if(!assembly.length)assembly=@"Assembly-CSharp.dll";
    NSString *ns=ZNM52XString(candidate[@"namespace"]);
    NSString *cls=ZNM52XString(candidate[@"class"]);
    ZNIL2CPPInstanceResolver *resolver=[ZNIL2CPPInstanceResolver sharedResolver];

    uintptr_t previous=[resolver znm44_selectedInstanceForAssembly:assembly namespace:ns className:cls];
    [resolver znm44_clearSelectedInstanceForAssembly:assembly namespace:ns className:cls];

    NSString *diag=nil,*findError=nil;
    NSArray<NSNumber *> *instances=[resolver candidateAddressesForAssembly:assembly namespace:ns className:cls limit:32 diagnostics:&diag error:&findError];
    if(!instances.count){
        [self zn60v3_setStatus:findError ?: @"重新选择实例：没有找到活实例"];
        [self renderPage];
        return;
    }

    UIAlertController *alert=[UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"重新选择实例 · %@",cls.length?cls:@"Object"]
                                                                 message:[NSString stringWithFormat:@"发现 %lu 个活实例；旧 GCHandle 已释放",(unsigned long)instances.count]
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf=self;
    for(NSUInteger i=0;i<instances.count;i++){
        uintptr_t address=instances[i].unsignedLongLongValue;
        NSString *mark=(previous&&address==previous)?@" · 原当前":@"";
        NSString *title=[NSString stringWithFormat:@"实例 %lu · 0x%llX%@",(unsigned long)(i+1),(unsigned long long)address,mark];
        [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
            NSString *selectionError=nil;
            BOOL ok=[[ZNIL2CPPInstanceResolver sharedResolver] znm44_selectInstanceAddress:address assembly:assembly namespace:ns className:cls error:&selectionError];
            [weakSelf zn60v3_setStatus:ok
                ? [NSString stringWithFormat:@"已重新选择 %@：0x%llX",cls.length?cls:@"Object",(unsigned long long)address]
                : (selectionError ?: @"重新选择实例失败")];
            [weakSelf renderPage];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *a){
        [weakSelf zn60v3_setStatus:@"已取消重新选择；旧 receiver 已释放"];
        [weakSelf renderPage];
    }]];

    UIViewController *top=ZNM52XTop(self.hostWindow);
    if(!top)return;
    UIPopoverPresentationController *popover=alert.popoverPresentationController;
    if(popover){popover.sourceView=sender;popover.sourceRect=sender.bounds;popover.permittedArrowDirections=UIPopoverArrowDirectionAny;}
    [top presentViewController:alert animated:YES completion:nil];
}

- (void)zn52x_batchTestInstances:(UIButton *)sender {
    NSDictionary *candidate=objc_getAssociatedObject(sender,kZNM52XCandidateKey);
    if(!candidate||!ZNM52XBatchSafe(candidate))return;
    NSString *assembly=ZNM52XString(candidate[@"assembly"]); if(!assembly.length)assembly=@"Assembly-CSharp.dll";
    NSString *ns=ZNM52XString(candidate[@"namespace"]);
    NSString *cls=ZNM52XString(candidate[@"class"]);
    NSString *method=ZNM52XString(candidate[@"method"]);

    NSString *diag=nil,*findError=nil;
    NSArray<NSNumber *> *instances=[[ZNIL2CPPInstanceResolver sharedResolver] candidateAddressesForAssembly:assembly namespace:ns className:cls limit:32 diagnostics:&diag error:&findError];
    if(!instances.count){
        [self zn60v3_setStatus:findError ?: @"批量测试实例：没有找到活实例"];
        [self renderPage];
        return;
    }

    ZNRuntimeMethodAction *action=[ZNRuntimeMethodAction new];
    action.title=method.length?method:@"Batch Instance Test";
    action.assembly=assembly;
    action.namespaceName=ns;
    action.className=cls;
    action.methodName=method;
    action.argumentCount=0;
    action.argumentValues=@[];
    action.immediateChain=@{};

    NSMutableArray<NSString *> *lines=[NSMutableArray array];
    NSUInteger success=0;
    for(NSUInteger i=0;i<instances.count;i++){
        uintptr_t address=instances[i].unsignedLongLongValue;
        NSString *invokeError=nil;
        NSDictionary *result=[[ZNIL2CPPInvokeEngine sharedEngine] executeAction:action receiver:address error:&invokeError];
        if(result){
            success++;
            NSString *value=[result[@"returnValue"] description];
            if(!value.length)value=[NSString stringWithFormat:@"0x%llX",(unsigned long long)[result[@"result"] unsignedLongLongValue]];
            [lines addObject:[NSString stringWithFormat:@"#%lu 0x%llX  ✅  %@",(unsigned long)(i+1),(unsigned long long)address,value]];
        }else{
            [lines addObject:[NSString stringWithFormat:@"#%lu 0x%llX  ❌  %@",(unsigned long)(i+1),(unsigned long long)address,invokeError ?: @"FAILED"]];
        }
    }

    [self zn60v3_setStatus:[NSString stringWithFormat:@"批量测试完成：%lu/%lu 成功；当前 receiver 未改变",(unsigned long)success,(unsigned long)instances.count]];
    UIViewController *top=ZNM52XTop(self.hostWindow);
    if(top){
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"批量测试实例 · %@::%@",cls,method]
                                                                     message:[lines componentsJoinedByString:@"\n"]
                                                              preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [top presentViewController:alert animated:YES completion:nil];
    }
}

- (void)zn52x_restartChainLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIButton *button = [gesture.view isKindOfClass:UIButton.class] ? (UIButton *)gesture.view : nil;
    if (!button) return;
    NSInteger index = [objc_getAssociatedObject(button, kZNM52XIndexKey) integerValue];
    NSString *error = nil;
    if (index < 0 || ![[ZNRuntimeActionStore sharedStore] updateImmediateChain:@{} atIndex:(NSUInteger)index error:&error]) {
        [self zn60v3_setStatus:error.length ? error : @"重新链式调用失败：无法清空旧链"];
        return;
    }
    [button setTitle:@"链式调用" forState:UIControlStateNormal];
    [button removeTarget:self action:@selector(zn52x_executeChainTapped:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(zn52_chainTapped:) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(button, kZNM52XActionKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self zn60v3_setStatus:@"旧链已清空，重新进入链式调用"];
    [self zn52_chainTapped:button];
}

@end

static void ZNM52XSwap(Class cls, SEL a, SEL b) {
    Method ma = class_getInstanceMethod(cls, a), mb = class_getInstanceMethod(cls, b);
    if (ma && mb) method_exchangeImplementations(ma, mb);
}

extern "C" void ZNInstallM52ChainExecuteButtonDeferred(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class menu = NSClassFromString(@"ZNRuntimeMenuControllerV040");
        if (menu) ZNM52XSwap(menu, @selector(zn60v3_renderResultsAtWidth:), @selector(zn52x_renderResultsAtWidth:));
        [[ZNRuntimeLogger sharedLogger] log:@"[m6.13.1-result-card] single-owner renderer; no additive overlay; explicit mode state"];
    });
}

#pragma mark - END ZNM52ChainExecuteButton.mm
