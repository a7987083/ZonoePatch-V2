#import "V3CustomerMenuController.h"
#import "V3CustomerRuntime.h"
#import "V3UIComponents.h"
#import <QuartzCore/QuartzCore.h>

// P9 Customer: one controller, one scene window, no stacked overlay or shadow menu.
@interface ZNV3CustomerMenuController ()
@property(nonatomic,strong) UIStackView *features;
@property(nonatomic,strong) UIScrollView *featureScroll;
@property(nonatomic,strong) NSMutableArray<ZNV3CustomerFeature *> *snapshot;
@property(nonatomic,strong) CAGradientLayer *neonBorder;
@property(nonatomic,strong) CAShapeLayer *neonBorderMask;
@end

@implementation ZNV3CustomerMenuController

- (void)loadView {
 self.view=[UIView new];
 self.view.backgroundColor=[UIColor colorWithRed:.035 green:.045 blue:.115 alpha:.97];
 self.view.layer.cornerRadius=22;
 self.view.layer.masksToBounds=YES;
}

- (void)viewDidLoad {
 [super viewDidLoad];

 CAGradientLayer *border=[CAGradientLayer layer];
 border.colors=@[(id)[UIColor colorWithRed:.89 green:.20 blue:1 alpha:1].CGColor,
                 (id)[UIColor colorWithRed:.12 green:.75 blue:1 alpha:1].CGColor,
                 (id)[UIColor colorWithRed:.72 green:.14 blue:1 alpha:1].CGColor,
                 (id)[UIColor colorWithRed:.13 green:.48 blue:1 alpha:1].CGColor];
 border.startPoint=CGPointMake(0,0);border.endPoint=CGPointMake(1,1);
 CAShapeLayer *outline=[CAShapeLayer layer];
 outline.fillColor=UIColor.clearColor.CGColor;
 outline.strokeColor=UIColor.whiteColor.CGColor;
 outline.lineWidth=3;
 border.mask=outline;
 [self.view.layer addSublayer:border];
 self.neonBorder=border;self.neonBorderMask=outline;

 UIStackView *stack=[UIStackView new];
 stack.translatesAutoresizingMaskIntoConstraints=NO;
 stack.axis=UILayoutConstraintAxisVertical;stack.spacing=12;
 stack.layoutMargins=UIEdgeInsetsMake(18,18,18,18);
 stack.layoutMarginsRelativeArrangement=YES;
 [self.view addSubview:stack];
 [NSLayoutConstraint activateConstraints:@[
  [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
  [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
  [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
  [stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]]];

 UIStackView *header=[UIStackView new];
 header.axis=UILayoutConstraintAxisHorizontal;
 header.alignment=UIStackViewAlignmentCenter;header.spacing=12;
 [stack addArrangedSubview:header];
 [header.heightAnchor constraintEqualToConstant:62].active=YES;

 UIImageView *icon=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"gamecontroller.fill"]];
 icon.tintColor=[UIColor colorWithRed:1 green:.45 blue:.97 alpha:1];
 icon.contentMode=UIViewContentModeScaleAspectFit;
 [header addArrangedSubview:icon];
 [icon.widthAnchor constraintEqualToConstant:46].active=YES;
 [icon.heightAnchor constraintEqualToConstant:40].active=YES;

 UILabel *title=ZNLabel(@"ZonoePatch",17,YES);
 title.textColor=UIColor.whiteColor;title.numberOfLines=1;
 title.adjustsFontSizeToFitWidth=YES;title.minimumScaleFactor=.75;
 [header addArrangedSubview:title];

 UIButton *close=[UIButton buttonWithType:UIButtonTypeSystem];
 [close setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
 close.tintColor=[UIColor colorWithWhite:.87 alpha:1];
 close.accessibilityLabel=@"关闭菜单";
 [close addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
 [header addArrangedSubview:close];
 [close.widthAnchor constraintEqualToConstant:38].active=YES;
 [close.heightAnchor constraintEqualToConstant:42].active=YES;

 UIView *divider=[UIView new];
 divider.backgroundColor=[UIColor colorWithRed:.55 green:.22 blue:.94 alpha:.8];
 [stack addArrangedSubview:divider];
 [divider.heightAnchor constraintEqualToConstant:1].active=YES;

 UIScrollView *scroll=[UIScrollView new];
 scroll.alwaysBounceVertical=NO;
 scroll.showsVerticalScrollIndicator=NO;
 self.featureScroll=scroll;
 [stack addArrangedSubview:scroll];
 self.features=[UIStackView new];
 self.features.axis=UILayoutConstraintAxisVertical;
 self.features.spacing=9;
 self.features.translatesAutoresizingMaskIntoConstraints=NO;
 [scroll addSubview:self.features];
 [NSLayoutConstraint activateConstraints:@[
  [self.features.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
  [self.features.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
  [self.features.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
  [self.features.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
  [self.features.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor]]];

 [self refreshFeatures];
}

- (void)viewDidLayoutSubviews {
 [super viewDidLayoutSubviews];
 CGRect bounds=self.view.bounds;
 [CATransaction begin];
 [CATransaction setDisableActions:YES];
 self.neonBorder.frame=bounds;
 self.neonBorderMask.frame=bounds;
 self.neonBorderMask.path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(bounds,2,2)
  cornerRadius:20].CGPath;
 [CATransaction commit];
}

- (void)viewWillAppear:(BOOL)animated {
 [super viewWillAppear:animated];
 [self refreshFeatures];
}

- (void)closeMenu {if(self.closeBlock)self.closeBlock();}

- (void)showError:(NSString *)message {
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"功能切换失败"
  message:message preferredStyle:UIAlertControllerStyleAlert];
 [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
 [self presentViewController:alert animated:YES completion:nil];
}

- (void)refreshFeatures {
 if(!self.isViewLoaded||!self.features)return;
 for(UIView *view in [self.features.arrangedSubviews copy]) {
  [self.features removeArrangedSubview:view];[view removeFromSuperview];
 }
 self.snapshot=[[[ZNV3CustomerRuntime shared] discover] mutableCopy];
 BOOL locked=[ZNV3CustomerRuntime shared].recoveryFailed;
 if(!self.snapshot.count||locked) {
  UILabel *message=ZNLabel(locked?@"静态 Patch 恢复失败，开关已锁定":@"暂无可用功能",13,NO);
  message.textAlignment=NSTextAlignmentCenter;
  message.textColor=[UIColor colorWithWhite:1 alpha:.75];
  [self.features addArrangedSubview:message];
  [message.heightAnchor constraintEqualToConstant:66].active=YES;
 }
 NSArray<NSString *> *symbols=@[@"bolt.fill",@"crown.fill",@"ticket.fill",@"gift.fill"];
 NSArray<UIColor *> *iconColors=@[
  [UIColor colorWithRed:1 green:.74 blue:.18 alpha:1],
  [UIColor colorWithRed:1 green:.81 blue:.30 alpha:1],
  [UIColor colorWithRed:1 green:.39 blue:.72 alpha:1],
  [UIColor colorWithRed:.93 green:.38 blue:1 alpha:1]];
 for(NSUInteger i=0;i<self.snapshot.count;i++) {
  ZNV3CustomerFeature *feature=self.snapshot[i];
  UIView *panel=[UIView new];
  panel.backgroundColor=[UIColor colorWithRed:.055 green:.062 blue:.17 alpha:.97];
  panel.layer.cornerRadius=12;
  panel.layer.borderWidth=1;
  panel.layer.borderColor=[UIColor colorWithRed:.47 green:.25 blue:.84 alpha:.75].CGColor;
  [self.features addArrangedSubview:panel];
  [panel.heightAnchor constraintEqualToConstant:55].active=YES;

  UIStackView *row=[UIStackView new];
  row.axis=UILayoutConstraintAxisHorizontal;
  row.alignment=UIStackViewAlignmentCenter;
  row.spacing=10;
  row.translatesAutoresizingMaskIntoConstraints=NO;
  [panel addSubview:row];
  [NSLayoutConstraint activateConstraints:@[
   [row.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:12],
   [row.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-11],
   [row.topAnchor constraintEqualToAnchor:panel.topAnchor constant:7],
   [row.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-7]]];

  NSUInteger style=i%symbols.count;
  UIImageView *glyph=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:symbols[style]]];
  glyph.contentMode=UIViewContentModeScaleAspectFit;
  glyph.tintColor=iconColors[style];
  [row addArrangedSubview:glyph];
  [glyph.widthAnchor constraintEqualToConstant:26].active=YES;
  [glyph.heightAnchor constraintEqualToConstant:25].active=YES;

  UILabel *name=ZNLabel(feature.title?:@"",14,NO);
  name.textColor=UIColor.whiteColor;
  name.numberOfLines=1;name.lineBreakMode=NSLineBreakByTruncatingTail;
  [name setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
    forAxis:UILayoutConstraintAxisHorizontal];
  [row addArrangedSubview:name];

  UISwitch *toggle=[UISwitch new];
  toggle.on=feature.enabled;
  toggle.tag=(NSInteger)i;
  toggle.enabled=!locked;
  toggle.onTintColor=[UIColor colorWithRed:.73 green:.19 blue:.98 alpha:1];
  toggle.tintColor=[UIColor colorWithRed:.40 green:.42 blue:.63 alpha:1];
  toggle.thumbTintColor=UIColor.whiteColor;
  toggle.accessibilityLabel=feature.title;
  [toggle addTarget:self action:@selector(toggleFeature:) forControlEvents:UIControlEventValueChanged];
  [row addArrangedSubview:toggle];
 }
}

- (void)toggleFeature:(UISwitch *)toggle {
 NSUInteger index=(NSUInteger)toggle.tag;
 if(index>=self.snapshot.count){[self refreshFeatures];return;}
 ZNV3CustomerFeature *feature=self.snapshot[index];
 NSError *error=nil;
 BOOL ok=[[ZNV3CustomerRuntime shared] setEnabled:toggle.isOn feature:feature error:&error];
 [self refreshFeatures];
 // Successful switches are silent; errors remain visible and never imply success.
 if(!ok)[self showError:error.localizedDescription?:[ZNV3CustomerRuntime shared].lastDiagnostic];
}
@end
