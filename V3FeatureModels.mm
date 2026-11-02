#import "V3FeatureModels.h"
@implementation ZNV3PatchRule
+ (instancetype)emptyRule {
 ZNV3PatchRule *r=[self new];r.identifier=NSUUID.UUID.UUIDString;r.offsetText=@"";r.patchText=@"";return r;
}
@end
@implementation ZNV3Feature
+ (instancetype)feature:(NSString *)name detail:(NSString *)detail module:(NSString *)module {
 ZNV3Feature *f=[self new];f.identifier=NSUUID.UUID.UUIDString;f.name=name;f.detail=detail;f.module=module;
 f.rules=[NSMutableArray array];return f;
}
@end
@implementation ZNV3FeatureStore
@synthesize editingIndex=_editingIndex;
- (instancetype)init {
 if((self=[super init])) {
 _editingIndex=NSNotFound;
 _features=[NSMutableArray arrayWithArray:@[
 [ZNV3Feature feature:@"无限生命" detail:@"示例 · 未执行补丁" module:@"主程序"],
 [ZNV3Feature feature:@"无限子弹" detail:@"示例 · 未执行补丁" module:@"UnityFramework"]]];
 }return self;
}
- (void)beginDraftForModule:(NSString *)module {
 _editingIndex=NSNotFound;
 self.draft=[ZNV3Feature feature:@"" detail:@"" module:module];
 [self.draft.rules addObject:[ZNV3PatchRule emptyRule]];
}
- (void)editFeatureAtIndex:(NSUInteger)index {
 if(index>=self.features.count)return;
 ZNV3Feature *source=self.features[index];
 ZNV3Feature *draft=[ZNV3Feature feature:source.name detail:source.detail module:source.module];
 draft.identifier=source.identifier;draft.buttonType=source.buttonType;
 for(ZNV3PatchRule *item in source.rules) {
   ZNV3PatchRule *r=[ZNV3PatchRule emptyRule];r.identifier=item.identifier;
   r.offsetText=item.offsetText;r.patchText=item.patchText;[draft.rules addObject:r];
 }
 if(draft.rules.count==0)[draft.rules addObject:[ZNV3PatchRule emptyRule]];
 _editingIndex=index;self.draft=draft;
}
- (void)cancelDraft {self.draft=nil;_editingIndex=NSNotFound;}
- (void)saveDraft {
 if(!self.draft)return;
 if(_editingIndex!=NSNotFound && _editingIndex<self.features.count)
   self.features[_editingIndex]=self.draft;
 else [self.features addObject:self.draft];
 [self cancelDraft];
}
- (void)deleteFeatureAtIndex:(NSUInteger)index {
 if(index<self.features.count)[self.features removeObjectAtIndex:index];
}
- (void)deleteRuleAtIndex:(NSUInteger)index {
 if(self.draft.rules.count>1&&index<self.draft.rules.count)
 [self.draft.rules removeObjectAtIndex:index];
}
@end
