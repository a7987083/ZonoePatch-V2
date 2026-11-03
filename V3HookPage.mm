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
 [self add:ZNLabel(@"目标模块（新增 / 编辑 / 保存）",12,NO) height:20];
 self.moduleButton=ZNButton(@"主程序  ▾",self,@selector(cycleModule));[self add:self.moduleButton height:38];
 self.moduleStatus=ZNLabel(@"正在识别模块…",11,NO);[self add:self.moduleStatus height:38];
 [self refreshModuleStatus];
 if(self.store.quarantinedFeatureCount){
  [self add:ZNLabel([NSString stringWithFormat:@"⚠️ %lu 个旧版功能格式不兼容：已原样保留在 JSON 中，未启用或覆盖。",(unsigned long)self.store.quarantinedFeatureCount],11,NO) height:38];
 }
 self.staticBuildButton=ZNButton(@"生成预埋二进制（初始 OFF）",self,@selector(generateStaticBinary));
 [self add:self.staticBuildButton height:42];
 [self add:ZNLabel(@"当前功能",14,YES) height:24];
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
 [self.nameField addTarget:self action:@selector(staticBuildInputChanged:) forControlEvents:UIControlEventEditingChanged];
 [stack addArrangedSubview:ZNLabel(@"功能说明",12,YES)];
 self.descField=[self field:@"功能说明" value:@""];[stack addArrangedSubview:self.descField];
 [self.descField addTarget:self action:@selector(staticBuildInputChanged:) forControlEvents:UIControlEventEditingChanged];
 self.rulesTitleLabel=ZNLabel(@"Offset / Patch 规则（支持多组）",12,YES);
 [stack addArrangedSubview:self.rulesTitleLabel];
 self.rules=[UIStackView new];self.rules.axis=UILayoutConstraintAxisVertical;self.rules.spacing=7;[stack addArrangedSubview:self.rules];
 self.addRuleButton=ZNButton(@"＋ 添加一组 Offset / Patch",self,@selector(addRuleTap));
 [stack addArrangedSubview:self.addRuleButton];[self.addRuleButton.heightAnchor constraintEqualToConstant:36].active=YES;
 [stack addArrangedSubview:ZNLabel(@"按钮类型",12,YES)];
 self.typeButton=ZNButton(@"开关  ▾",self,@selector(cycleType));[stack addArrangedSubview:self.typeButton];[self.typeButton.heightAnchor constraintEqualToConstant:36].active=YES;
 // P10.2: numeric metadata editor (not yet connected to a runtime writer).
 self.parameterFields=[UIStackView new];self.parameterFields.axis=UILayoutConstraintAxisVertical;
 self.parameterFields.spacing=6;[stack addArrangedSubview:self.parameterFields];
 [self.parameterFields addArrangedSubview:ZNLabel(@"数值数据类型",12,YES)];
 self.valueTypeButton=ZNButton(@"Int32  ▾",self,@selector(cycleValueType));
 [self.parameterFields addArrangedSubview:self.valueTypeButton];
 [self.valueTypeButton.heightAnchor constraintEqualToConstant:34].active=YES;
 NSArray<NSString *> *names=@[@"最小值",@"最大值",@"步长",@"默认值"];
 NSMutableArray<UITextField *> *fields=[NSMutableArray arrayWithCapacity:4];
 for(NSString *name in names){
  UILabel *nameLabel=ZNLabel(name,12,YES);
  [self.parameterFields addArrangedSubview:nameLabel];
  if([name isEqualToString:@"步长"])self.stepLabel=nameLabel;
  if([name isEqualToString:@"默认值"])self.defaultLabel=nameLabel;
  UITextField *field=[self field:name value:@""];
  field.keyboardType=UIKeyboardTypeNumbersAndPunctuation;
  [self.parameterFields addArrangedSubview:field];
  [fields addObject:field];
 }
 self.minimumField=fields[0];self.maximumField=fields[1];
 self.stepField=fields[2];self.defaultField=fields[3];
 UILabel *note=ZNLabel(@"滑条：拖动只改变待生效值；打开开关才提交，关闭恢复原始状态。（执行后端待接入）",11,NO);
 note.numberOfLines=0;self.sliderHintLabel=note;
 [self.parameterFields addArrangedSubview:note];
 self.parameterFields.hidden=YES;
 UIStackView *actions=[UIStackView new];actions.axis=UILayoutConstraintAxisHorizontal;actions.distribution=UIStackViewDistributionFillEqually;actions.spacing=5;[stack addArrangedSubview:actions];
 UIButton *cancel=ZNButton(@"取消",self,@selector(hideEditor));self.patchActionButton=ZNButton(@"应用 Patch",self,@selector(applyOrRestore));UIButton *save=ZNButton(@"保存",self,@selector(saveUI));
 for(UIButton *button in @[cancel,self.patchActionButton,save]){[actions addArrangedSubview:button];[button.heightAnchor constraintEqualToConstant:38].active=YES;}

 self.editor.hidden=YES;

}
- (void)renderFeatures {
 if(!self.features)return;
 BOOL compact=self.view.bounds.size.width>0 && self.view.bounds.size.width<430;
 self.featureRowsCompact=compact;
 for(UIView *v in self.features.arrangedSubviews){[self.features removeArrangedSubview:v];[v removeFromSuperview];}
 for(NSUInteger i=0;i<self.store.features.count;i++){
  ZNV3Feature *f=self.store.features[i];
  UIStackView *row=[UIStackView new];row.axis=compact?UILayoutConstraintAxisVertical:UILayoutConstraintAxisHorizontal;
  row.alignment=compact?UIStackViewAlignmentFill:UIStackViewAlignmentCenter;row.spacing=compact?5:3;
  row.layoutMargins=UIEdgeInsetsMake(7,5,7,5);row.layoutMarginsRelativeArrangement=YES;
  row.backgroundColor=[UIColor colorWithWhite:.95 alpha:1];row.layer.cornerRadius=7;
  UIStackView *nameRow=row;
  UIStackView *actions=row;
  if(compact){
   nameRow=[UIStackView new];nameRow.axis=UILayoutConstraintAxisHorizontal;
   nameRow.alignment=UIStackViewAlignmentCenter;nameRow.spacing=5;[row addArrangedSubview:nameRow];
   actions=[UIStackView new];actions.axis=UILayoutConstraintAxisHorizontal;
   actions.distribution=UIStackViewDistributionFillEqually;actions.spacing=6;
   [row addArrangedSubview:actions];
  }
  BOOL selected=[self.selectedFeatureIDs containsObject:f.identifier] ||
   (!self.selectedFeatureIDs.count && [self.selectedFeatureID isEqualToString:f.identifier]);
  UIButton *choice=ZNButton(selected?@"◉":@"◯",self,@selector(selectFeature:));choice.tag=(NSInteger)i;
  choice.accessibilityLabel=[NSString stringWithFormat:@"%@ %@",selected?@"已选中":@"选择",f.name];
  choice.enabled=!self.staticBuildRunning;
  [choice.widthAnchor constraintEqualToConstant:25].active=YES;
  [choice.heightAnchor constraintEqualToConstant:34].active=YES;
  [nameRow addArrangedSubview:choice];
  UILabel *label=ZNLabel(f.name,13,NO);
  label.numberOfLines=1;label.lineBreakMode=NSLineBreakByTruncatingTail;
  [label setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  [label setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  [nameRow addArrangedSubview:label];
  BOOL active=[[ZNV3PatchSession shared] isActiveFeature:f.identifier];
  UIButton *toggle=ZNButton(active?@"恢复":@"启用",self,@selector(toggleFeaturePatch:));toggle.tag=(NSInteger)i;
  toggle.enabled=!self.staticBuildRunning &&
    [ZNV3PatchSession shared].status!=ZNV3PatchTransactionStatusRecoveryFailed;
  [toggle.heightAnchor constraintEqualToConstant:34].active=YES;
  if(!compact)[toggle.widthAnchor constraintEqualToConstant:43].active=YES;
  [actions addArrangedSubview:toggle];
  UIButton *edit=ZNButton(@"编辑",self,@selector(editFeature:));edit.tag=(NSInteger)i;
  edit.enabled=!self.staticBuildRunning;
  [edit.heightAnchor constraintEqualToConstant:34].active=YES;
  if(!compact)[edit.widthAnchor constraintEqualToConstant:43].active=YES;
  [actions addArrangedSubview:edit];
  UIButton *remove=ZNButton(@"删除",self,@selector(removeFeature:));remove.tag=(NSInteger)i;
  remove.enabled=!self.staticBuildRunning;
  remove.accessibilityLabel=[NSString stringWithFormat:@"删除功能 %@",f.name];
  [remove.heightAnchor constraintEqualToConstant:34].active=YES;
  if(!compact)[remove.widthAnchor constraintEqualToConstant:43].active=YES;
  [actions addArrangedSubview:remove];
  [row.heightAnchor constraintGreaterThanOrEqualToConstant:compact?88:48].active=YES;
  [self.features addArrangedSubview:row];
 }
 [self refreshStaticBuildButton];
}
- (void)selectFeature:(UIButton *)sender {
 if(self.staticBuildRunning)return;
 NSUInteger index=(NSUInteger)sender.tag;
 if(index>=self.store.features.count)return;
 NSString *identifier=self.store.features[index].identifier;
 if([self.selectedFeatureIDs containsObject:identifier]){
  [self.selectedFeatureIDs removeObject:identifier];
 }else{
  [self.selectedFeatureIDs addObject:identifier];
 }
 self.selectedFeatureID=self.selectedFeatureIDs.lastObject;
 [self renderFeatures];
}
- (void)toggleFeaturePatch:(UIButton *)sender {
 if(self.staticBuildRunning){
  [self showPatchMessage:@"构建进行中" detail:@"静态生成期间不能改变 Runtime Patch 状态。"];return;
 }
 NSUInteger index=(NSUInteger)sender.tag;
 if(index>=self.store.features.count)return;
 ZNV3Feature *feature=self.store.features[index];
 if(feature.buttonType!=ZNV3FeatureTypeToggle){
  [self showPatchMessage:@"功能尚未接入执行器" detail:@"非开关功能目前仅支持保存参数配置。不能按旧二态 Patch 执行。"];return;
 }
 ZNV3PatchSession *session=[ZNV3PatchSession shared];
 if(session.status==ZNV3PatchTransactionStatusRecoveryFailed){
  [self showPatchMessage:@"执行器已锁定" detail:session.lastDiagnostic];return;
 }
 BOOL active=[session isActiveFeature:feature.identifier];
 if(!active){
  if([ZNV3StaticDispatchRuntime shared].hasActiveFeature ||
     [ZNV3StaticDispatchRuntime shared].recoveryFailed){
   [self showPatchMessage:@"静态 Patch 已启用或故障锁定"
       detail:@"请先在用户端关闭静态 Patch，不能与 Runtime Bytes Patch 混用。"];return;
  }
  if(self.store.draft && self.store.editingIndex==index &&
     ![self draftMatchesSavedPatch:feature]){
   [self showPatchMessage:@"功能存在未保存规则"
       detail:@"请先保存或取消编辑，再启用这个功能。"];return;
  }
 }
 NSError *error=nil;
 BOOL ok=active?[session restoreFeature:feature.identifier error:&error]:
                [session applyFeature:feature error:&error];
 [self renderFeatures];
 [self refreshPatchActionButton];
 [self showPatchMessage:ok?(active?@"Original 已恢复":@"Patch 已启用"):(active?@"恢复失败":@"启用失败")
   detail:ok?(active?@"原始字节已恢复并通过读回校验。":@"目标字节已更新并通过读回校验。"):
     (error.localizedDescription?:session.lastDiagnostic)];
}
- (void)editFeature:(UIButton *)sender {
 if(self.staticBuildRunning)return;
 NSUInteger index=(NSUInteger)sender.tag;
 if(index>=self.store.features.count)return;
 self.selectedFeatureID=self.store.features[index].identifier;
 [self.selectedFeatureIDs removeAllObjects];
 [self.selectedFeatureIDs addObject:self.selectedFeatureID];
 [self editFeatureAtIndex:index];
 [self renderFeatures];
}
- (void)removeFeature:(UIButton *)sender {
 if(self.staticBuildRunning){
  [self showPatchMessage:@"构建进行中" detail:@"静态生成完成后再删除功能。"];return;
 }
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
   message:@"请先点击当前功能列表中的「恢复」，再删除该功能。" preferredStyle:UIAlertControllerStyleAlert];
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
 if(self.store.draft && [self.store.draft.identifier isEqualToString:target.identifier])
  [self hideEditor];
 [self.selectedFeatureIDs removeObject:target.identifier];
 if([self.selectedFeatureID isEqualToString:target.identifier])self.selectedFeatureID=self.selectedFeatureIDs.lastObject;
 [self renderFeatures];
}
- (void)refreshModuleStatus {
 NSString *name=self.moduleIndex==0?@"主程序":@"UnityFramework";
 ZNV3ModuleInfo *info=[ZNV3ModuleResolver resolveModule:name];
 if(!info){self.moduleStatus.text=[NSString stringWithFormat:@"%@ · 未加载（仅诊断）",name];return;}
 self.moduleStatus.text=[NSString stringWithFormat:@"%@ · 已加载 · Base 0x%llX · Slide 0x%llX",name,(unsigned long long)info.imageBase,(unsigned long long)(uint64_t)info.slide];
}
- (void)cycleModule {
 if(self.staticBuildRunning)return;
 if(self.store.draft && ([[ZNV3PatchSession shared] isActiveFeature:self.store.draft.identifier]||
    [[ZNV3StaticDispatchRuntime shared] isEnabledForFeature:self.store.draft.identifier]))return;
 self.moduleIndex=(self.moduleIndex+1)%2;
 [self.moduleButton setTitle:self.moduleIndex==0?@"主程序  ▾":@"UnityFramework  ▾" forState:UIControlStateNormal];
 [self refreshModuleStatus];
 if(self.store.draft)self.store.draft.module=self.moduleIndex==0?@"主程序":@"UnityFramework";
 [self refreshStaticBuildButton];
}
- (void)categoryTap:(UIButton *)b {
 if(b.tag==0)return;
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"UI 演示" message:@"当前仅实现 Hook 分类的可交互界面。" preferredStyle:UIAlertControllerStyleAlert];
 [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
 [self presentViewController:a animated:YES completion:nil];
}
- (void)closeTap {if(self.closeBlock)self.closeBlock();}
@end
