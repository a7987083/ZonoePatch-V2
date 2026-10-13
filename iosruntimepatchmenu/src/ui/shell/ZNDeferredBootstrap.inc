#pragma mark - BEGIN ZNDeferredBootstrap.mm
#line 1 "ZNDeferredBootstrap.mm"
#import "ZNDeferredBootstrap.h"
#import <UIKit/UIKit.h>
#import <atomic>

extern "C" void ZNInstallSharedSiteExecutionProbeV3Deferred(void);
extern "C" void ZNInstallPublicCompactLayoutDeferred(void);
extern "C" void ZNInstallRuntimeExecutorV041Deferred(void);
extern "C" void ZNInstallRuntimeDiagnosticsV042Deferred(void);
extern "C" void ZNPrepareStaticDispatchRuntimeDeferred(void);
extern "C" void ZNInstallRuntimeMenuV055Deferred(void);
extern "C" void ZNInstallFeatureGroupUIDeferred(void);
extern "C" void ZNInstallPublicCompactDefaultsDeferred(void);
extern "C" void ZNInstallIL2CPPNamedOffsetWorkspaceDeferred(void);
extern "C" void ZNInstallFeatureBuilderUIDeferred(void);
extern "C" void ZNInstallRuntimeMethodCallBuilderUIDeferred(void);
extern "C" void ZNInstallMethodFinderUnifiedUIDeferred(void);
extern "C" void ZNInstallM630HardCutUIDeferred(void);

extern "C" void ZonoePatchStart(void);
extern "C" void ZonoePatchShow(void);

typedef NS_ENUM(int, ZNDeferredState) {
    ZNDeferredStateCold = 0,
    ZNDeferredStateLoading = 1,
    ZNDeferredStateReady = 2,
    ZNDeferredStateFailed = 3,
};

static std::atomic<int> gZNDeferredState{ZNDeferredStateCold};

#import "ZNActivationStageRunner.h"

extern "C" BOOL ZNDeferredBootstrapIsActivated(void) {
    int state = gZNDeferredState.load(std::memory_order_acquire);
    return state == ZNDeferredStateLoading || state == ZNDeferredStateReady;
}

extern "C" BOOL ZNDeferredBootstrapIsReady(void) {
    return gZNDeferredState.load(std::memory_order_acquire) == ZNDeferredStateReady;
}

static UIWindow *ZNDeferredCurrentWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if (@available(iOS 13.0, *)) {
        UIWindow *fallback = nil;
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            if (scene.activationState != UISceneActivationStateForegroundActive &&
                scene.activationState != UISceneActivationStateForegroundInactive) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.hidden || window.alpha <= 0.01) continue;
                if (window.isKeyWindow) return window;
                if (!fallback && window.windowLevel == UIWindowLevelNormal && window.rootViewController) fallback = window;
            }
        }
        if (fallback) return fallback;
    }
    if (app.keyWindow && !app.keyWindow.hidden) return app.keyWindow;
    for (UIWindow *window in app.windows.reverseObjectEnumerator) {
        if (!window.hidden && window.windowLevel == UIWindowLevelNormal && window.rootViewController) return window;
    }
    return nil;
}

@interface ZNDeferredLauncher : NSObject
@property(nonatomic,weak) UIWindow *hostWindow;
- (void)installIfPossible;
- (void)zn_beginActivation;
- (void)zn_finishActivation;
- (void)zn_markFailed:(NSException *)exception;
@end

@implementation ZNDeferredLauncher

