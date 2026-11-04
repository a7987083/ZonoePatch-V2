#import "V3MenuController.h"
#import "V3UIComponents.h"
#import "V3AddressResolver.h"
#import "V3PatchValidator.h"
#import "V3PatchSession.h"
#import "V3StaticBuildPlanner.h"
#import "V3StaticBinaryExport.h"
#import "V3StaticDispatchRuntime.h"

@implementation ZNV3MenuController (FeatureEditor)
- (void)renderRules {
 BOOL numeric=self.typeIndex==ZNV3FeatureTypeNumberInput||self.typeIndex==ZNV3FeatureTypeSlider;
 self.rulesTitleLabel.text=numeric?@"数值 Offset（无需 Patch HEX）":@"Offset / Patch 规则（支持多组）";
 [self.addRuleButton setTitle:numeric?@"＋ 添加 Offset":@"＋ 添加一组 Offset / Patch"
                   forState:UIControlStateNormal];
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
 [box addArrangedSubview:offset];
 if(!numeric) {
  UITextField *patch=[self field:@"Patch，例如 0x000080D2" value:r.patchText];patch.tag=2000+(NSInteger)i;
  [patch addTarget:self action:@selector(ruleTextChanged:) forControlEvents:UIControlEventEditingChanged];
  [box addArrangedSubview:patch];
 }
 [self.rules addArrangedSubview:box];
 }
}
- (void)ruleTextChanged:(UITextField *)field {
 NSUInteger index=(NSUInteger)(field.tag%1000);
 if(index>=self.store.draft.rules.count)return;
 ZNV3PatchRule *r=self.store.draft.rules[index];
 if(field.tag>=2000)r.patchText=field.text?:@"";else r.offsetText=field.text?:@"";
 [self refreshStaticBuildButton];
}
- (void)addRuleTap {
 if(!self.store.draft)return;
 [self.store.draft.rules addObject:[ZNV3PatchRule emptyRule]];
 [self renderRules];[self refreshStaticBuildButton];
}
- (void)removeRule:(UIButton *)sender {
 [self.store deleteRuleAtIndex:(NSUInteger)sender.tag];[self renderRules];[self refreshStaticBuildButton];
}
- (void)showEditor {
 if(self.staticBuildRunning)return;
 [self.store beginDraftForModule:self.moduleIndex==0?@"主程序":@"UnityFramework"];
 self.nameField.text=@"";self.descField.text=@"";
 self.typeIndex=ZNV3FeatureTypeToggle;
 [self.typeButton setTitle:[ZNV3FeatureTypeTitle(self.typeIndex) stringByAppendingString:@"  ▾"] forState:UIControlStateNormal];
 [self renderRules];[self updateParameterControls];self.editor.hidden=NO;
 [self refreshPatchActionButton];[self refreshStaticBuildButton];
 [self.view layoutIfNeeded];
 CGRect editorTop=[self.nameField convertRect:self.nameField.bounds toView:self.scroll];
 [self.scroll scrollRectToVisible:CGRectInset(editorTop,0,-12) animated:YES];
}
- (void)editFeatureAtIndex:(NSUInteger)index {
 if(self.staticBuildRunning)return;
 [self.store editFeatureAtIndex:index];
 ZNV3Feature *draft=self.store.draft;if(!draft)return;
 // Restore the persisted target when opening an existing feature; only an explicit module switch may change it.
 self.moduleIndex=[draft.module isEqualToString:@"UnityFramework"]?1:0;
 [self.moduleButton setTitle:self.moduleIndex==0?@"主程序  ▾":@"UnityFramework  ▾" forState:UIControlStateNormal];
 [self refreshModuleStatus];
 self.nameField.text=draft.name;self.descField.text=draft.detail;
 self.typeIndex=draft.buttonType;
 [self.typeButton setTitle:[ZNV3FeatureTypeTitle(self.typeIndex) stringByAppendingString:@"  ▾"] forState:UIControlStateNormal];
 [self renderRules];[self updateParameterControls];self.editor.hidden=NO;
 [self refreshPatchActionButton];[self refreshStaticBuildButton];
 [self.view endEditing:YES];[self.view layoutIfNeeded];
 CGRect editorTop=[self.nameField convertRect:self.nameField.bounds toView:self.scroll];
 [self.scroll scrollRectToVisible:CGRectInset(editorTop,0,-12) animated:YES];
}
- (void)hideEditor {
 [self.view endEditing:YES];self.editor.hidden=YES;[self.store cancelDraft];
 [self refreshStaticBuildButton];
}

