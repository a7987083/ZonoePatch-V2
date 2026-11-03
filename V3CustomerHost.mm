#import "V3CustomerMenuController.h"

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
 if(!self.window){
    UIWindow *w;
    if(@available(iOS 13.0,*))w=[[UIWindow alloc] initWithWindowScene:host.windowScene];
    else w=[[UIWindow alloc] initWithFrame:host.bounds];
    w.windowLevel=UIWindowLevelAlert+2;w.backgroundColor=UIColor.clearColor;
    ZNV3CustomerMenuController *controller=[ZNV3CustomerMenuController new];
    __weak ZNV3CustomerHost *weakOwner=self;
    controller.closeBlock=^{[weakOwner hide];};
    w.rootViewController=controller;
    self.window=w;self.controller=controller;
 }
 CGRect sceneBounds=host.bounds;
 if(@available(iOS 13.0,*))sceneBounds=host.windowScene.coordinateSpace.bounds;
 CGFloat width=MIN(350.0,MAX(250.0,CGRectGetWidth(sceneBounds)-24.0));
 CGFloat height=MIN(475.0,MAX(270.0,CGRectGetHeight(sceneBounds)-44.0));
 self.window.frame=CGRectMake(CGRectGetMidX(sceneBounds)-width/2.0,
                              CGRectGetMidY(sceneBounds)-height/2.0,width,height);
 self.window.hidden=NO;
}
@end

void ZNV3ShowMenu(UIWindow *host) {[[ZNV3CustomerHost shared] toggleFromWindow:host];}
