#import "V3ConfigRepository.h"
#import "V3FeatureModels.h"
#import "V3AddressResolver.h"
#import "V3PatchCodec.h"

static NSString * const ZNErrorDomain=@"ZonoePatch.V3.Config";
static NSError *ZNError(NSInteger code,NSString *description) {
 return [NSError errorWithDomain:ZNErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:description}];
}
// Keep storage and runtime input semantics identical. Blank rules are allowed only as empty pairs.
static BOOL ZNValidRule(NSString *offset, NSString *patch) {
 if(![offset isKindOfClass:NSString.class]||![patch isKindOfClass:NSString.class])return NO;
 if(!offset.length&&!patch.length)return YES;
 return [ZNV3AddressResolver validAlignedCodeOffsetText:offset] &&
        [ZNV3PatchCodec isValidCodeText:patch];
}
// Legacy schema v1 permits numeric features without a parameter section.
static BOOL ZNDecodeValueConfig(id object,ZNV3FeatureType type,ZNV3ValueConfig **out) {
 ZNV3ValueConfig *v=[ZNV3ValueConfig defaults];
 if(object){
  if(![object isKindOfClass:NSDictionary.class])return NO;
  NSDictionary *d=object;
  NSArray *keys=type==ZNV3FeatureTypeNumberInput?@[@"valueType",@"minimum",@"maximum"]:@[@"valueType",@"minimum",@"maximum",@"step",@"defaultValue",@"requiresEnableSwitch"];
  for(NSString *key in keys)
   if(![d[key] isKindOfClass:NSNumber.class])return NO;
  NSInteger typeID=[d[@"valueType"] integerValue];
  // Legacy P10.2 numeric config omitted schema marker: 0=Int32, 1=Float32.
  if(!d[@"numericSchemaVersion"]){
   if(typeID!=0&&typeID!=1)return NO;
   typeID=(typeID==0)?ZNV3NumericTypeInt32:ZNV3NumericTypeFloat32;
  }else if(![d[@"numericSchemaVersion"] isKindOfClass:NSNumber.class]||
           [d[@"numericSchemaVersion"] integerValue]!=2)return NO;
  v.valueType=(ZNV3NumericType)typeID;
  v.minimum=[d[@"minimum"] doubleValue];v.maximum=[d[@"maximum"] doubleValue];
  if(d[@"step"])v.step=[d[@"step"] doubleValue];
  if(d[@"defaultValue"])v.defaultValue=[d[@"defaultValue"] doubleValue];
  if(d[@"requiresEnableSwitch"])v.requiresEnableSwitch=[d[@"requiresEnableSwitch"] boolValue];
 }
 if(![v isValidForFeatureType:type])return NO;
 *out=v;return YES;
}
static NSDictionary *ZNEncodeValueConfig(ZNV3ValueConfig *v,ZNV3FeatureType type){
 if(type==ZNV3FeatureTypeNumberInput)
  return @{@"numericSchemaVersion":@2,@"valueType":@(v.valueType),@"minimum":@(v.minimum),@"maximum":@(v.maximum)};
 return @{@"numericSchemaVersion":@2,@"valueType":@(v.valueType),@"minimum":@(v.minimum),
          @"maximum":@(v.maximum),@"step":@(v.step),
          @"defaultValue":@(v.defaultValue),@"requiresEnableSwitch":@(v.requiresEnableSwitch)};
}
@interface ZNV3ConfigRepository ()
@property(nonatomic,copy) NSArray *quarantinedEntries;
@end
@implementation ZNV3ConfigRepository
- (NSUInteger)quarantinedFeatureCount {return self.quarantinedEntries.count;}
- (NSURL *)fileURL:(NSError **)error {
 NSURL *dir=[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
 if(!dir) {if(error)*error=ZNError(1,@"App Support 路径不可用");return nil;}
 dir=[dir URLByAppendingPathComponent:@"ZonoePatchV3" isDirectory:YES];
 if(![[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:error])return nil;
 return [dir URLByAppendingPathComponent:@"features-v1.json"];
}
- (NSArray<ZNV3Feature *> *)loadFeatures:(NSError **)error {
 NSURL *url=[self fileURL:error];if(!url)return nil;
 if(![[NSFileManager defaultManager] fileExistsAtPath:url.path])return @[];
 NSData *data=[NSData dataWithContentsOfURL:url options:0 error:error];if(!data)return nil;
 id root=[NSJSONSerialization JSONObjectWithData:data options:0 error:error];
 if(![root isKindOfClass:NSDictionary.class]){if(error)*error=ZNError(2,@"配置根结构错误");return nil;}
 NSDictionary *doc=root;
 if(![doc[@"schemaVersion"] isKindOfClass:NSNumber.class] || [doc[@"schemaVersion"] integerValue]!=1){
  if(error)*error=ZNError(3,@"配置 Schema 版本不支持");return nil;
 }
 NSArray *entries=doc[@"features"];
 if(![entries isKindOfClass:NSArray.class]||entries.count>1000){if(error)*error=ZNError(4,@"功能列表格式错误");return nil;}
 NSMutableArray *result=[NSMutableArray arrayWithCapacity:entries.count];
 NSMutableArray *quarantine=[NSMutableArray array];
 for(id entry in entries){
  if(![entry isKindOfClass:NSDictionary.class]){[quarantine addObject:entry];continue;}
  NSDictionary *d=entry;
  NSString *name=d[@"name"],*detail=d[@"detail"],*module=d[@"module"],*uid=d[@"id"];
  NSNumber *button=d[@"buttonType"];NSArray *rules=d[@"rules"];
  if(![name isKindOfClass:NSString.class]||name.length>128||!name.length||
     ![detail isKindOfClass:NSString.class]||detail.length>1024||
     ![module isKindOfClass:NSString.class]||![@[@"主程序",@"UnityFramework"] containsObject:module]||
     ![uid isKindOfClass:NSString.class]||uid.length>128||!uid.length||
     ![button isKindOfClass:NSNumber.class]||!ZNV3FeatureTypeIsValid(button.integerValue)||
     ![rules isKindOfClass:NSArray.class]||rules.count>128) {
    [quarantine addObject:entry];continue;
  }
  BOOL numeric=button.integerValue==ZNV3FeatureTypeSlider||button.integerValue==ZNV3FeatureTypeNumberInput;
  BOOL legacyInvalid=NO;
  for(id item in rules){
   if(![item isKindOfClass:NSDictionary.class]){legacyInvalid=YES;break;}
   NSDictionary *r=item;id off=r[@"offset"],patch=r[@"patch"],rid=r[@"id"];
   if(![rid isKindOfClass:NSString.class]||![(NSString *)rid length]||[(NSString *)rid length]>128||
      ![off isKindOfClass:NSString.class]||
      (numeric?![ZNV3AddressResolver validAddressText:off]:(![patch isKindOfClass:NSString.class]||!ZNValidRule(off,patch)))){
    legacyInvalid=YES;break;
   }
  }
  if(legacyInvalid){[quarantine addObject:entry];continue;}
  ZNV3ValueConfig *valueConfig=nil;
  if((button.integerValue==ZNV3FeatureTypeSlider ||
      button.integerValue==ZNV3FeatureTypeNumberInput) &&
     !ZNDecodeValueConfig(d[@"parameters"],(ZNV3FeatureType)button.integerValue,&valueConfig)){
   [quarantine addObject:entry];continue;
  }
  ZNV3Feature *f=[ZNV3Feature feature:name detail:detail module:module];
  f.identifier=uid;f.buttonType=(ZNV3FeatureType)button.integerValue;
  if(valueConfig)f.valueConfig=valueConfig;
  for(NSDictionary *r in rules){
   ZNV3PatchRule *rule=[ZNV3PatchRule emptyRule];
   rule.identifier=r[@"id"];rule.offsetText=r[@"offset"];
   rule.patchText=numeric?@"":r[@"patch"];
   [f.rules addObject:rule];
  }
  [result addObject:f];
 }
 self.quarantinedEntries=[quarantine copy];
 return result;
}
- (BOOL)saveFeatures:(NSArray<ZNV3Feature *> *)features error:(NSError **)error {
 if(features.count>1000||self.quarantinedEntries.count>1000-features.count){if(error)*error=ZNError(9,@"功能数量超限");return NO;}
 NSMutableArray *items=[NSMutableArray arrayWithCapacity:features.count];
 for(ZNV3Feature *f in features){
  if(!f.name.length||f.name.length>128||f.detail.length>1024||
     ![@[@"主程序",@"UnityFramework"] containsObject:f.module]||
     !ZNV3FeatureTypeIsValid(f.buttonType)||f.rules.count>128) {
   if(error)*error=ZNError(10,@"功能字段校验失败");return NO;
  }
  BOOL numeric=f.buttonType==ZNV3FeatureTypeNumberInput||f.buttonType==ZNV3FeatureTypeSlider;
  if(numeric && (![f.valueConfig isValidForFeatureType:f.buttonType] ||
      (f.buttonType==ZNV3FeatureTypeSlider && !f.valueConfig.requiresEnableSwitch))){
   if(error)*error=ZNError(12,@"数值参数范围或 Slider 开关模式无效");return NO;
  }
  NSMutableArray *rules=[NSMutableArray arrayWithCapacity:f.rules.count];
  for(ZNV3PatchRule *rule in f.rules){
   NSString *off=rule.offsetText?:@"",*patch=rule.patchText?:@"";
   if(numeric?![ZNV3AddressResolver validAddressText:off]:!ZNValidRule(off,patch)) {
    if(error)*error=ZNError(11,numeric?@"数值类型需要合法的 Offset（Patch HEX 不适用）":@"Offset / Patch 格式错误：ARM64 Code Patch 需要 4–256 字节、4 字节对齐");return NO;
   }
   [rules addObject:numeric?@{@"id":rule.identifier?:@"",@"offset":off}:
                         @{@"id":rule.identifier?:@"",@"offset":off,@"patch":patch}];
  }
  NSMutableDictionary *item=[@{@"id":f.identifier?:@"",@"name":f.name,@"detail":f.detail?:@"",
    @"module":f.module,@"buttonType":@(f.buttonType),@"rules":rules} mutableCopy];
  if(numeric)item[@"parameters"]=ZNEncodeValueConfig(f.valueConfig,f.buttonType);
  [items addObject:item];
 }
 // Preserve legacy entries verbatim; never silently drop incompatible features on save.
 [items addObjectsFromArray:self.quarantinedEntries?:@[]];
 NSDictionary *doc=@{@"schemaVersion":@1,@"features":items};
 NSData *data=[NSJSONSerialization dataWithJSONObject:doc options:NSJSONWritingPrettyPrinted error:error];if(!data)return NO;
 NSURL *url=[self fileURL:error];if(!url)return NO;
 return [data writeToURL:url options:NSDataWritingAtomic error:error];
}
@end
