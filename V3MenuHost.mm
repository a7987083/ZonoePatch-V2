#import "V3MenuController.h"

@interface ZNV3MenuHost : NSObject
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) ZNV3MenuController *controller;
+ (instancetype)shared;
- (void)toggleFromWindow:(UIWindow *)host;
- (void)hide;
- (void)appEvent:(NSNotification *)note;
@end
@implementation ZNV3MenuHost
+ (instancetype)shared {static ZNV3MenuHost *v;static dispatch_once_t once;dispatch_once(&once,^{v=[self new];});return v;}
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
    ZNV3MenuController *controller=[ZNV3MenuController new];
    __weak ZNV3MenuHost *weakOwner=self;
    controller.closeBlock=^{[weakOwner hide];};
    w.rootViewController=controller;
    self.window=w;self.controller=controller;
 }
 self.window.frame=host.bounds;
 self.window.hidden=NO;
}
@end

void ZNV3ShowMenu(UIWindow *host) {[[ZNV3MenuHost shared] toggleFromWindow:host];}
