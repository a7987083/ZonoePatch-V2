#import "ZNMenuUIHelpers.h"
#define ZN_UI_LINKAGE

// UI_RELOCATED_BEGIN ZN48TopViewController
ZN_UI_LINKAGE UIViewController *ZN48TopViewController(UIViewController *vc) {
    if (!vc) return nil;
    UIViewController *presented=vc.presentedViewController;
    if (presented && !presented.isBeingDismissed) return ZN48TopViewController(presented);
    if ([vc isKindOfClass:UINavigationController.class]) {
        UIViewController *top=((UINavigationController *)vc).visibleViewController;
        return top?ZN48TopViewController(top):vc;
    }
    if ([vc isKindOfClass:UITabBarController.class]) {
        UIViewController *sel=((UITabBarController *)vc).selectedViewController;
        return sel?ZN48TopViewController(sel):vc;
    }
    if ([vc isKindOfClass:UISplitViewController.class]) {
        UIViewController *last=((UISplitViewController *)vc).viewControllers.lastObject;
        return last?ZN48TopViewController(last):vc;
    }
    return vc;
}// UI_RELOCATED_END ZN48TopViewController

// UI_RELOCATED_BEGIN ZNM52XTop
ZN_UI_LINKAGE UIViewController *ZNM52XTop(UIWindow *window) {
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}// UI_RELOCATED_END ZNM52XTop

// UI_RELOCATED_BEGIN ZNM54Field
ZN_UI_LINKAGE UITextField *ZNM54Field(CGRect frame, ZNTheme *theme, UIFont *font) {
    UITextField *field = [[UITextField alloc] initWithFrame:frame];
    field.textColor = theme.primaryTextColor;
    field.backgroundColor = theme.controlColor;
    field.tintColor = theme.accentColor;
    field.font = font;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.spellCheckingType = UITextSpellCheckingTypeNo;
    field.layer.cornerRadius = 7.0;
    field.layer.borderWidth = 1.0;
    field.layer.borderColor = theme.borderColor.CGColor;
    UIView *pad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 1)];
    field.leftView = pad;
    field.leftViewMode = UITextFieldViewModeAlways;
    return field;
}// UI_RELOCATED_END ZNM54Field