- (void)cycleType {
 if(![self validateAndStoreNumericFields])return;
 self.typeIndex=(self.typeIndex+1)%(ZNV3FeatureTypeSlider+1);
 if(self.store.draft)self.store.draft.buttonType=(ZNV3FeatureType)self.typeIndex;
 [self.typeButton setTitle:[ZNV3FeatureTypeTitle(self.typeIndex) stringByAppendingString:@"  ▾"] forState:UIControlStateNormal];
 [self renderRules];[self updateParameterControls];
 [self refreshPatchActionButton];[self refreshStaticBuildButton];
}
- (void)updateParameterControls {
 BOOL numeric=self.typeIndex==ZNV3FeatureTypeNumberInput||
              self.typeIndex==ZNV3FeatureTypeSlider;
 self.parameterFields.hidden=!numeric;
 BOOL slider=self.typeIndex==ZNV3FeatureTypeSlider;
 self.stepLabel.hidden=!slider;
 self.stepField.hidden=!slider;
 self.defaultLabel.hidden=!slider;
 self.defaultField.hidden=!slider;
 self.sliderHintLabel.hidden=!slider;
 if(!numeric||!self.store.draft)return;
 ZNV3ValueConfig *v=self.store.draft.valueConfig?:[ZNV3ValueConfig defaults];
 [self.valueTypeButton setTitle:[ZNV3NumericTypeName(v.valueType) stringByAppendingString:@"  ▾"]
                     forState:UIControlStateNormal];
 self.minimumField.text=v.minimumText?:[NSString stringWithFormat:@"%.17g",v.minimum];
 self.maximumField.text=v.maximumText?:[NSString stringWithFormat:@"%.17g",v.maximum];
 self.stepField.text=v.stepText?:[NSString stringWithFormat:@"%.17g",v.step];
 self.defaultField.text=v.defaultText?:[NSString stringWithFormat:@"%.17g",v.defaultValue];
}
- (void)cycleValueType {
 if(!self.store.draft)return;
 ZNV3ValueConfig *v=self.store.draft.valueConfig;
 v.valueType=(ZNV3NumericType)((v.valueType+1)%10);
 [self.valueTypeButton setTitle:[ZNV3NumericTypeName(v.valueType) stringByAppendingString:@"  ▾"]
                     forState:UIControlStateNormal];
}
- (BOOL)validateAndStoreNumericFields {
 if(self.typeIndex!=ZNV3FeatureTypeNumberInput&&self.typeIndex!=ZNV3FeatureTypeSlider)return YES;
 BOOL slider=self.typeIndex==ZNV3FeatureTypeSlider;
 ZNV3ValueConfig *v=[self.store.draft.valueConfig copy]?:[ZNV3ValueConfig defaults];
 v.minimumText=[self.minimumField.text copy]?:@"";
 v.maximumText=[self.maximumField.text copy]?:@"";
 v.stepText=slider?([self.stepField.text copy]?:@""):nil;
 v.defaultText=slider?([self.defaultField.text copy]?:@""):nil;
 v.requiresEnableSwitch=YES;
 if(![v isValidForFeatureType:(ZNV3FeatureType)self.typeIndex]){
  [self showPatchMessage:@"数值范围无效"
    detail:slider?@"请填写合法的最小值、最大值、步长及默认值；整数按完整类型宽度精确验证。":
                  @"请填写合法的最小值和最大值；整数按完整类型宽度精确验证。"];return NO;
 }
 self.store.draft.valueConfig=v;return YES;
}
- (void)refreshPatchActionButton {
 ZNV3Feature *draft=self.store.draft;
 ZNV3PatchSession *session=[ZNV3PatchSession shared];
 BOOL blocked=session.status==ZNV3PatchTransactionStatusRecoveryFailed;
 BOOL active=draft && [session isActiveFeature:draft.identifier];
 [self.patchActionButton setTitle:blocked?@"故障锁定":(active?@"恢复 Original":@"应用 Patch") forState:UIControlStateNormal];
 self.patchActionButton.enabled=!blocked && (!draft || draft.buttonType==ZNV3FeatureTypeToggle);
 self.patchActionButton.hidden=draft && (draft.buttonType==ZNV3FeatureTypeNumberInput || draft.buttonType==ZNV3FeatureTypeSlider);
}
- (void)showPatchMessage:(NSString *)title detail:(NSString *)detail {
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:title
   message:detail preferredStyle:UIAlertControllerStyleAlert];
 [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
 [self presentViewController:alert animated:YES completion:nil];
}
- (BOOL)draftMatchesSavedPatch:(ZNV3Feature *)saved {
 ZNV3Feature *draft=self.store.draft;
 if(!saved||!draft||![saved.identifier isEqualToString:draft.identifier]||
    ![saved.module isEqualToString:draft.module]||saved.rules.count!=draft.rules.count)return NO;
 for(NSUInteger i=0;i<saved.rules.count;i++){
  ZNV3PatchRule *a=saved.rules[i],*b=draft.rules[i];
  if(![a.identifier isEqualToString:b.identifier]||
     ![a.offsetText isEqualToString:b.offsetText]||
     ![a.patchText isEqualToString:b.patchText])return NO;
 }
 return YES;
}
- (void)refreshStaticBuildButton {
 ZNV3Feature *selected=nil;
 for(ZNV3Feature *feature in self.store.features)
  if([feature.identifier isEqualToString:self.selectedFeatureID]){
   selected=feature;break;
  }
 BOOL numeric=selected&&(selected.buttonType==ZNV3FeatureTypeNumberInput||
                           selected.buttonType==ZNV3FeatureTypeSlider);
 NSString *reason=nil;
 if(self.staticBuildRunning)reason=@"正在生成二进制";
 else if(!selected)reason=@"请先保存功能，然后在当前功能中选中它";
 else if(selected.buttonType!=ZNV3FeatureTypeToggle&&!numeric)
  reason=@"此功能类型尚不支持静态二进制生成";
 else if(numeric&&self.selectedFeatureIDs.count>1)
  reason=@"数值功能一次只能选择一个，其他功能请取消选择";
 else if(self.store.draft){
  NSUInteger idx=self.store.editingIndex;
  BOOL matches=idx!=NSNotFound&&idx<self.store.features.count&&
     [self.store.features[idx].identifier isEqualToString:self.selectedFeatureID]&&
     [self draftMatchesSavedPatch:selected]&&
     [self.nameField.text isEqualToString:selected.name]&&
     [self.descField.text isEqualToString:selected.detail]&&
     self.typeIndex==selected.buttonType;
  if(!matches)reason=@"正在编辑或有未保存修改，请保存或取消后再生成";
 }
 if(!reason&&[ZNV3PatchSession shared].status!=ZNV3PatchTransactionStatusDisabled)
  reason=@"请先恢复当前 Runtime Patch";
 if(!reason&&[ZNV3StaticDispatchRuntime shared].hasActiveFeature)
  reason=@"请先关闭当前启用的静态 Patch";
 if(!reason&&[ZNV3StaticDispatchRuntime shared].recoveryFailed)
  reason=@"静态 Patch 恢复失败，构建已锁定";
 BOOL ready=!reason;
 self.staticBuildButton.enabled=ready;
 self.staticBuildButton.alpha=ready?1.0:0.48;
 [self.staticBuildButton setTitle:self.staticBuildRunning?@"正在生成二进制…":
       (numeric?@"生成数值元数据二进制":@"生成预埋二进制（初始 OFF）")
                   forState:UIControlStateNormal];
 self.staticBuildStatusLabel.text=reason?:(
    numeric?@"仅支持已加载 Mach-O 的 RW 文件映射数据 Offset；代码 Offset 无法直接生成":
             @"已选择功能，可开始生成预埋二进制");
 self.staticBuildStatusLabel.textColor=ready?
    [UIColor colorWithRed:.18 green:.43 blue:.30 alpha:1]:
    [UIColor colorWithRed:.68 green:.32 blue:.20 alpha:1];
}

