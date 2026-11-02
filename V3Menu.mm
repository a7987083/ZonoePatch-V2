#import <UIKit/UIKit.h>
#import "V3FeatureModels.h"
#import "V3MenuController.h"

#import "V3UIComponents.h"

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
@end
