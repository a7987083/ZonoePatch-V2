#import "V3FeatureModels.h"
#import "V3ConfigRepository.h"
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
@implementation ZNV3FeatureStore {
 ZNV3ConfigRepository *_repository;
 NSError *_lastError;
 BOOL _persistenceAvailable;
}
@synthesize editingIndex=_editingIndex;
- (NSError *)lastError {return _lastError;}
- (BOOL)persistenceAvailable {return _persistenceAvailable;}
- (NSUInteger)quarantinedFeatureCount {return _repository.quarantinedFeatureCount;}
- (BOOL)persist {
 if(!_persistenceAvailable)return NO;
 NSError *err=nil;BOOL ok=[_repository saveFeatures:_features error:&err];_lastError=err;
 return ok;
}
- (instancetype)init {
 if((self=[super init])) {
 _editingIndex=NSNotFound;
 _repository=[ZNV3ConfigRepository new];
 NSError *err=nil;NSArray *loaded=[_repository loadFeatures:&err];
 _persistenceAvailable=(loaded!=nil);_lastError=err;
 _features=[NSMutableArray arrayWithArray:loaded?:@[]];
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
- (BOOL)saveDraft {
 if(!self.draft)return NO;
 NSUInteger oldIndex=_editingIndex;
 ZNV3Feature *old=oldIndex!=NSNotFound&&oldIndex<_features.count?_features[oldIndex]:nil;
 if(old)[_features replaceObjectAtIndex:oldIndex withObject:self.draft];
 else [_features addObject:self.draft];
 if(![self persist]) {
  if(old)[_features replaceObjectAtIndex:oldIndex withObject:old];
  else [_features removeLastObject];
  return NO;
 }
 [self cancelDraft];return YES;
}
- (BOOL)deleteFeatureAtIndex:(NSUInteger)index {
 if(index>=_features.count)return NO;
 ZNV3Feature *old=_features[index];[_features removeObjectAtIndex:index];
 if(![self persist]){[_features insertObject:old atIndex:index];return NO;}
 return YES;
}
- (void)deleteRuleAtIndex:(NSUInteger)index {
 if(self.draft.rules.count>1&&index<self.draft.rules.count)
 [self.draft.rules removeObjectAtIndex:index];
}
@end