+ (instancetype)sharedLauncher {
    static ZNDeferredLauncher *launcher;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ launcher = [ZNDeferredLauncher new]; });
    return launcher;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    [nc addObserver:self selector:@selector(zn_windowChanged:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [nc addObserver:self selector:@selector(zn_windowChanged:) name:UIWindowDidBecomeKeyNotification object:nil];
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)zn_windowChanged:(NSNotification *)note {
    (void)note;
    [self installIfPossible];
}

- (void)installIfPossible {
    int state=gZNDeferredState.load(std::memory_order_acquire);
    if(state==ZNDeferredStateReady||state==ZNDeferredStateLoading)return;

    UIWindow *window=ZNDeferredCurrentWindow();
    if(!window)return;

    int expected=ZNDeferredStateCold;
    if(!gZNDeferredState.compare_exchange_strong(expected,
                                                  ZNDeferredStateLoading,
                                                  std::memory_order_acq_rel))
        return;

    // The cold launcher is no longer a user-visible activation button. We build
    // the real menu shell as soon as UIKit has a host window; its own floating
    // button appears only after the shell is ready.
    self.hostWindow=window;
    [self zn_beginActivation];
}

- (void)zn_markFailed:(NSException *)exception {
    gZNDeferredState.store(ZNDeferredStateFailed, std::memory_order_release);
    NSLog(@"[ZonoPatch] v0.5.7 deferred activation failed: %@", exception.reason ?: @"unknown exception");
}

- (void)zn_finishActivation {
    @try {
        // M6.11 prewarms the visual/menu wiring before the real floating button
        // becomes interactive. No IL2CPP resolve, no build, no diagnostic probe.
        ZNRunActivationStage(@"RuntimeMenu", ^{ ZNInstallRuntimeMenuV055Deferred(); });
        ZNRunActivationStage(@"FeatureGroupUI", ^{ ZNInstallFeatureGroupUIDeferred(); });
        ZNRunActivationStage(@"PublicCompactDefaults", ^{ ZNInstallPublicCompactDefaultsDeferred(); });
        ZNRunActivationStage(@"IL2CPPNamedOffsetWorkspace", ^{ ZNInstallIL2CPPNamedOffsetWorkspaceDeferred(); });
        ZNRunActivationStage(@"FeatureBuilderUI", ^{ ZNInstallFeatureBuilderUIDeferred(); });
        ZNRunActivationStage(@"RuntimeMethodBuilderUI", ^{ ZNInstallRuntimeMethodCallBuilderUIDeferred(); });
        ZNRunActivationStage(@"MethodFinderUnifiedUI", ^{ ZNInstallMethodFinderUnifiedUIDeferred(); });
        ZNRunActivationStage(@"M630HardCutUI", ^{ ZNInstallM630HardCutUIDeferred(); });

        gZNDeferredState.store(ZNDeferredStateReady, std::memory_order_release);

        // Start creates/attaches the real menu floating button but does NOT show
        // the panel. Therefore the first user tap is only a show/toggle action.
        ZNRunActivationStage(@"ZonoePatchStart", ^{ ZonoePatchStart(); });

        [[ZNRuntimeLogger sharedLogger] log:
            @"[bootstrap][m6.11] instant-menu prewarm ready; first tap is show-only"];
    } @catch (NSException *exception) {
        [self zn_markFailed:exception];
    }
}

- (void)zn_beginActivation {
    @try {
        // Install lightweight execution/UI wiring now. Expensive capability work
        // remains lazy. In particular there is no fixed sleep and no Resolver.
        ZNRunActivationStage(@"SharedSiteExecutionProbeV3", ^{ ZNInstallSharedSiteExecutionProbeV3Deferred(); });
        ZNRunActivationStage(@"PublicCompactLayout", ^{ ZNInstallPublicCompactLayoutDeferred(); });
        ZNRunActivationStage(@"RuntimeExecutorV041", ^{ ZNInstallRuntimeExecutorV041Deferred(); });
        ZNRunActivationStage(@"RuntimeDiagnosticsV042", ^{ ZNInstallRuntimeDiagnosticsV042Deferred(); });
        ZNRunActivationStage(@"StaticDispatchPrepare", ^{ ZNPrepareStaticDispatchRuntimeDeferred(); });
        [self zn_finishActivation];
    } @catch (NSException *exception) {
        [self zn_markFailed:exception];
    }
}

@end

// M6.11 load-time bootstrap: wait until UIKit has a usable host window, then
// prewarm the menu shell. Resolver/build/test work stays lazy. The user's first
// tap on the real floating button performs no activation work.
__attribute__((constructor(200))) static void ZNDeferredColdLauncherBootstrap(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[ZNDeferredLauncher sharedLauncher] installIfPossible];
    });
}

#pragma mark - END ZNDeferredBootstrap.mm
