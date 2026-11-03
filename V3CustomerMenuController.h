#import <UIKit/UIKit.h>
@interface ZNV3CustomerMenuController : UIViewController
@property(nonatomic,copy) void (^closeBlock)(void);
@property(nonatomic,assign) UIInterfaceOrientationMask hostOrientationMask;
- (void)refreshFeatures;
@end