- (void)staticBuildInputChanged:(UITextField *)sender {
 (void)sender;
 [self refreshStaticBuildButton];
}
- (void)generateStaticBinary {
 [self.view endEditing:YES];
 if(self.staticBuildRunning)return;
 ZNV3Feature *selected=nil;
 for(ZNV3Feature *feature in self.store.features)
  if([feature.identifier isEqualToString:self.selectedFeatureID]){selected=feature;break;}
 if(!selected){
  [self showPatchMessage:@"未选择功能" detail:@"请先点选当前功能列表中的圆点。"];
  [self refreshStaticBuildButton];return;
 }
 [self refreshStaticBuildButton];
 if(!self.staticBuildButton.enabled){
  [self showPatchMessage:@"静态构建未执行"
    detail:@"请先保存或取消编辑，并确认已恢复当前 Runtime Patch。"];
  return;
 }
 NSError *error=nil;
 NSMutableArray<ZNV3Feature *> *selectedFeatures=[NSMutableArray array];
 for(ZNV3Feature *feature in self.store.features){
  if([self.selectedFeatureIDs containsObject:feature.identifier])[selectedFeatures addObject:feature];
 }
 if(!selectedFeatures.count)[selectedFeatures addObject:selected];
 if(selected.buttonType==ZNV3FeatureTypeNumberInput||selected.buttonType==ZNV3FeatureTypeSlider){
  if(selectedFeatures.count!=1){
   [self showPatchMessage:@"数值功能只支持单独生成"
         detail:@"当前数值描述符协议每个 Mach-O 仅支持一个输入框或滑条功能。"];
   return;
  }
  NSData *descriptor=[ZNV3StaticBuildPlanner typedDescriptorForFeature:selected error:&error];
  if(!descriptor){
   [self showPatchMessage:@"数值目标预检失败"
         detail:error.localizedDescription?:@"仅接受属于 RW 数据段的类型化 Offset。"];
   return;
  }
  self.staticBuildRunning=YES;
  [self renderFeatures];
  __weak ZNV3MenuController *weakSelf=self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
   NSError *buildError=nil;
   NSString *output=[ZNV3StaticBinaryExport generateTypedMetadataForFeature:selected error:&buildError];
   NSString *detail=output?[NSString stringWithFormat:
     @"功能：%@\n文件：%@\n\n已预埋只读数值描述符并重建签名。仅适用于已验证的 RW 数据 Offset；不包含代码 Hook。替换进 IPA 并整包重签后，由新版 Customer 的数值控件执行写入及恢复。",
     selected.name,output]:(buildError.localizedDescription?:@"无法生成数值二进制");
   dispatch_async(dispatch_get_main_queue(),^{
    ZNV3MenuController *strongSelf=weakSelf;if(!strongSelf)return;
    strongSelf.staticBuildRunning=NO;
    [strongSelf renderFeatures];
    [strongSelf showPatchMessage:output?@"已生成数值元数据 Mach-O":@"数值构建失败"
                         detail:detail];
   });
  });
  return;
 }
 ZNV3StaticBuildPlan *plan=[ZNV3StaticBuildPlanner planForFeatures:selectedFeatures error:&error];
 if(!plan){
  [self showPatchMessage:@"静态构建预检失败"
    detail:error.localizedDescription?:@"目标 Mach-O 校验失败"];
  return;
 }
 self.staticBuildRunning=YES;
 [self renderFeatures];
 __weak ZNV3MenuController *weakSelf=self;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSError *buildError=nil;
  NSString *output=[ZNV3StaticBinaryExport generate:plan error:&buildError];
  NSString *detail=output?[NSString stringWithFormat:
    @"功能：%@\\n文件：%@\\n\\n已重建 ad-hoc CodeDirectory。请替换至 IPA 并完成整包重签。预埋 Patch 初始 OFF，交由用户版菜单控制。",
    plan.featureName,output]:(buildError.localizedDescription?:@"无法生成 Mach-O");
  dispatch_async(dispatch_get_main_queue(),^{
   ZNV3MenuController *strongSelf=weakSelf;if(!strongSelf)return;
   strongSelf.staticBuildRunning=NO;
   [strongSelf renderFeatures];
   [strongSelf showPatchMessage:output?@"已生成完整 Mach-O":@"静态生成失败" detail:detail];
  });
 });
}
- (void)applyOrRestore {
 if(self.staticBuildRunning){
  [self showPatchMessage:@"静态构建进行中" detail:@"生成完成后再切换 Runtime Patch。"];return;
 }
 [self.view endEditing:YES];
 ZNV3Feature *draft=self.store.draft;if(!draft)return;
 if(draft.buttonType!=ZNV3FeatureTypeToggle){
  [self showPatchMessage:@"该类型尚未接入执行器" detail:@"此阶段仅保存参数定义，不允许误执行二态 Patch。"];return;
 }
 ZNV3PatchSession *session=[ZNV3PatchSession shared];
 if([session isActiveFeature:draft.identifier]){
  NSError *error=nil;
  BOOL restored=[session restoreFeature:draft.identifier error:&error];
  [self refreshPatchActionButton];[self renderFeatures];
  [self showPatchMessage:restored?@"Original 已恢复":@"恢复失败"
                detail:restored?@"原始字节已写回并通过读回校验。":
                   (error.localizedDescription?:session.lastDiagnostic)];
  return;
 }
 if(session.status==ZNV3PatchTransactionStatusRecoveryFailed){
  [self showPatchMessage:@"执行器已锁定" detail:session.lastDiagnostic];return;
 }
 NSUInteger index=self.store.editingIndex;
 if(index==NSNotFound||index>=self.store.features.count){
  [self showPatchMessage:@"请先保存功能" detail:@"应用 Patch 仅支持已经保存的功能；保存后重新进入编辑器。"];return;
 }
 ZNV3Feature *saved=self.store.features[index];
 if(![self draftMatchesSavedPatch:saved]){
  [self showPatchMessage:@"规则尚未保存" detail:@"模块或 Offset / Patch 已修改。请先保存，重新进入编辑器后再应用。"];return;
 }
 if([ZNV3StaticDispatchRuntime shared].hasActiveFeature||
    [ZNV3StaticDispatchRuntime shared].recoveryFailed){
  [self showPatchMessage:@"静态 Patch 已启用或故障锁定"
        detail:@"请先关闭静态预埋 Patch，再使用越狱 Runtime Bytes Patch。"];return;
 }
 NSError *error=nil;
 BOOL applied=[session applyFeature:saved error:&error];
 [self refreshPatchActionButton];[self renderFeatures];
 [self showPatchMessage:applied?@"Patch 已应用":@"Patch 未应用"
                detail:applied?@"目标字节已更新并通过读回验证。可通过「恢复 Original」撤销。":
                    (error.localizedDescription?:session.lastDiagnostic)];
}
- (void)saveUI {
 if(self.staticBuildRunning){
  [self showPatchMessage:@"静态构建进行中" detail:@"生成完成后再保存修改。"];return;
 }
 if(!self.store.draft)return;
 if([[ZNV3StaticDispatchRuntime shared] isEnabledForFeature:self.store.draft.identifier]||
    [ZNV3StaticDispatchRuntime shared].recoveryFailed){
  [self showPatchMessage:@"静态 Patch 活动或故障锁定" detail:@"请先关闭静态 Patch，且确认没有恢复故障，再保存修改。"];return;
 }
 if([[ZNV3PatchSession shared] isActiveFeature:self.store.draft.identifier]){
  [self showPatchMessage:@"禁止修改活动补丁" detail:@"请先恢复 Original，再保存功能修改。"];return;
 }
 self.store.draft.module=self.moduleIndex==0?@"主程序":@"UnityFramework";
 NSString *name=self.nameField.text.length?self.nameField.text:@"未命名功能";
 self.store.draft.name=name;
 self.store.draft.detail=self.descField.text?:@"";
 self.store.draft.buttonType=(ZNV3FeatureType)self.typeIndex;
 if(![self validateAndStoreNumericFields])return;
 // Pin identity only during explicit UI save; never silently migrate across images.
 NSString *boundUUID=nil;
 for(ZNV3PatchRule *rule in self.store.draft.rules){
  if(!rule.offsetText.length)continue;
  NSError *resolveError=nil;
  ZNV3ResolvedAddress *address=[ZNV3AddressResolver resolve:rule.offsetText
                                              module:self.store.draft.module error:&resolveError];
  if(!address||!ZNV3ValidBoundImageUUID(address.imageUUID)){
   [self showPatchMessage:@"Mach-O UUID 绑定失败"
     detail:resolveError.localizedDescription?:@"必须加载目标映像并使用有效的 Offset"];return;
  }
  if(boundUUID&&!ZNV3MatchesBoundImageUUID(boundUUID,address.imageUUID)){
   [self showPatchMessage:@"UUID 绑定失败" detail:@"同一功能规则的映像身份不一致"];return;
  }
  boundUUID=address.imageUUID;
 }
 if(boundUUID.length){
  if(self.store.draft.boundImageUUID.length&&
     !ZNV3MatchesBoundImageUUID(self.store.draft.boundImageUUID,boundUUID)){
   [self showPatchMessage:@"目标 Mach-O 版本已变化"
     detail:@"保存的 UUID 不匹配当前映像。拒绝静默重绑，请为新版本新建功能。"];return;
  }
  self.store.draft.boundImageUUID=boundUUID;
 }
 NSString *savedIdentifier=[self.store.draft.identifier copy];
 if(![self.store saveDraft]) {
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"配置保存失败"
    message:self.store.lastError.localizedDescription?:@"配置不可写，请检查 App Support 文件权限"
    preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];return;
 }
 self.selectedFeatureID=savedIdentifier;
 [self.selectedFeatureIDs removeAllObjects];
 [self.selectedFeatureIDs addObject:savedIdentifier];
 [self hideEditor];[self renderFeatures];
}
@end
