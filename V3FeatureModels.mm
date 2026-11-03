#import "V3FeatureModels.h"
#import "V3ConfigRepository.h"
#include <math.h>
#include <stdint.h>
#include <float.h>
@implementation ZNV3ValueConfig
+ (instancetype)defaults {ZNV3ValueConfig *v=[self new];v.valueType=ZNV3NumericTypeInt32;v.minimum=0;v.maximum=100;v.step=1;v.defaultValue=0;v.requiresEnableSwitch=YES;return v;}
- (id)copyWithZone:(NSZone *)zone {ZNV3ValueConfig *v=[[[self class] allocWithZone:zone]init];v.valueType=self.valueType;v.minimum=self.minimum;v.maximum=self.maximum;v.step=self.step;v.defaultValue=self.defaultValue;v.requiresEnableSwitch=self.requiresEnableSwitch;return v;}
- (BOOL)isValidForFeatureType:(ZNV3FeatureType)featureType {
 if(featureType==ZNV3FeatureTypeSlider)return [self isValid];
 if(featureType!=ZNV3FeatureTypeNumberInput)return NO;
 if(self.valueType!=ZNV3NumericTypeInt32&&self.valueType!=ZNV3NumericTypeFloat32)return NO;
 if(!isfinite(self.minimum)||!isfinite(self.maximum)||self.minimum>=self.maximum)return NO;
 if(self.valueType==ZNV3NumericTypeInt32)
  return self.minimum>=INT32_MIN&&self.maximum<=INT32_MAX&&
         trunc(self.minimum)==self.minimum&&trunc(self.maximum)==self.maximum;
 return fabs(self.minimum)<=FLT_MAX&&fabs(self.maximum)<=FLT_MAX;
}
- (BOOL)isValid {
 if(self.valueType!=ZNV3NumericTypeInt32&&self.valueType!=ZNV3NumericTypeFloat32)return NO;
 if(!isfinite(self.minimum)||!isfinite(self.maximum)||!isfinite(self.step)||!isfinite(self.defaultValue)||
    self.minimum>=self.maximum||self.step<=0||self.defaultValue<self.minimum||self.defaultValue>self.maximum||
    !self.requiresEnableSwitch)return NO;
 if(self.valueType==ZNV3NumericTypeInt32){
  for(NSNumber *number in @[@(self.minimum),@(self.maximum),@(self.step),@(self.defaultValue)]){
   double v=number.doubleValue;
   if(v<INT32_MIN||v>INT32_MAX||trunc(v)!=v)return NO;
  }
 }else{
  if(fabs(self.minimum)>FLT_MAX||fabs(self.maximum)>FLT_MAX||fabs(self.defaultValue)>FLT_MAX||self.step>FLT_MAX)return NO;
 }
 return YES;
}
@end

@implementation ZNV3PatchRule
+ (instancetype)emptyRule {
 ZNV3PatchRule *r=[self new];r.identifier=NSUUID.UUID.UUIDString;r.offsetText=@"";r.patchText=@"";return r;
}
@end
@implementation ZNV3Feature
+ (instancetype)feature:(NSString *)name detail:(NSString *)detail module:(NSString *)module {
 ZNV3Feature *f=[self new];f.identifier=NSUUID.UUID.UUIDString;f.name=name;f.detail=detail;f.module=module;
 f.rules=[NSMutableArray array];f.buttonType=ZNV3FeatureTypeToggle;f.valueConfig=[ZNV3ValueConfig defaults];return f;
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
 draft.valueConfig=[source.valueConfig copy]?:[ZNV3ValueConfig defaults];
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
 // Deleting a preceding row shifts the live draft target by one slot.
 if(_editingIndex!=NSNotFound && index<_editingIndex) _editingIndex--;
 return YES;
}
- (void)deleteRuleAtIndex:(NSUInteger)index {
 if(self.draft.rules.count>1&&index<self.draft.rules.count)
 [self.draft.rules removeObjectAtIndex:index];
}
@end
