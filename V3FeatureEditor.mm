#import "V3MenuController.h"
#import "V3UIComponents.h"
#import "V3AddressResolver.h"

@implementation ZNV3MenuController (FeatureEditor)
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
- (void)editFeatureAtIndex:(NSUInteger)index {
 [self.store editFeatureAtIndex:index];
 ZNV3Feature *draft=self.store.draft;if(!draft)return;
 self.nameField.text=draft.name;self.descField.text=draft.detail;
 self.typeIndex=draft.buttonType;
 [self.typeButton setTitle:(@[@"开关  ▾",@"点击按钮  ▾",@"输入框  ▾"])[MIN(2,MAX(0,self.typeIndex))] forState:UIControlStateNormal];
 [self renderRules];self.editor.hidden=NO;
 [self.view endEditing:YES];[self.scroll layoutIfNeeded];
 [self.scroll scrollRectToVisible:self.editor.frame animated:YES];
}
- (void)hideEditor {
 [self.view endEditing:YES];self.editor.hidden=YES;[self.store cancelDraft];
}

- (void)cycleType {
 self.typeIndex=(self.typeIndex+1)%3;
 [self.typeButton setTitle:(@[@"开关  ▾",@"点击按钮  ▾",@"输入框  ▾"])[self.typeIndex] forState:UIControlStateNormal];
}
- (void)preview {
 [self.view endEditing:YES];
 ZNV3Feature *draft=self.store.draft;
 if(!draft)return;
 NSMutableArray<NSString *> *lines=[NSMutableArray array];
 for(NSUInteger i=0;i<draft.rules.count;i++){
  ZNV3PatchRule *rule=draft.rules[i];
  if(!rule.offsetText.length&&!rule.patchText.length)continue;
  NSError *error=nil;
  ZNV3ResolvedAddress *r=[ZNV3AddressResolver resolve:rule.offsetText module:draft.module error:&error];
  if(!r){[lines addObject:[NSString stringWithFormat:@"#%lu ❌ %@",(unsigned long)i+1,error.localizedDescription?:@"无法解析"]];continue;}
  NSString *file=r.fileBacked?[NSString stringWithFormat:@"0x%llX",(unsigned long long)r.fileOffset]:@"无文件映射";
  [lines addObject:[NSString stringWithFormat:@"#%lu %@ · %@\\nRVA 0x%llX · Runtime 0x%llX\\nFile %@",
    (unsigned long)i+1,r.kind,r.segmentName,(unsigned long long)r.rva,(unsigned long long)r.runtimeVA,file]];
 }
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"地址解析（只读）"
  message:lines.count?[lines componentsJoinedByString:@"\\n\\n"]:@"请先输入 Offset / Patch。不会修改内存。"
  preferredStyle:UIAlertControllerStyleAlert];
 [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
 [self presentViewController:a animated:YES completion:nil];
}
- (void)saveUI {
 NSString *name=self.nameField.text.length?self.nameField.text:@"未命名功能";
 self.store.draft.name=name;
 self.store.draft.detail=self.descField.text?:@"";
 self.store.draft.buttonType=self.typeIndex;
 if(![self.store saveDraft]) {
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"配置保存失败"
    message:self.store.lastError.localizedDescription?:@"配置不可写，请检查 App Support 文件权限"
    preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];return;
 }
 [self renderFeatures];[self hideEditor];
}
@end
