#import "V3FeatureModels.h"
#import "V3ConfigRepository.h"
#include "ZNTypedDescriptor.hpp"
#include <math.h>
#include <stdint.h>
#include <float.h>
@implementation ZNV3ValueConfig
+ (instancetype)defaults {ZNV3ValueConfig *v=[self new];v.valueType=ZNV3NumericTypeInt32;v.minimum=0;v.maximum=100;v.step=1;v.defaultValue=0;v.requiresEnableSwitch=YES;return v;}
- (id)copyWithZone:(NSZone *)zone {ZNV3ValueConfig *v=[[[self class] allocWithZone:zone]init];v.valueType=self.valueType;v.minimum=self.minimum;v.maximum=self.maximum;v.step=self.step;v.defaultValue=self.defaultValue;v.requiresEnableSwitch=self.requiresEnableSwitch;
 v.minimumText=self.minimumText;v.maximumText=self.maximumText;
 v.stepText=self.stepText;v.defaultText=self.defaultText;return v;}
// Current UI range model is double-based. Constrain 64-bit integer ranges to
// exact IEEE-754 integers until a decimal-string codec is wired into P10.3.
static BOOL ZNValidScalar(double value,ZNV3NumericType type) {
 if(!isfinite(value)||!ZNV3NumericTypeIsValid(type))return NO;
 if(type==ZNV3NumericTypeFloat32)return fabs(value)<=FLT_MAX;
 if(type==ZNV3NumericTypeFloat64)return YES;
 if(trunc(value)!=value)return NO;
 switch(type){
  case ZNV3NumericTypeInt8:return value>=INT8_MIN&&value<=INT8_MAX;
  case ZNV3NumericTypeUInt8:return value>=0&&value<=UINT8_MAX;
  case ZNV3NumericTypeInt16:return value>=INT16_MIN&&value<=INT16_MAX;
  case ZNV3NumericTypeUInt16:return value>=0&&value<=UINT16_MAX;
  case ZNV3NumericTypeInt32:return value>=INT32_MIN&&value<=INT32_MAX;
  case ZNV3NumericTypeUInt32:return value>=0&&value<=UINT32_MAX;
  case ZNV3NumericTypeInt64:return value>=-9007199254740991.0&&value<=9007199254740991.0;
  case ZNV3NumericTypeUInt64:return value>=0&&value<=9007199254740991.0;
  default:return NO;
 }
}
- (BOOL)isValidForFeatureType:(ZNV3FeatureType)featureType {
 if(self.minimumText||self.maximumText||self.stepText||self.defaultText){
  if(!self.minimumText||!self.maximumText)return NO;
  BOOL slider=featureType==ZNV3FeatureTypeSlider;
  if(!slider&&featureType!=ZNV3FeatureTypeNumberInput)return NO;
  if(slider&&(!self.stepText||!self.defaultText||!self.requiresEnableSwitch))return NO;
  auto type=static_cast<ZNValueCodec::Type>(self.valueType);
  size_t width=ZNValueCodec::width(type);
  if(!width)return NO;
  ZNTypedDescriptor::Record r={slider?ZNTypedDescriptor::FeatureKind::Slider:
                                   ZNTypedDescriptor::FeatureKind::Input,
    type,static_cast<uint64_t>(width),slider,
    std::string(self.minimumText.UTF8String),std::string(self.maximumText.UTF8String),
    slider?std::string(self.stepText.UTF8String):std::string(),
    slider?std::string(self.defaultText.UTF8String):std::string()};
  std::vector<uint8_t> bytes;std::string error;
  return ZNTypedDescriptor::encode({r},bytes,error);
 }
 if(featureType!=ZNV3FeatureTypeSlider&&featureType!=ZNV3FeatureTypeNumberInput)return NO;
 if(!ZNValidScalar(self.minimum,self.valueType)||!ZNValidScalar(self.maximum,self.valueType)||
    self.minimum>=self.maximum)return NO;
 if(featureType==ZNV3FeatureTypeNumberInput)return YES;
 if(!ZNValidScalar(self.step,self.valueType)||!ZNValidScalar(self.defaultValue,self.valueType)||
    self.step<=0||self.defaultValue<self.minimum||self.defaultValue>self.maximum||
    !self.requiresEnableSwitch)return NO;
 return YES;
}
- (BOOL)isValid {return [self isValidForFeatureType:ZNV3FeatureTypeSlider];}

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
 draft.boundImageUUID=source.boundImageUUID;
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
