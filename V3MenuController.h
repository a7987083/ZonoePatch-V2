#import <UIKit/UIKit.h>
#import "V3FeatureModels.h"
@interface ZNV3MenuController : UIViewController <UITextFieldDelegate>
@property(nonatomic,strong) UIScrollView *scroll;
@property(nonatomic,strong) UIStackView *body;
@property(nonatomic,strong) UIStackView *rules;
@property(nonatomic,strong) UILabel *rulesTitleLabel;
@property(nonatomic,strong) UIButton *addRuleButton;
@property(nonatomic,strong) UIView *editor;
@property(nonatomic,strong) UITextField *nameField;
@property(nonatomic,strong) UITextField *descField;
@property(nonatomic,strong) UIButton *moduleButton;
@property(nonatomic,strong) UILabel *moduleStatus;
@property(nonatomic,strong) UIButton *typeButton;
@property(nonatomic,strong) UIStackView *parameterFields;
@property(nonatomic,strong) UIButton *valueTypeButton;
@property(nonatomic,strong) UITextField *minimumField;
@property(nonatomic,strong) UITextField *maximumField;
@property(nonatomic,strong) UILabel *stepLabel;
@property(nonatomic,strong) UITextField *stepField;
@property(nonatomic,strong) UILabel *defaultLabel;
@property(nonatomic,strong) UILabel *sliderHintLabel;
@property(nonatomic,strong) UITextField *defaultField;
@property(nonatomic,strong) UIButton *patchActionButton;
@property(nonatomic,strong) UIButton *staticBuildButton;
@property(nonatomic,assign) BOOL staticBuildRunning;
@property(nonatomic,copy) NSString *selectedFeatureID;
@property(nonatomic,strong) NSMutableOrderedSet<NSString *> *selectedFeatureIDs;
@property(nonatomic,assign) BOOL featureRowsCompact;
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
- (void)selectFeature:(UIButton *)sender;
- (void)toggleFeaturePatch:(UIButton *)sender;
- (void)refreshModuleStatus;
- (void)categoryTap:(UIButton *)sender;
- (void)closeTap;
@end
@interface ZNV3MenuController (FeatureEditor)
- (void)renderRules;
- (void)refreshStaticBuildButton;
- (void)showPatchMessage:(NSString *)title detail:(NSString *)detail;
- (BOOL)draftMatchesSavedPatch:(ZNV3Feature *)saved;
- (void)showEditor;
- (void)editFeatureAtIndex:(NSUInteger)index;
- (void)hideEditor;
- (void)addRuleTap;
- (void)removeRule:(UIButton *)sender;
- (void)cycleType;
- (void)cycleValueType;
- (void)updateParameterControls;
- (void)applyOrRestore;
- (void)generateStaticBinary;
- (void)refreshPatchActionButton;
- (void)staticBuildInputChanged:(UITextField *)sender;
- (void)saveUI;
@end
