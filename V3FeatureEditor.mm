#import "V3MenuController.h"
#import "V3UIComponents.h"

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
- (void)hideEditor {self.editor.hidden=YES;self.store.draft=nil;[self.view endEditing:YES];}

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
@end
