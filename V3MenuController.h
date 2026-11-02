#import <UIKit/UIKit.h>
@interface ZNV3MenuController : UIViewController <UITextFieldDelegate>
@property(nonatomic,copy) void (^closeBlock)(void);
@end
