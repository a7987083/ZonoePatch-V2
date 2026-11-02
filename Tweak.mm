#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface ZNOverlayWindow : UIWindow
@end
@implementation ZNOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self || hit == self.rootViewController.view) ? nil : hit;
}
@end

@interface ZNOverlayController : UIViewController
@property(nonatomic,strong) UIButton *bubble;
@property(nonatomic,assign) CGPoint start;
@end
@implementation ZNOverlayController
- (void)loadView {
    self.view=[[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor=UIColor.clearColor;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];
    b.frame=CGRectMake(16,160,56,56);
    b.backgroundColor=[UIColor colorWithRed:.1 green:.43 blue:.94 alpha:.94];
    b.layer.cornerRadius=28;
    b.layer.borderWidth=1.5;
    b.layer.borderColor=UIColor.whiteColor.CGColor;
    [b setTitle:@"Z" forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font=[UIFont boldSystemFontOfSize:24];
    [b addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    pan.maximumNumberOfTouches=1;
    [b addGestureRecognizer:pan];
    [self.view addSubview:b];
    self.bubble=b;
}
- (CGRect)range {
    CGRect r=self.view.bounds;
    UIEdgeInsets insets=self.view.safeAreaInsets;
    CGFloat left=insets.left+8,top=insets.top+8;
    return CGRectMake(left,top,MAX(0,CGRectGetWidth(r)-left-insets.right-64),
        MAX(0,CGRectGetHeight(r)-top-insets.bottom-64));
}
- (void)clampSnap:(BOOL)snap animated:(BOOL)animated {
    CGRect r=[self range],f=self.bubble.frame;
    f.origin.x=MAX(r.origin.x,MIN(f.origin.x,CGRectGetMaxX(r)));
    f.origin.y=MAX(r.origin.y,MIN(f.origin.y,CGRectGetMaxY(r)));
    if(snap) f.origin.x=f.origin.x<=CGRectGetMidX(r)?r.origin.x:CGRectGetMaxX(r);
    void (^apply)(void)=^{self.bubble.frame=f;};
    if(animated) [UIView animateWithDuration:.22 animations:apply];
    else apply();
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self clampSnap:NO animated:NO];
}
- (void)panned:(UIPanGestureRecognizer *)pan {
    if(pan.state==UIGestureRecognizerStateBegan) self.start=self.bubble.frame.origin;
    if(pan.state==UIGestureRecognizerStateBegan||pan.state==UIGestureRecognizerStateChanged) {
        CGPoint delta=[pan translationInView:self.view];
        CGRect f=self.bubble.frame;
        f.origin=CGPointMake(self.start.x+delta.x,self.start.y+delta.y);
        self.bubble.frame=f;
        [self clampSnap:NO animated:NO];
    } else if(pan.state==UIGestureRecognizerStateEnded||pan.state==UIGestureRecognizerStateCancelled)
        [self clampSnap:YES animated:YES];
}
- (void)tapped {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"ZonoePatch V3"
        message:@"悬浮图标响应成功" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

@interface ZNOverlayHost : NSObject
@property(nonatomic,strong) ZNOverlayWindow *window;
@property(nonatomic,strong) ZNOverlayController *controller;
+ (instancetype)shared;
- (void)refresh;
- (void)notify:(NSNotification *)notification;
@end
@implementation ZNOverlayHost
+ (instancetype)shared {
    static ZNOverlayHost *host;
    static dispatch_once_t once;
    dispatch_once(&once,^{host=[self new];});
    return host;
}
- (void)notify:(NSNotification *)notification {(void)notification;[self refresh];}
- (void)refresh {
    if(![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(),^{[self refresh];});return;
    }
    UIApplication *app=UIApplication.sharedApplication;
    if(!app||app.applicationState==UIApplicationStateBackground) {
        self.window.hidden=YES;return;
    }
    UIWindowScene *scene=nil;
    if(@available(iOS 13.0,*)) {
        for(UIScene *candidate in app.connectedScenes) {
            if([candidate isKindOfClass:UIWindowScene.class]&&
                candidate.activationState==UISceneActivationStateForegroundActive) {
                scene=(UIWindowScene *)candidate;break;
            }
        }
        if(!scene) {self.window.hidden=YES;return;}
        if(self.window&&self.window.windowScene!=scene) {
            self.window.hidden=YES;self.window=nil;self.controller=nil;
        }
    }
    if(self.window) {self.window.hidden=NO;return;}
    ZNOverlayWindow *window;
    if(@available(iOS 13.0,*)) window=[[ZNOverlayWindow alloc] initWithWindowScene:scene];
    else window=[[ZNOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    window.frame=window.windowScene?window.windowScene.coordinateSpace.bounds:UIScreen.mainScreen.bounds;
    window.windowLevel=UIWindowLevelAlert+1;
    window.backgroundColor=UIColor.clearColor;
    ZNOverlayController *controller=[ZNOverlayController new];
    window.rootViewController=controller;
    self.controller=controller;self.window=window;
    window.hidden=NO;
}
@end
__attribute__((constructor)) static void ZNInit(void) {
    dispatch_async(dispatch_get_main_queue(),^{
        NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
        [center addObserver:[ZNOverlayHost shared] selector:@selector(notify:)
            name:UIApplicationDidBecomeActiveNotification object:nil];
        if(@available(iOS 13.0,*))
            [center addObserver:[ZNOverlayHost shared] selector:@selector(notify:)
                name:UISceneDidActivateNotification object:nil];
        [[ZNOverlayHost shared] refresh];
    });
}
