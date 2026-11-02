#import <UIKit/UIKit.h>

@interface ZNV3MenuHost : NSObject
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) ZNV3MenuController *controller;
+ (instancetype)shared;
- (void)toggleFromWindow:(UIWindow *)host;
@end
@implementation ZNV3MenuHost
+ (instancetype)shared {static ZNV3MenuHost *v;static dispatch_once_t once;dispatch_once(&once,^{v=[self new];});return v;}
- (void)toggleFromWindow:(UIWindow *)host {
 if(self.window&&!self.window.hidden){self.window.hidden=YES;return;}
 if(!host)return;
 if(self.window && self.window.windowScene!=host.windowScene){self.window.hidden=YES;self.window=nil;self.controller=nil;}
 if(!self.window){
    UIWindow *w;
    if(@available(iOS 13.0,*))w=[[UIWindow alloc] initWithWindowScene:host.windowScene];
    else w=[[UIWindow alloc] initWithFrame:host.bounds];
    w.windowLevel=UIWindowLevelAlert+2;w.backgroundColor=UIColor.clearColor;
    ZNV3MenuController *controller=[ZNV3MenuController new];
    __weak ZNV3MenuHost *weakOwner=self;
    controller.closeBlock=^{weakOwner.window.hidden=YES;};
    w.rootViewController=controller;
    self.window=w;self.controller=controller;
 }
 self.window.frame=host.bounds;
 self.window.hidden=NO;
}
@end

void ZNV3ShowMenu(UIWindow *host) {[[ZNV3MenuHost shared] toggleFromWindow:host];}
