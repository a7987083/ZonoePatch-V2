#import "V3CustomerMenuController.h"
#import "V3CustomerRuntime.h"

@interface ZNV3CustomerHost : NSObject
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) ZNV3CustomerMenuController *controller;
+ (instancetype)shared;
- (void)toggleFromWindow:(UIWindow *)host;
- (void)hide;
- (void)appEvent:(NSNotification *)note;
@end
@implementation ZNV3CustomerHost
+ (instancetype)shared {static ZNV3CustomerHost *v;static dispatch_once_t once;dispatch_once(&once,^{v=[self new];});return v;}
- (instancetype)init {
 if((self=[super init])) {
 [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEvent:) name:UIApplicationDidEnterBackgroundNotification object:nil];
 if(@available(iOS 13.0,*)) [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEvent:) name:UISceneDidDisconnectNotification object:nil];
 }return self;
}
- (void)appEvent:(NSNotification *)note {
 if(![NSThread isMainThread]) { dispatch_async(dispatch_get_main_queue(), ^{[self appEvent:note];});return; }
 if([note.name isEqualToString:UIApplicationDidEnterBackgroundNotification]) { [self hide];return; }
 if(@available(iOS 13.0,*)) {
  if([note.object isKindOfClass:UIWindowScene.class] && self.window.windowScene==note.object) { [self hide];self.window.rootViewController=nil;self.window=nil;self.controller=nil; }
 }
}
- (void)hide { [self.controller.view endEditing:YES];self.window.hidden=YES; }
- (void)toggleFromWindow:(UIWindow *)host {
 if(self.window&&!self.window.hidden){[self hide];return;}
 if(!host)return;
 if(self.window && self.window.windowScene!=host.windowScene){[self hide];self.window.rootViewController=nil;self.window=nil;self.controller=nil;}
 // The game host determines layout orientation. The overlay must not rotate
 // independently just because its root controller defaults to all orientations.
 CGRect hostBounds=host.bounds;
 UIInterfaceOrientationMask mask=CGRectGetWidth(hostBounds)>CGRectGetHeight(hostBounds)
  ?UIInterfaceOrientationMaskLandscape:UIInterfaceOrientationMaskPortrait;
 BOOL creatingWindow=(self.window==nil);
 if(creatingWindow){
    UIWindow *w;
    if(@available(iOS 13.0,*))w=[[UIWindow alloc] initWithWindowScene:host.windowScene];
    else w=[[UIWindow alloc] initWithFrame:host.bounds];
    w.windowLevel=UIWindowLevelAlert+2;w.backgroundColor=UIColor.clearColor;
    ZNV3CustomerMenuController *controller=[ZNV3CustomerMenuController new];
    __weak ZNV3CustomerHost *weakOwner=self;
    controller.closeBlock=^{[weakOwner hide];};
    controller.hostOrientationMask=mask;
    w.rootViewController=controller;
    self.window=w;self.controller=controller;
 }
 CGRect sceneBounds=host.bounds;
 if(@available(iOS 13.0,*))sceneBounds=host.windowScene.coordinateSpace.bounds;
 self.controller.hostOrientationMask=mask;
 // Restore a readable card: about three quarters of a typical portrait game viewport.
 CGFloat width=MIN(300.0,MAX(210.0,CGRectGetWidth(sceneBounds)-28.0));
 NSUInteger count=[[ZNV3CustomerRuntime shared] discover].count;
 // 54pt header, 52pt per feature and 20pt combined vertical margins.
 CGFloat contentHeight=76.0+52.0*MIN((NSUInteger)12,MAX((NSUInteger)1,count));
 CGFloat height=MIN(contentHeight,MAX(130.0,CGRectGetHeight(sceneBounds)-24.0));
 CGPoint origin=creatingWindow
  ?CGPointMake(CGRectGetMidX(sceneBounds)-width/2.0,CGRectGetMidY(sceneBounds)-height/2.0)
  :self.window.frame.origin;
 CGFloat minX=CGRectGetMinX(sceneBounds)+8;
 CGFloat minY=CGRectGetMinY(sceneBounds)+8;
 origin.x=MAX(minX,MIN(origin.x,MAX(minX,CGRectGetMaxX(sceneBounds)-width-8)));
 origin.y=MAX(minY,MIN(origin.y,MAX(minY,CGRectGetMaxY(sceneBounds)-height-8)));
 self.window.frame=CGRectMake(origin.x,origin.y,width,height);
 self.window.hidden=NO;
 [self.controller refreshFeatures];
}
@end

void ZNV3ShowMenu(UIWindow *host) {[[ZNV3CustomerHost shared] toggleFromWindow:host];}
