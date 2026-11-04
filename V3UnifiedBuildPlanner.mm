#import "V3UnifiedBuildPlanner.h"
#import "V3FeatureModels.h"
#import "V3StaticBuildPlanner.h"
#import "V3AddressResolver.h"
#import "ZNUnifiedBuildPlan.hpp"
#import "ZNTypedDescriptor.hpp"
#import "ZNValueCodec.hpp"
#import "V3UnifiedImageIdentity.h"
#include <string>
#include <vector>

static NSError *ZNUPError(NSInteger code,NSString *message) {
 return [NSError errorWithDomain:@"ZonoePatch.V3.UnifiedPreflight" code:code
  userInfo:@{NSLocalizedDescriptionKey:message?:@"Unified BuildPlan failed"}];
}
static std::string ZNUPString(NSString *s) {
 return s.length?std::string(s.UTF8String):std::string();
}
static NSString *ZNUPNSString(const std::string &s) {
 return [[NSString alloc]initWithBytes:s.data() length:s.size() encoding:NSUTF8StringEncoding]?:@"";
}
@implementation ZNV3UnifiedBuildPlanner
+ (NSDictionary<NSString *,id> *)preflightManifestForFeatures:(NSArray<ZNV3Feature *> *)features
 error:(NSError **)error {
 if(features.count==0||features.count>ZNUnifiedBuildPlan::kMaxFeatures) {
  if(error)*error=ZNUPError(1,@"统一预检要求 1–128 个功能");return nil;
 }
 ZNUnifiedBuildPlan::Plan unified;
 NSString *requiredModule=nil,*requiredUUID=nil,*requiredPath=nil;
 for(ZNV3Feature *feature in features) {
  if(!feature.identifier.length||!feature.name.length||
     ![@[@"主程序",@"UnityFramework"] containsObject:feature.module]) {
   if(error)*error=ZNUPError(2,@"Feature ID、名称或模块无效");return nil;
  }
  if(requiredModule&&![feature.module isEqualToString:requiredModule]) {
   if(error)*error=ZNUPError(3,@"单次构建只能包含同一 Mach-O 的功能");return nil;
  }
  requiredModule=feature.module;
  const BOOL toggle=feature.buttonType==ZNV3FeatureTypeToggle;
  const BOOL input=feature.buttonType==ZNV3FeatureTypeNumberInput;
  const BOOL slider=feature.buttonType==ZNV3FeatureTypeSlider;
  if(!toggle&&!input&&!slider) {
   if(error)*error=ZNUPError(4,@"点击按钮尚未实现静态协议");return nil;
  }
  ZNUnifiedBuildPlan::Feature f;
  f.featureID=ZNUPString(feature.identifier);
  f.name=ZNUPString(feature.name);
  f.group=f.name; // no persisted independent group field; never derive ID from name
  f.control=toggle?ZNUnifiedBuildPlan::Control::Toggle:
      (slider?ZNUnifiedBuildPlan::Control::Slider:ZNUnifiedBuildPlan::Control::Input);
  if(toggle) {
   NSError *local=nil;
   ZNV3StaticBuildPlan *part=[ZNV3StaticBuildPlanner planForFeature:feature error:&local];
   if(!part){if(error)*error=local?:ZNUPError(5,@"普通 Patch 预检失败");return nil;}
   f.imageUUID=ZNUPString(part.imageUUID);
   f.sourcePath=ZNUPString(part.sourcePath);
   for(ZNV3StaticBuildEntry *e in part.entries) {
    f.rules.push_back({ZNUPString(e.ruleID),ZNUnifiedBuildPlan::RuleKind::PatchBytes,
                       e.rva,e.fileOffset,static_cast<uint64_t>(e.patchBytes.length)});
   }
  } else {
   NSError *local=nil;
   NSData *descriptor=[ZNV3StaticBuildPlanner typedDescriptorForFeature:feature error:&local];
   if(!descriptor){if(error)*error=local?:ZNUPError(6,@"数值预检失败");return nil;}
   std::vector<ZNTypedDescriptor::Record> records;
   std::string diagnostic;
   if(!ZNTypedDescriptor::decode((const uint8_t *)descriptor.bytes,descriptor.length,
                                records,diagnostic)||
      records.size()!=feature.rules.count||records.empty()) {
    if(error)*error=ZNUPError(7,@"数值 Descriptor 无法读取或规则数量不匹配");return nil;
   }
   const auto &first=records.front();
   f.numeric.valueType=static_cast<uint8_t>(first.type);
   f.numeric.minimum=first.minimum;f.numeric.maximum=first.maximum;
   f.numeric.step=first.step;f.numeric.defaultValue=first.defaultValue;
   f.numeric.requiresEnableSwitch=first.requiresEnableSwitch;
   for(NSUInteger i=0;i<feature.rules.count;i++) {
    ZNV3PatchRule *rule=feature.rules[i];
    ZNV3ResolvedAddress *address=[ZNV3AddressResolver resolve:rule.offsetText
                                                             module:feature.module error:&local];
    const auto &r=records[i];
    const uint64_t width=ZNValueCodec::width(r.type);
    if(!address||!width||r.rva!=address.rva||r.kind!=first.kind||r.type!=first.type||
       r.minimum!=first.minimum||r.maximum!=first.maximum||
       r.step!=first.step||r.defaultValue!=first.defaultValue||
       r.requiresEnableSwitch!=first.requiresEnableSwitch||
       !address.fileBacked||!address.imageUUID.length||!address.imagePath.length||
       address.fileOffset>INT64_MAX||width>INT64_MAX-address.fileOffset) {
     if(error)*error=local?:ZNUPError(8,@"Descriptor 与实时地址或参数不一致");return nil;
    }
    if(!f.imageUUID.empty()&&
       (f.imageUUID!=ZNUPString(address.imageUUID)||f.sourcePath!=ZNUPString(address.imagePath))) {
     if(error)*error=ZNUPError(9,@"单个功能不能跨映像");return nil;
    }
    f.imageUUID=ZNUPString(address.imageUUID);
    f.sourcePath=ZNUPString(address.imagePath);
    f.rules.push_back({ZNUPString(rule.identifier),ZNUnifiedBuildPlan::RuleKind::TypedValue,
                       r.rva,address.fileOffset,width});
   }
  }
  NSString *actualUUID=ZNUPNSString(f.imageUUID);
  NSString *actualPath=ZNUPNSString(f.sourcePath);
  if(requiredUUID &&
     !ZNV3SameImageIdentity(requiredUUID,requiredPath,actualUUID,actualPath)) {
   if(error)*error=ZNUPError(10,[NSString stringWithFormat:
     @"所选功能来自不同 Mach-O：%@ 与 %@ 的 UUID 或路径不一致",
     unified.features.empty()?@"上一功能":ZNUPNSString(unified.features.back().name),
     feature.name]);return nil;
  }
  requiredUUID=actualUUID;
  requiredPath=actualPath;
  unified.features.push_back(std::move(f));
 }
 std::string failure;
 if(!ZNUnifiedBuildPlan::validate(unified,failure)) {
  if(error)*error=ZNUPError(11,[NSString stringWithFormat:@"统一预检失败：%s",failure.c_str()]);
  return nil;
 }
 NSMutableArray *out=[NSMutableArray array];
 for(const auto &f:unified.features) {
  NSMutableArray *rules=[NSMutableArray array];
  for(const auto &r:f.rules)
   [rules addObject:@{@"ruleID":ZNUPNSString(r.ruleID),
     @"kind":@(static_cast<uint8_t>(r.kind)),
     @"rva":[NSString stringWithFormat:@"0x%llX",(unsigned long long)r.rva],
     @"fileOffset":[NSString stringWithFormat:@"0x%llX",(unsigned long long)r.fileOffset],
     @"width":@(r.width)}];
  [out addObject:@{@"featureID":ZNUPNSString(f.featureID),
    @"name":ZNUPNSString(f.name),@"group":ZNUPNSString(f.group),
    @"control":@(static_cast<uint8_t>(f.control)),
    @"valueType":f.control==ZNUnifiedBuildPlan::Control::Toggle?@(-1):@(f.numeric.valueType),
    @"numeric":f.control==ZNUnifiedBuildPlan::Control::Toggle?@{}:
      @{@"minimum":ZNUPNSString(f.numeric.minimum),@"maximum":ZNUPNSString(f.numeric.maximum),
        @"step":ZNUPNSString(f.numeric.step),@"default":ZNUPNSString(f.numeric.defaultValue),
        @"requiresEnableSwitch":@(f.numeric.requiresEnableSwitch)},
    @"rules":rules}];
 }
 return @{@"schema":@"com.zonoe.v3.unified-build-preflight",
   @"version":@(ZNUnifiedBuildPlan::kSchemaVersion),
   @"module":requiredModule?:@"",@"imageUUID":requiredUUID?:@"",
   @"sourcePath":requiredPath?:@"",@"features":out,
   @"status":@"PREFLIGHT_ONLY",@"binaryGenerated":@NO};
}
@end
