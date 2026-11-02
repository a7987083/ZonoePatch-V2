#import <UIKit/UIKit.h>
#import "V3FeatureModels.h"

static UIColor *ZNBlue(void) { return [UIColor colorWithRed:.10 green:.43 blue:.94 alpha:1]; }
static UILabel *ZNLabel(NSString *s,CGFloat size,BOOL bold) {
 UILabel *v=[UILabel new];v.text=s;v.font=bold?[UIFont boldSystemFontOfSize:size]:[UIFont systemFontOfSize:size];
 v.numberOfLines=0;return v;
}
static UIButton *ZNButton(NSString *s,id target,SEL sel) {
 UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];[b setTitle:s forState:UIControlStateNormal];
 b.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
 b.layer.cornerRadius=8;b.layer.borderColor=[UIColor colorWithWhite:.84 alpha:1].CGColor;b.layer.borderWidth=1;
 [b addTarget:target action:sel forControlEvents:UIControlEventTouchUpInside];return b;
}
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
@property(nonatomic,copy) void(^closeBlock)(void);
@end
@implementation ZNV3MenuController
- (void)loadView {self.view=[UIView new];self.view.backgroundColor=[UIColor colorWithWhite:.97 alpha:1];}
- (void)viewDidLoad {
 [super viewDidLoad];
 UIView *head=[UIView new];head.backgroundColor=UIColor.whiteColor;head.translatesAutoresizingMaskIntoConstraints=NO;
 [self.view addSubview:head];
 UILabel *title=ZNLabel(@"ZonoePatch V3",19,YES);title.translatesAutoresizingMaskIntoConstraints=NO;[head addSubview:title];
 UIButton *close=ZNButton(@"✕",self,@selector(closeTap));close.translatesAutoresizingMaskIntoConstraints=NO;[head addSubview:close];
 UIView *side=[UIView new];side.backgroundColor=[UIColor colorWithWhite:.94 alpha:1];side.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:side];
 UIStackView *categories=[UIStackView new];categories.axis=UILayoutConstraintAxisVertical;categories.spacing=7;
 categories.translatesAutoresizingMaskIntoConstraints=NO;[side addSubview:categories];
 NSArray *names=@[@"Hook",@"运行时补丁",@"静态构建",@"日志",@"设置"];
 for(NSInteger i=0;i<names.count;i++){
    UIButton *b=ZNButton(names[i],self,@selector(categoryTap:));b.tag=i;
    b.titleLabel.font=[UIFont systemFontOfSize:12];b.backgroundColor=i==0?[UIColor colorWithRed:.84 green:.90 blue:1 alpha:1]:UIColor.clearColor;
    [categories addArrangedSubview:b];[b.heightAnchor constraintEqualToConstant:43].active=YES;
 }
 self.scroll=[UIScrollView new];self.scroll.translatesAutoresizingMaskIntoConstraints=NO;self.scroll.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;[self.view addSubview:self.scroll];
 self.body=[UIStackView new];self.body.axis=UILayoutConstraintAxisVertical;self.body.spacing=12;self.body.translatesAutoresizingMaskIntoConstraints=NO;[self.scroll addSubview:self.body];
 [NSLayoutConstraint activateConstraints:@[
 [head.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
 [head.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[head.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],[head.heightAnchor constraintEqualToConstant:56],
 [title.leadingAnchor constraintEqualToAnchor:head.leadingAnchor constant:16],[title.centerYAnchor constraintEqualToAnchor:head.centerYAnchor],
 [close.trailingAnchor constraintEqualToAnchor:head.trailingAnchor constant:-12],[close.centerYAnchor constraintEqualToAnchor:head.centerYAnchor],[close.widthAnchor constraintEqualToConstant:42],[close.heightAnchor constraintEqualToConstant:36],
 [side.topAnchor constraintEqualToAnchor:head.bottomAnchor],[side.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[side.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],[side.widthAnchor constraintEqualToConstant:104],
 [categories.topAnchor constraintEqualToAnchor:side.topAnchor constant:15],[categories.leadingAnchor constraintEqualToAnchor:side.leadingAnchor constant:5],[categories.trailingAnchor constraintEqualToAnchor:side.trailingAnchor constant:-5],
 [self.scroll.leadingAnchor constraintEqualToAnchor:side.trailingAnchor],[self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],[self.scroll.topAnchor constraintEqualToAnchor:head.bottomAnchor],[self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
 [self.body.leadingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.leadingAnchor constant:10],
 [self.body.trailingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.trailingAnchor constant:-10],
 [self.body.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:12],
 [self.body.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-20],
 [self.body.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor constant:-20]]];
 self.store=[ZNV3FeatureStore new];
 [self buildHookPage];
}
- (void)add:(UIView *)v height:(CGFloat)h {
 [self.body addArrangedSubview:v];if(h>0)[v.heightAnchor constraintGreaterThanOrEqualToConstant:h].active=YES;
}
- (UITextField *)field:(NSString *)hint value:(NSString *)value {
 UITextField *f=[UITextField new];f.borderStyle=UITextBorderStyleRoundedRect;f.placeholder=hint;f.text=value;f.font=[UIFont systemFontOfSize:13];
 f.backgroundColor=UIColor.whiteColor;f.delegate=self;[f.heightAnchor constraintEqualToConstant:36].active=YES;return f;
}
- (void)addField:(NSString *)label value:(NSString *)value store:(UITextField **)out {
 UILabel *l=ZNLabel(label,12,YES);[self add:l height:0];UITextField *f=[self field:label value:value];[self add:f height:36];
 if(out)*out=f;
}
- (void)buildHookPage {
 [self add:ZNLabel(@"Hook 管理",18,YES) height:28];
 [self add:ZNLabel(@"目标模块（UI 演示，未执行识别）",12,NO) height:20];
 self.moduleButton=ZNButton(@"主程序  ▾",self,@selector(cycleModule));[self add:self.moduleButton height:38];
 [self add:ZNLabel(@"可选模块：主程序 / UnityFramework",11,NO) height:18];
 [self add:ZNLabel(@"当前功能（演示）",14,YES) height:24];
 self.features=[UIStackView new];self.features.axis=UILayoutConstraintAxisVertical;self.features.spacing=6;[self add:self.features height:0];
 [self renderFeatures];
 UIButton *newItem=ZNButton(@"＋ 增加功能",self,@selector(showEditor));newItem.tintColor=ZNBlue();[self add:newItem height:44];
 UIView *panel=[UIView new];panel.backgroundColor=UIColor.whiteColor;panel.layer.cornerRadius=10;panel.layer.borderWidth=1;panel.layer.borderColor=ZNBlue().CGColor;
 self.editor=panel;[self add:panel height:0];
 UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=8;stack.translatesAutoresizingMaskIntoConstraints=NO;[panel addSubview:stack];
 [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:9],
 [stack.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-9],[stack.topAnchor constraintEqualToAnchor:panel.topAnchor constant:12],
 [stack.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-12]]];
 [stack addArrangedSubview:ZNLabel(@"新增功能",15,YES)];
 [stack addArrangedSubview:ZNLabel(@"功能名字",12,YES)];
 self.nameField=[self field:@"功能名字" value:@""];[stack addArrangedSubview:self.nameField];
 [stack addArrangedSubview:ZNLabel(@"功能说明",12,YES)];
 self.descField=[self field:@"功能说明" value:@""];[stack addArrangedSubview:self.descField];
 [stack addArrangedSubview:ZNLabel(@"Offset / Patch 规则（支持多组）",12,YES)];
 self.rules=[UIStackView new];self.rules.axis=UILayoutConstraintAxisVertical;self.rules.spacing=7;[stack addArrangedSubview:self.rules];
 UIButton *addRule=ZNButton(@"＋ 添加一组 Offset / Patch",self,@selector(addRuleTap));[stack addArrangedSubview:addRule];[addRule.heightAnchor constraintEqualToConstant:36].active=YES;
 [stack addArrangedSubview:ZNLabel(@"按钮类型",12,YES)];
 self.typeButton=ZNButton(@"开关  ▾",self,@selector(cycleType));[stack addArrangedSubview:self.typeButton];[self.typeButton.heightAnchor constraintEqualToConstant:36].active=YES;
 UIStackView *actions=[UIStackView new];actions.axis=UILayoutConstraintAxisHorizontal;actions.distribution=UIStackViewDistributionFillEqually;actions.spacing=5;[stack addArrangedSubview:actions];
 UIButton *cancel=ZNButton(@"取消",self,@selector(hideEditor));UIButton *test=ZNButton(@"预览",self,@selector(preview));UIButton *save=ZNButton(@"保存",self,@selector(saveUI));
 for(UIButton *button in @[cancel,test,save]){[actions addArrangedSubview:button];[button.heightAnchor constraintEqualToConstant:38].active=YES;}
 self.editor.hidden=YES;

}
- (void)renderFeatures {
 for(UIView *v in self.features.arrangedSubviews){[self.features removeArrangedSubview:v];[v removeFromSuperview];}
 for(NSUInteger i=0;i<self.store.features.count;i++){
 ZNV3Feature *f=self.store.features[i];
 UIStackView *row=[UIStackView new];row.axis=UILayoutConstraintAxisHorizontal;
 row.alignment=UIStackViewAlignmentCenter;row.spacing=6;
 row.layoutMargins=UIEdgeInsetsMake(7,8,7,5);row.layoutMarginsRelativeArrangement=YES;
 row.backgroundColor=[UIColor colorWithWhite:.95 alpha:1];row.layer.cornerRadius=7;
 NSString *detail=f.rules.count?[NSString stringWithFormat:@"%@ · %lu 组规则 · UI 示例",f.module,(unsigned long)f.rules.count]:f.detail;
 UILabel *l=ZNLabel([NSString stringWithFormat:@"◯  %@\n     %@",f.name,detail],13,NO);
 [l setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];[row addArrangedSubview:l];
 UIButton *b=ZNButton(@"删除",self,@selector(removeFeature:));b.tag=(NSInteger)i;
 b.accessibilityLabel=[NSString stringWithFormat:@"删除功能 %@",f.name];
 [b.widthAnchor constraintEqualToConstant:55].active=YES;[b.heightAnchor constraintEqualToConstant:34].active=YES;[row addArrangedSubview:b];
 [row.heightAnchor constraintGreaterThanOrEqualToConstant:60].active=YES;[self.features addArrangedSubview:row];
 }
}
- (void)removeFeature:(UIButton *)sender {
 [self.store deleteFeatureAtIndex:(NSUInteger)sender.tag];[self renderFeatures];
}
- (void)renderRules {
 for(UIView *v in self.rules.arrangedSubviews){[self.rules removeArrangedSubview:v];[v removeFromSuperview];}
 for(NSUInteger i=0;i<self.store.draft.rules.count;i++){
 ZNV3PatchRule *r=self.store.draft.rules[i];
 UIStackView *box=[UIStackView new];box.axis=UILayoutConstraintAxisVertical;box.spacing=4;
 box.layer.cornerRadius=7;box.backgroundColor=[UIColor colorWithWhite:.96 alpha:1];
 UIStackView *bar=[UIStackView new];bar.axis=UILayoutConstraintAxisHorizontal;
 UILabel *l=ZNLabel([NSString stringWithFormat:@"规则 %lu",(unsigned long)i+1],12,YES);
 UIButton *b=ZNButton(@"删除",self,@selector(removeRule:));b.tag=(NSInteger)i;
 [bar addArrangedSubview:l];[bar addArrangedSubview:b];
 [b.widthAnchor constraintEqualToConstant:50].active=YES;[b.heightAnchor constraintEqualToConstant:27].active=YES;
 [box addArrangedSubview:bar];
 UITextField *offset=[self field:@"Offset，例如 0x105A3C" value:r.offsetText];offset.tag=1000+(NSInteger)i;
 [offset addTarget:self action:@selector(ruleTextChanged:) forControlEvents:UIControlEventEditingChanged];
 UITextField *patch=[self field:@"Patch，例如 00 00 80 D2" value:r.patchText];patch.tag=2000+(NSInteger)i;
 [patch addTarget:self action:@selector(ruleTextChanged:) forControlEvents:UIControlEventEditingChanged];
 [box addArrangedSubview:offset];[box addArrangedSubview:patch];[self.rules addArrangedSubview:box];
 }
}
- (void)ruleTextChanged:(UITextField *)field {
 NSUInteger index=(NSUInteger)(field.tag%1000);
 if(index>=self.store.draft.rules.count)return;
 ZNV3PatchRule *r=self.store.draft.rules[index];
 if(field.tag>=2000)r.patchText=field.text?:@"";else r.offsetText=field.text?:@"";
}
- (void)addRuleTap {
 if(!self.store.draft)return;
 [self.store.draft.rules addObject:[ZNV3PatchRule emptyRule]];
 [self renderRules];
}
- (void)removeRule:(UIButton *)sender {
 [self.store deleteRuleAtIndex:(NSUInteger)sender.tag];[self renderRules];
}
- (void)showEditor {
 [self.store beginDraftForModule:self.moduleIndex==0?@"主程序":@"UnityFramework"];
 self.nameField.text=@"";self.descField.text=@"";
 self.typeIndex=0;[self.typeButton setTitle:@"开关  ▾" forState:UIControlStateNormal];
 [self renderRules];self.editor.hidden=NO;
 [self.scroll layoutIfNeeded];[self.scroll scrollRectToVisible:self.editor.frame animated:YES];
}
- (void)hideEditor {self.editor.hidden=YES;self.store.draft=nil;[self.view endEditing:YES];}

- (void)cycleModule {
 self.moduleIndex=(self.moduleIndex+1)%2;
 [self.moduleButton setTitle:self.moduleIndex==0?@"主程序  ▾":@"UnityFramework  ▾" forState:UIControlStateNormal];
}
- (void)cycleType {
 self.typeIndex=(self.typeIndex+1)%3;
 [self.typeButton setTitle:(@[@"开关  ▾",@"点击按钮  ▾",@"输入框  ▾"])[self.typeIndex] forState:UIControlStateNormal];
}
- (void)preview {
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"UI 预览" message:@"这里只演示表单，不执行任何 Patch / Hook。" preferredStyle:UIAlertControllerStyleAlert];
 [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
 [self presentViewController:a animated:YES completion:nil];
}
- (void)saveUI {
 NSString *name=self.nameField.text.length?self.nameField.text:@"未命名功能";
 self.store.draft.name=name;
 self.store.draft.detail=self.descField.text?:@"";
 self.store.draft.buttonType=self.typeIndex;
 [self.store saveDraft];
 [self renderFeatures];[self hideEditor];
}
- (void)categoryTap:(UIButton *)b {
 if(b.tag==0)return;
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"UI 演示" message:@"当前仅实现 Hook 分类的可交互界面。" preferredStyle:UIAlertControllerStyleAlert];
 [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
 [self presentViewController:a animated:YES completion:nil];
}
- (void)closeTap {if(self.closeBlock)self.closeBlock();}
@end

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
