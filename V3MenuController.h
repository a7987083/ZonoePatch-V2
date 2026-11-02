#import <UIKit/UIKit.h>
#import "V3FeatureModels.h"
@interface ZNV3MenuController : UIViewController <UITextFieldDelegate>
@property(nonatomic,strong) UIScrollView *scroll;
@property(nonatomic,strong) UIStackView *body;
@property(nonatomic,strong) UIStackView *rules;
@property(nonatomic,strong) UIView *editor;
@property(nonatomic,strong) UITextField *nameField;
@property(nonatomic,strong) UITextField *descField;
@property(nonatomic,strong) UIButton *moduleButton;
@property(nonatomic,strong) UIButton *typeButton;
@property(nonatomic,strong) UIStackView *features;
@property(nonatomic,strong) ZNV3FeatureStore *store;
@property(nonatomic,assign) NSInteger ruleCount;
@property(nonatomic,assign) NSInteger moduleIndex;
@property(nonatomic,assign) NSInteger typeIndex;
@property(nonatomic,copy) void (^closeBlock)(void);
@end
@interface ZNV3MenuController (HookPage)
- (void)buildHookPage;
- (void)add:(UIView *)view height:(CGFloat)height;
- (UITextField *)field:(NSString *)hint value:(NSString *)value;
- (void)renderFeatures;
- (void)renderRules;
- (void)showEditor;
- (void)hideEditor;
- (void)addRuleTap;
- (void)removeRule:(UIButton *)sender;
- (void)cycleType;
- (void)preview;
- (void)saveUI;
- (void)categoryTap:(UIButton *)sender;
- (void)closeTap;
@end
