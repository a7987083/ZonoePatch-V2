#import <UIKit/UIKit.h>

// P9.3 compact Customer layout contract, shared by the view and window host.
static const CGFloat ZNCustomerTopInset=3.0;
static const CGFloat ZNCustomerBottomInset=5.0;
static const CGFloat ZNCustomerHeaderHeight=40.0;
static const CGFloat ZNCustomerDividerHeight=1.0;
static const CGFloat ZNCustomerRowHeight=44.0;
static const CGFloat ZNCustomerEmptyHeight=66.0;
static const CGFloat ZNCustomerRecoveryHeight=34.0;
static const NSUInteger ZNCustomerMaxVisibleRows=12;
static const CGFloat ZNCustomerTypedRowHeight=112.0;
static inline CGFloat ZNCustomerMixedContentHeight(NSUInteger toggles, NSUInteger typed, BOOL locked) {
 CGFloat rows=toggles*ZNCustomerRowHeight+typed*ZNCustomerTypedRowHeight;
 if(!toggles&&!typed)rows=ZNCustomerEmptyHeight;
 // Clamp to a scrollable viewport; do not clip interactive numeric controls.
 rows=MIN(rows,ZNCustomerTypedRowHeight*5.0);
 return ZNCustomerTopInset+ZNCustomerHeaderHeight+ZNCustomerDividerHeight+
        rows+ZNCustomerBottomInset+(locked&&(toggles||typed)?ZNCustomerRecoveryHeight:0.0);
}
static inline CGFloat ZNCustomerContentHeight(NSUInteger count, BOOL locked) {
 CGFloat rows=count?ZNCustomerRowHeight*MIN(ZNCustomerMaxVisibleRows,count):
                    ZNCustomerEmptyHeight;
 return ZNCustomerTopInset+ZNCustomerHeaderHeight+ZNCustomerDividerHeight+
        rows+ZNCustomerBottomInset+(locked&&count?ZNCustomerRecoveryHeight:0.0);
}

@interface ZNV3CustomerMenuController : UIViewController
@property(nonatomic,copy) void (^closeBlock)(void);
@property(nonatomic,copy) void (^layoutChangedBlock)(void);
@property(nonatomic,copy) void (^windowMovedBlock)(void);
@property(nonatomic,assign) UIInterfaceOrientationMask hostOrientationMask;
@property(nonatomic,assign,readonly) NSUInteger presentedFeatureCount;
@property(nonatomic,assign,readonly) NSUInteger presentedTypedFeatureCount;
@property(nonatomic,assign,readonly) BOOL presentedRecoveryLocked;
- (void)refreshFeatures;
@end
