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
- (instancetype)init {
 if((self=[super init])) {
 _features=[NSMutableArray arrayWithArray:@[
 [ZNV3Feature feature:@"无限生命" detail:@"示例 · 未执行补丁" module:@"主程序"],
 [ZNV3Feature feature:@"无限子弹" detail:@"示例 · 未执行补丁" module:@"UnityFramework"]]];
 }return self;
}
- (void)beginDraftForModule:(NSString *)module {
 self.draft=[ZNV3Feature feature:@"" detail:@"" module:module];
 [self.draft.rules addObject:[ZNV3PatchRule emptyRule]];
}
- (void)saveDraft {
 if(!self.draft)return;
 [self.features addObject:self.draft];self.draft=nil;
}
- (void)deleteFeatureAtIndex:(NSUInteger)index {
 if(index<self.features.count)[self.features removeObjectAtIndex:index];
}
- (void)deleteRuleAtIndex:(NSUInteger)index {
 if(self.draft.rules.count>1&&index<self.draft.rules.count)
 [self.draft.rules removeObjectAtIndex:index];
}
@end
