#import "V3CustomerMenuController.h"
#import "V3CustomerRuntime.h"
#import "V3UIComponents.h"

@interface ZNV3CustomerMenuController ()
@property(nonatomic,strong) UIStackView *features;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) NSMutableArray<ZNV3CustomerFeature *> *snapshot;
@end
@implementation ZNV3CustomerMenuController
- (void)loadView{
 self.view=[UIView new];self.view.backgroundColor=[UIColor colorWithRed:.70 green:.08 blue:.18 alpha:.97];
 self.view.layer.cornerRadius=20;self.view.layer.masksToBounds=YES;
 self.view.layer.borderWidth=1;self.view.layer.borderColor=[UIColor colorWithRed:1 green:.40 blue:.50 alpha:.7].CGColor;
}
- (void)viewDidLoad{
 [super viewDidLoad];
 UIStackView *stack=[UIStackView new];stack.translatesAutoresizingMaskIntoConstraints=NO;
 stack.axis=UILayoutConstraintAxisVertical;stack.spacing=10;stack.layoutMargins=UIEdgeInsetsMake(16,15,16,15);
 stack.layoutMarginsRelativeArrangement=YES;[self.view addSubview:stack];
 [NSLayoutConstraint activateConstraints:@[
  [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
  [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
  [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
  [stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]]];
 UIStackView *bar=[UIStackView new];bar.axis=UILayoutConstraintAxisHorizontal;
 bar.distribution=UIStackViewDistributionEqualSpacing;bar.alignment=UIStackViewAlignmentCenter;
 UILabel *heading=ZNLabel(@"⚡ ZonoePatch",19,YES);heading.textColor=UIColor.whiteColor;
 [bar addArrangedSubview:heading];
 UIButton *close=ZNButton(@"✕",self,@selector(closeMenu));
 [bar addArrangedSubview:close];[stack addArrangedSubview:bar];
 [close setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
 [close.widthAnchor constraintEqualToConstant:40].active=YES;
 self.status=ZNLabel(@"扫描已安装的预埋功能",12,NO);
 self.status.textColor=[UIColor colorWithWhite:1 alpha:.78];[stack addArrangedSubview:self.status];
 UIScrollView *scroll=[UIScrollView new];[stack addArrangedSubview:scroll];
 self.features=[UIStackView new];self.features.axis=UILayoutConstraintAxisVertical;self.features.spacing=5;
 self.features.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:self.features];
 [NSLayoutConstraint activateConstraints:@[
  [self.features.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
  [self.features.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
  [self.features.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
  [self.features.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
  [self.features.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor]]];
 UIButton *refresh=ZNButton(@"刷新预埋功能",self,@selector(refreshFeatures));
 [stack addArrangedSubview:refresh];[refresh.heightAnchor constraintEqualToConstant:38].active=YES;
 [refresh setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
 [self refreshFeatures];
}
- (void)viewWillAppear:(BOOL)animated{
 [super viewWillAppear:animated];[self refreshFeatures];
}
- (void)closeMenu{if(self.closeBlock)self.closeBlock();}
- (void)showResult:(NSString *)title detail:(NSString *)detail{
 UIAlertController *a=[UIAlertController alertControllerWithTitle:title message:detail
   preferredStyle:UIAlertControllerStyleAlert];
 [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
 [self presentViewController:a animated:YES completion:nil];
}
- (void)refreshFeatures{
 for(UIView *v in self.features.arrangedSubviews){
  [self.features removeArrangedSubview:v];[v removeFromSuperview];
 }
 self.snapshot=[[[ZNV3CustomerRuntime shared] discover] mutableCopy];
 BOOL locked=[ZNV3CustomerRuntime shared].recoveryFailed;
 self.status.text=locked?@"静态事务回滚失败，已锁定":(
   self.snapshot.count?[NSString stringWithFormat:@"发现 %lu 个预埋功能（默认 OFF）",(unsigned long)self.snapshot.count]:
   @"未检测到 P6-C 预埋功能。请确认已安装生成后的 Mach-O。");
 for(NSUInteger i=0;i<self.snapshot.count;i++){
  ZNV3CustomerFeature *feature=self.snapshot[i];
  UIView *panel=[UIView new];panel.backgroundColor=[UIColor colorWithRed:.94 green:.13 blue:.27 alpha:.78];
  panel.layer.cornerRadius=12;panel.layer.borderWidth=1;
  panel.layer.borderColor=[UIColor colorWithRed:1 green:.45 blue:.55 alpha:.48].CGColor;
  UIStackView *row=[UIStackView new];row.axis=UILayoutConstraintAxisVertical;row.spacing=5;
  row.translatesAutoresizingMaskIntoConstraints=NO;[panel addSubview:row];
  [NSLayoutConstraint activateConstraints:@[
    [row.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:10],
    [row.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-10],
    [row.topAnchor constraintEqualToAnchor:panel.topAnchor constant:10],
    [row.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-10]]];
  UILabel *name=ZNLabel([@"⚡ " stringByAppendingString:feature.title?:@""],14,YES);
  name.textColor=UIColor.whiteColor;[row addArrangedSubview:name];
  UILabel *subtitle=ZNLabel([NSString stringWithFormat:@"%@ · %lu 组 Patch",
    feature.imageName,(unsigned long)feature.ruleCount],11,NO);
  subtitle.textColor=[UIColor colorWithWhite:1 alpha:.78];[row addArrangedSubview:subtitle];
  UIButton *button=ZNButton(feature.enabled?@"关闭（Original）":@"开启 Patch",self,@selector(toggleFeature:));
  button.tag=(NSInteger)i;button.enabled=!locked;
  [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  button.backgroundColor=feature.enabled?[UIColor colorWithRed:.24 green:.66 blue:.41 alpha:.9]:[UIColor colorWithRed:.45 green:.05 blue:.15 alpha:.8];
  button.layer.borderColor=[UIColor colorWithWhite:1 alpha:.4].CGColor;
  [row addArrangedSubview:button];[button.heightAnchor constraintEqualToConstant:38].active=YES;
  [self.features addArrangedSubview:panel];
 }
}
- (void)toggleFeature:(UIButton *)button{
 NSUInteger index=(NSUInteger)button.tag;
 if(index>=self.snapshot.count)return;
 ZNV3CustomerFeature *feature=self.snapshot[index];
 NSError *error=nil;
 BOOL enabled=!feature.enabled;
 BOOL ok=[[ZNV3CustomerRuntime shared]setEnabled:enabled feature:feature error:&error];
 [self refreshFeatures];
 [self showResult:ok?(enabled?@"Patch 已启用":@"Original 已恢复"):@"操作失败"
   detail:ok?@"仅切换已预埋的可写指针，未修改 RX 代码页。":
   error.localizedDescription?:[ZNV3CustomerRuntime shared].lastDiagnostic];
}
@end
