#import <UIKit/UIKit.h>
@interface ZNV3CustomerMenuController : UIViewController
@property(nonatomic,copy) void (^closeBlock)(void);
@property(nonatomic,copy) void (^layoutChangedBlock)(void);
@property(nonatomic,assign) UIInterfaceOrientationMask hostOrientationMask;
- (void)refreshFeatures;
@end
