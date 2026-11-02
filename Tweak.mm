#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// H5GG-style architecture: attach the button to an existing application UIWindow.
// No overlay UIWindow is created until the menu milestone.
@interface ZNFloatingIcon : UIImageView
@property(nonatomic,copy) void (^onTap)(void);
@property(nonatomic,assign) CGPoint touchStart;
@property(nonatomic,assign) CGPoint originAtTouchStart;
@property(nonatomic,assign) BOOL moved;
- (void)constrainPosition;
@end

@implementation ZNFloatingIcon
- (instancetype)init {
    if ((self=[super initWithFrame:CGRectMake(20,160,50,50)])) {
        self.userInteractionEnabled=YES;
        self.backgroundColor=[UIColor colorWithRed:0.10 green:0.43 blue:0.94 alpha:0.94];
        self.layer.cornerRadius=25;
        self.clipsToBounds=YES;
        self.alpha=0.88;
        UILabel *label=[[UILabel alloc] initWithFrame:self.bounds];
        label.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        label.text=@"Z";
        label.textColor=UIColor.whiteColor;
        label.textAlignment=NSTextAlignmentCenter;
        label.font=[UIFont boldSystemFontOfSize:23];
        [self addSubview:label];
    }
    return self;
}
- (void)constrainPosition {
    UIView *parent=self.superview;
    if (!parent) return;
    CGRect r=parent.bounds;
    UIEdgeInsets safe=parent.safeAreaInsets;
    CGRect f=self.frame;
    CGFloat xMin=safe.left, yMin=safe.top;
    CGFloat xMax=MAX(xMin,CGRectGetWidth(r)-safe.right-f.size.width);
    CGFloat yMax=MAX(yMin,CGRectGetHeight(r)-safe.bottom-f.size.height);
    f.origin.x=MAX(xMin,MIN(f.origin.x,xMax));
    f.origin.y=MAX(yMin,MIN(f.origin.y,yMax));
    self.frame=f;
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch=touches.anyObject;
    self.touchStart=[touch locationInView:self.superview];
    self.originAtTouchStart=self.frame.origin;
    self.moved=NO;
    [self.superview bringSubviewToFront:self];
    [super touchesBegan:touches withEvent:event];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint now=[touches.anyObject locationInView:self.superview];
    CGPoint shift=CGPointMake(now.x-self.touchStart.x,now.y-self.touchStart.y);
    if (hypot(shift.x,shift.y)>7) self.moved=YES;
    CGRect f=self.frame;
    f.origin=CGPointMake(self.originAtTouchStart.x+shift.x,
                         self.originAtTouchStart.y+shift.y);
    self.frame=f;
    [self constrainPosition];
    [super touchesMoved:touches withEvent:event];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint end=[touches.anyObject locationInView:self.superview];
    if (!self.moved && hypot(end.x-self.touchStart.x,end.y-self.touchStart.y)<8) {
        if(self.onTap) self.onTap();
    }
    [super touchesEnded:touches withEvent:event];
}
@end

@interface ZNFloatingHost : NSObject
@property(nonatomic,strong) ZNFloatingIcon *icon;
@property(nonatomic,strong) NSTimer *monitor;
+ (instancetype)shared;
- (void)start;
- (void)refresh;
- (void)event:(NSNotification *)note;
@end

@implementation ZNFloatingHost
+ (instancetype)shared {
    static ZNFloatingHost *instance;
    static dispatch_once_t once;
    dispatch_once(&once,^{instance=[self new];});
    return instance;
}
- (UIWindow *)hostWindow {
    UIApplication *app=UIApplication.sharedApplication;
    if (app.applicationState==UIApplicationStateBackground) return nil;
    UIWindow *fallback=nil;
    if (@available(iOS 13.0,*)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class] ||
                scene.activationState!=UISceneActivationStateForegroundActive) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.hidden || window.alpha<=0 || !window.rootViewController ||
                    window.windowLevel!=UIWindowLevelNormal) continue;
                if (window.isKeyWindow) return window;
                if (!fallback) fallback=window;
            }
        }
    } else {
        for (UIWindow *window in app.windows) {
            if (window.hidden || !window.rootViewController ||
                window.windowLevel!=UIWindowLevelNormal) continue;
            if (window.isKeyWindow) return window;
            if (!fallback) fallback=window;
        }
    }
    return fallback;
}
- (void)event:(NSNotification *)note {(void)note;[self refresh];}
- (void)start {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(),^{[self start];}); return;
    }
    if (self.monitor) return;
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(event:)
        name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(event:)
        name:UIApplicationWillResignActiveNotification object:nil];
    if (@available(iOS 13.0,*)) {
        [center addObserver:self selector:@selector(event:)
            name:UISceneDidActivateNotification object:nil];
        [center addObserver:self selector:@selector(event:)
            name:UISceneWillDeactivateNotification object:nil];
    }
    // H5GG uses periodic reattachment; keep this lightweight and main-runloop-only.
    self.monitor=[NSTimer scheduledTimerWithTimeInterval:0.5
        target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    [self refresh];
}
- (void)refresh {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(),^{[self refresh];});return;
    }
    UIWindow *host=[self hostWindow];
    if (!host) {self.icon.hidden=YES;return;}
    if (!self.icon) {
        self.icon=[ZNFloatingIcon new];
        __weak typeof(self) weakSelf=self;
        self.icon.onTap=^{
            UIWindow *window=(UIWindow *)weakSelf.icon.window;
            UIViewController *presenter=window.rootViewController;
            while (presenter.presentedViewController)
                presenter=presenter.presentedViewController;
            if (!presenter || !presenter.view.window) return;
            UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"ZonoePatch V3"
                message:@"悬浮图标响应成功" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                style:UIAlertActionStyleDefault handler:nil]];
            [presenter presentViewController:alert animated:YES completion:nil];
        };
    }
    if (self.icon.superview!=host) [host addSubview:self.icon];
    self.icon.hidden=NO;
    [host bringSubviewToFront:self.icon];
    [self.icon constrainPosition];
}
@end

__attribute__((constructor)) static void ZNFloatingBootstrap(void) {
    dispatch_async(dispatch_get_main_queue(),^{
        [[ZNFloatingHost shared] start];
    });
}
