#import "V3MenuController.h"
#import "V3UIComponents.h"
#import "V3ModuleResolver.h"
#import "V3PatchSession.h"
#import "V3StaticDispatchRuntime.h"

@implementation ZNV3MenuController (HookPage)
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
 [self add:ZNLabel(@"目标模块（新增 / 编辑 / 预检 / 保存共用）",12,NO) height:20];
 self.moduleButton=ZNButton(@"主程序  ▾",self,@selector(cycleModule));[self add:self.moduleButton height:38];
 self.moduleStatus=ZNLabel(@"正在识别模块…",11,NO);[self add:self.moduleStatus height:38];
 [self refreshModuleStatus];
 if(self.store.quarantinedFeatureCount){
  [self add:ZNLabel([NSString stringWithFormat:@"⚠️ %lu 个旧版功能格式不兼容：已原样保留在 JSON 中，未启用或覆盖。",(unsigned long)self.store.quarantinedFeatureCount],11,NO) height:38];
 }
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
 UIButton *cancel=ZNButton(@"取消",self,@selector(hideEditor));self.patchActionButton=ZNButton(@"应用 Patch",self,@selector(applyOrRestore));UIButton *save=ZNButton(@"保存",self,@selector(saveUI));
 for(UIButton *button in @[cancel,self.patchActionButton,save]){[actions addArrangedSubview:button];[button.heightAnchor constraintEqualToConstant:38].active=YES;}
 UIButton *staticPreflight=ZNButton(@"静态生成预检（只读）",self,@selector(staticBuildPreflight));
 [stack addArrangedSubview:staticPreflight];
 [staticPreflight.heightAnchor constraintEqualToConstant:38].active=YES;
 self.staticBuildButton=ZNButton(@"生成预埋二进制（初始 OFF）",self,@selector(generateStaticBinary));
 [stack addArrangedSubview:self.staticBuildButton];
 [self.staticBuildButton.heightAnchor constraintEqualToConstant:38].active=YES;
 self.staticToggleButton=ZNButton(@"启用预埋静态 Patch",self,@selector(toggleStaticPatch));
 [stack addArrangedSubview:self.staticToggleButton];
 [self.staticToggleButton.heightAnchor constraintEqualToConstant:38].active=YES;
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
 UIButton *edit=ZNButton(@"编辑",self,@selector(editFeature:));edit.tag=(NSInteger)i;
 [edit.widthAnchor constraintEqualToConstant:48].active=YES;[edit.heightAnchor constraintEqualToConstant:34].active=YES;[row addArrangedSubview:edit];
 UIButton *b=ZNButton(@"删除",self,@selector(removeFeature:));b.tag=(NSInteger)i;
 b.accessibilityLabel=[NSString stringWithFormat:@"删除功能 %@",f.name];
 [b.widthAnchor constraintEqualToConstant:55].active=YES;[b.heightAnchor constraintEqualToConstant:34].active=YES;[row addArrangedSubview:b];
 [row.heightAnchor constraintGreaterThanOrEqualToConstant:60].active=YES;[self.features addArrangedSubview:row];
 }
}
- (void)editFeature:(UIButton *)sender { [self editFeatureAtIndex:(NSUInteger)sender.tag]; }
- (void)removeFeature:(UIButton *)sender {
 if((NSUInteger)sender.tag>=self.store.features.count)return;
 if([ZNV3PatchSession shared].status==ZNV3PatchTransactionStatusRecoveryFailed){
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"执行器故障锁定"
   message:[ZNV3PatchSession shared].lastDiagnostic preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];return;
 }
 ZNV3Feature *target=self.store.features[(NSUInteger)sender.tag];
 if([ZNV3StaticDispatchRuntime shared].recoveryFailed){
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"静态 Patch 故障锁定"
     message:[ZNV3StaticDispatchRuntime shared].lastDiagnostic preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];return;
 }
 if([[ZNV3StaticDispatchRuntime shared] isEnabledForFeature:target.identifier]){
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"静态 Patch 正在生效"
    message:@"请先关闭预埋静态 Patch，再删除功能。" preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];return;
 }
 if([[ZNV3PatchSession shared] isActiveFeature:target.identifier]){
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"功能正在应用 Patch"
   message:@"请先进入编辑器恢复 Original，再删除该功能。" preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];return;
 }
 if(![self.store deleteFeatureAtIndex:(NSUInteger)sender.tag]) {
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"删除失败"
    message:self.store.lastError.localizedDescription?:@"配置保存不可用"
    preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];return;
 }
 [self renderFeatures];
}
- (void)refreshModuleStatus {
 NSString *name=self.moduleIndex==0?@"主程序":@"UnityFramework";
 ZNV3ModuleInfo *info=[ZNV3ModuleResolver resolveModule:name];
 if(!info){self.moduleStatus.text=[NSString stringWithFormat:@"%@ · 未加载（仅诊断）",name];return;}
 self.moduleStatus.text=[NSString stringWithFormat:@"%@ · 已加载 · Base 0x%llX · Slide 0x%llX",name,(unsigned long long)info.imageBase,(unsigned long long)(uint64_t)info.slide];
}
- (void)cycleModule {
 if(self.store.draft && ([[ZNV3PatchSession shared] isActiveFeature:self.store.draft.identifier]||
    [[ZNV3StaticDispatchRuntime shared] isEnabledForFeature:self.store.draft.identifier]))return;
 self.moduleIndex=(self.moduleIndex+1)%2;
 [self.moduleButton setTitle:self.moduleIndex==0?@"主程序  ▾":@"UnityFramework  ▾" forState:UIControlStateNormal];
 [self refreshModuleStatus];
 if(self.store.draft)self.store.draft.module=self.moduleIndex==0?@"主程序":@"UnityFramework";
}
- (void)categoryTap:(UIButton *)b {
 if(b.tag==0)return;
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"UI 演示" message:@"当前仅实现 Hook 分类的可交互界面。" preferredStyle:UIAlertControllerStyleAlert];
 [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
 [self presentViewController:a animated:YES completion:nil];
}
- (void)closeTap {if(self.closeBlock)self.closeBlock();}
@end
