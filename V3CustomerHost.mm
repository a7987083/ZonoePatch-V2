#import "V3CustomerMenuController.h"
#import "V3CustomerRuntime.h"

// Keep this window non-key. Accept touches only in the actual rounded card.
@interface ZNV3CustomerWindow : UIWindow
@end
@implementation ZNV3CustomerWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
 if(![super pointInside:point withEvent:event])return NO;
 return [[UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:14]
    containsPoint:point];
}
@end

@interface ZNV3CustomerHost : NSObject
@property(nonatomic,strong) ZNV3CustomerWindow *window;
@property(nonatomic,strong) ZNV3CustomerMenuController *controller;
@property(nonatomic,weak) UIWindow *sourceWindow;
@property(nonatomic,strong) NSTimer *layoutMonitor;
@property(nonatomic,assign) CGSize lastSceneSize;
+ (instancetype)shared;
- (void)toggleFromWindow:(UIWindow *)host;
- (void)updateLayout;
- (void)hide;
- (void)appEvent:(NSNotification *)note;
@end
@implementation ZNV3CustomerHost
+ (instancetype)shared {
 static ZNV3CustomerHost *v;static dispatch_once_t once;
 dispatch_once(&once,^{v=[self new];});return v;
}
- (instancetype)init {
 if((self=[super init])){
  NSNotificationCenter *nc=NSNotificationCenter.defaultCenter;
  [nc addObserver:self selector:@selector(appEvent:)
            name:UIApplicationDidEnterBackgroundNotification object:nil];
  [nc addObserver:self selector:@selector(appEvent:)
            name:UIApplicationDidBecomeActiveNotification object:nil];
  if(@available(iOS 13.0,*)){
   [nc addObserver:self selector:@selector(appEvent:)
             name:UISceneDidDisconnectNotification object:nil];
   [nc addObserver:self selector:@selector(appEvent:)
             name:UISceneDidActivateNotification object:nil];
  }
 }return self;
}
- (void)appEvent:(NSNotification *)note {
 if(![NSThread isMainThread]){
  dispatch_async(dispatch_get_main_queue(),^{[self appEvent:note];});return;
 }
 if([note.name isEqualToString:UIApplicationDidEnterBackgroundNotification]){
  [self hide];return;
 }
 if(@available(iOS 13.0,*)){
  if([note.name isEqualToString:UISceneDidDisconnectNotification] &&
     [note.object isKindOfClass:UIWindowScene.class] &&
     self.window.windowScene==note.object){
   [self hide];self.window.rootViewController=nil;
   self.window=nil;self.controller=nil;self.sourceWindow=nil;return;
  }
 }
 if(self.window && !self.window.hidden)[self updateLayout];
}
- (void)hide {
 [self.layoutMonitor invalidate];self.layoutMonitor=nil;
 [self.controller.view endEditing:YES];
 self.window.hidden=YES;
}
- (CGRect)sceneBoundsForHost:(UIWindow *)host {
 if(@available(iOS 13.0,*)){
  if(host.windowScene)return host.windowScene.coordinateSpace.bounds;
 }
 return host.bounds;
}
- (void)updateLayout {
 if(![NSThread isMainThread]){
  dispatch_async(dispatch_get_main_queue(),^{[self updateLayout];});return;
 }
 UIWindow *host=self.sourceWindow;
 if(!host||!self.window||!self.controller||self.window.hidden)return;
 if(@available(iOS 13.0,*)){
  if(host.windowScene!=self.window.windowScene ||
     host.windowScene.activationState!=UISceneActivationStateForegroundActive)return;
 }
 CGRect sceneBounds=[self sceneBoundsForHost:host];
 self.lastSceneSize=sceneBounds.size;
 UIInterfaceOrientationMask mask=
    CGRectGetWidth(sceneBounds)>CGRectGetHeight(sceneBounds)?
    UIInterfaceOrientationMaskLandscape:UIInterfaceOrientationMaskPortrait;
 self.controller.hostOrientationMask=mask;
 // Exact layout: 3 top + 40 header + 1 divider + 5 bottom.
 // Empty placeholder is 66pt; error banner adds 34pt only with visible rows.
 NSUInteger count=[[ZNV3CustomerRuntime shared] discover].count;
 BOOL locked=[ZNV3CustomerRuntime shared].recoveryFailed;
 CGFloat rows=count?44.0*MIN((NSUInteger)12,count):66.0;
 CGFloat contentHeight=49.0+rows+(locked&&count?34.0:0.0);
 CGFloat width=MIN(300.0,MAX(120.0,CGRectGetWidth(sceneBounds)-28.0));
 CGFloat height=MIN(contentHeight,MAX(60.0,CGRectGetHeight(sceneBounds)-16.0));
 CGRect previous=self.window.frame;
 // Preserve the dragged origin; only center when the window has no frame yet.
 CGPoint origin=CGRectIsEmpty(previous)?
   CGPointMake(CGRectGetMidX(sceneBounds)-width/2,CGRectGetMidY(sceneBounds)-height/2):
   previous.origin;
 CGFloat minX=CGRectGetMinX(sceneBounds)+8,minY=CGRectGetMinY(sceneBounds)+8;
 origin.x=MAX(minX,MIN(origin.x,MAX(minX,CGRectGetMaxX(sceneBounds)-width-8)));
 origin.y=MAX(minY,MIN(origin.y,MAX(minY,CGRectGetMaxY(sceneBounds)-height-8)));
 CGRect desired=CGRectMake(origin.x,origin.y,width,height);
 if(!CGRectEqualToRect(self.window.frame,desired))self.window.frame=desired;
}
- (void)monitorLayout:(NSTimer *)timer {
 (void)timer;
 if(!self.window||self.window.hidden)return;
 UIWindow *host=self.sourceWindow;
 if(!host)return;
 CGSize now=[self sceneBoundsForHost:host].size;
 if(!CGSizeEqualToSize(self.lastSceneSize,now))[self updateLayout];
}
- (void)toggleFromWindow:(UIWindow *)host {
 if(![NSThread isMainThread]){
  dispatch_async(dispatch_get_main_queue(),^{[self toggleFromWindow:host];});return;
 }
 if(self.window && !self.window.hidden){[self hide];return;}
 if(!host||host.hidden||host.windowLevel!=UIWindowLevelNormal)return;
 if(self.window && self.window.windowScene!=host.windowScene){
  [self hide];self.window.rootViewController=nil;
  self.window=nil;self.controller=nil;
 }
 self.sourceWindow=host;
 if(!self.window){
  ZNV3CustomerWindow *w;
  if(@available(iOS 13.0,*))w=[[ZNV3CustomerWindow alloc]initWithWindowScene:host.windowScene];
  else w=[[ZNV3CustomerWindow alloc]initWithFrame:host.bounds];
  // Stay below system alerts, and never call makeKeyAndVisible.
  w.windowLevel=UIWindowLevelAlert-1;
  w.backgroundColor=UIColor.clearColor;
  ZNV3CustomerMenuController *controller=[ZNV3CustomerMenuController new];
  __weak ZNV3CustomerHost *weakOwner=self;
  controller.closeBlock=^{[weakOwner hide];};
  controller.layoutChangedBlock=^{[weakOwner updateLayout];};
  w.rootViewController=controller;
  self.window=w;self.controller=controller;
  // Start with zero size so the first layout centers the card.
  self.window.frame=CGRectZero;
 }
 self.window.hidden=NO;
 [self.controller refreshFeatures];
 [self updateLayout];
 // Scene geometry can change without the menu controller receiving a size transition.
 [self.layoutMonitor invalidate];
 self.layoutMonitor=[NSTimer scheduledTimerWithTimeInterval:0.5
    target:self selector:@selector(monitorLayout:) userInfo:nil repeats:YES];
}
@end

void ZNV3ShowMenu(UIWindow *host) {
 [[ZNV3CustomerHost shared] toggleFromWindow:host];
}
