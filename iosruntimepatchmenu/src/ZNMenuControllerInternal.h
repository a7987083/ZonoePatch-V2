#pragma once
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "ZNTheme.h"
#ifndef ZNRuntimeMenuControllerV024
#define ZNRuntimeMenuControllerV024 ZNRuntimeMenuControllerV040
#define ZN_INTERNAL_UI_ALIAS_ADDED
#endif
// UI_RELOCATED_BEGIN controller
@interface ZNRuntimeMenuControllerV024 : NSObject
@property(nonatomic,strong) UIButton *floatButton;
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIView *headerView;
@property(nonatomic,strong) UILabel *titleLabel;
@property(nonatomic,strong) UILabel *subtitleLabel;
@property(nonatomic,strong) UIView *readyDot;
@property(nonatomic,strong) UILabel *readyLabel;
@property(nonatomic,strong) UIButton *themeButton;
@property(nonatomic,strong) UIButton *modeButton;
@property(nonatomic,strong) UIButton *closeButton;
@property(nonatomic,strong) UIView *sidebarView;
@property(nonatomic,strong) UIScrollView *contentScroll;
@property(nonatomic,strong) UIView *contentView;
@property(nonatomic,strong) UIView *footerView;
@property(nonatomic,strong) UILabel *footerLabel;
@property(nonatomic,strong) NSMutableArray<UIButton *> *sidebarButtons;
@property(nonatomic,copy) NSArray<NSString *> *categories;
@property(nonatomic,copy) NSArray<NSString *> *categorySymbols;
@property(nonatomic,assign) NSInteger selectedCategory;
@property(nonatomic,weak) UIWindow *hostWindow;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,assign) CGRect lastBounds;
@property(nonatomic,assign) UIEdgeInsets lastInsets;
@property(nonatomic,assign) UIUserInterfaceStyle lastStyle;
@property(nonatomic,assign) BOOL uiReady;
@property(nonatomic,assign) BOOL compactMode;
@property(nonatomic,assign) BOOL autoSnap;
@property(nonatomic,assign) BOOL rememberPosition;
@property(nonatomic,assign) ZNThemeMode themeMode;
@property(nonatomic,strong) ZNTheme *theme;
@property(nonatomic,assign) CGFloat menuAlpha;
@end// UI_RELOCATED_END controller
#ifdef ZN_INTERNAL_UI_ALIAS_ADDED
#undef ZNRuntimeMenuControllerV024
#undef ZN_INTERNAL_UI_ALIAS_ADDED
#endif
@interface ZNRuntimeMenuControllerV040 (ZNInternalUIContract)
+ (instancetype)shared;
- (instancetype)init;
- (BOOL)enabledForFeature:(NSString *)featureID;
- (void)setFeature:(NSString *)featureID enabled:(BOOL)enabled;
- (CGFloat)valueForFeature:(NSString *)featureID fallback:(CGFloat)fallback;
- (void)setFeature:(NSString *)featureID value:(CGFloat)value;
- (UIWindow *)currentWindow;
- (UIUserInterfaceStyle)interfaceStyle;
- (UIFont *)menuFont:(CGFloat)size weight:(UIFontWeight)weight;
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color;
- (CGPoint)clampFloat:(CGPoint)c window:(UIWindow *)w;
- (CGPoint)clampPanel:(CGPoint)c window:(UIWindow *)w;
- (CGSize)fullSizeForWindow:(UIWindow *)w;
- (CGSize)compactSizeForWindow:(UIWindow *)w;
- (void)clearDecorations;
- (void)applyDecorations;
- (UIView *)cardAtY:(CGFloat)y height:(CGFloat)h width:(CGFloat)w compact:(BOOL)compact;
- (UISwitch *)switchForCard:(UIView *)card featureID:(NSString *)featureID compact:(BOOL)compact;
- (void)placeCompactSwitch:(UISwitch *)sw inCard:(UIView *)card centerY:(CGFloat)centerY;
- (void)addFullComposite:(NSString *)name featureID:(NSString *)featureID fallback:(CGFloat)fallback min:(CGFloat)min max:(CGFloat)max y:(CGFloat *)y width:(CGFloat)width;
- (void)addFullSwitch:(NSString *)name subtitle:(NSString *)subtitle featureID:(NSString *)featureID y:(CGFloat *)y width:(CGFloat)width;
- (void)addCompactComposite:(NSString *)name featureID:(NSString *)featureID fallback:(CGFloat)fallback min:(CGFloat)min max:(CGFloat)max y:(CGFloat *)y width:(CGFloat)width;
- (void)addCompactSwitch:(NSString *)name featureID:(NSString *)featureID y:(CGFloat *)y width:(CGFloat)width;
- (void)addSection:(NSString *)title subtitle:(NSString *)subtitle y:(CGFloat *)y width:(CGFloat)width;
- (void)addAlphaCardY:(CGFloat *)y width:(CGFloat)width;
- (void)addSettingSwitch:(NSString *)name subtitle:(NSString *)subtitle on:(BOOL)on selector:(SEL)selector y:(CGFloat *)y width:(CGFloat)width;
- (NSInteger)themeColumnsForWidth:(CGFloat)width;
- (void)addThemeGridY:(CGFloat *)y width:(CGFloat)width;
- (void)renderFullPage;
- (void)renderCompactPage;
- (void)renderPage;
- (void)updateSidebar;
- (void)layoutSidebar;
- (void)applyTheme;
- (void)layoutPanel;
- (void)layoutForWindow:(UIWindow *)window initial:(BOOL)initial;
- (void)makeUI:(UIWindow *)window;
- (void)attach:(UIWindow *)window;
- (void)tick:(NSTimer *)timer;
- (void)start;
- (void)show;
- (void)hide;
- (BOOL)isVisible;
- (void)togglePanel:(id)sender;
- (void)modeTapped:(id)sender;
- (void)closeTapped:(id)sender;
- (void)themeTapped:(id)sender;
- (void)themeGridTapped:(UIButton *)sender;
- (void)categoryTapped:(UIButton *)sender;
- (void)featureSwitchChanged:(UISwitch *)sender;
- (void)featureSliderChanged:(UISlider *)slider;
- (void)alphaSliderChanged:(UISlider *)slider;
- (void)autoSnapChanged:(UISwitch *)sender;
- (void)rememberPositionChanged:(UISwitch *)sender;
- (void)panFloat:(UIPanGestureRecognizer *)g;
- (void)panPanel:(UIPanGestureRecognizer *)g;
- (UIButton *)zn40_button:(NSString *)title selector:(SEL)selector frame:(CGRect)frame;
@end
