#import "V3StaticBinaryExport.h"
#import "V3StaticBinaryBuilder.h"
#import "V3StaticBuildPlanner.h"
#import "V3PatchSession.h"
#import "ZNAdhocMachOSigner.h"
#import "ZNStaticPatchFormat.h"
#import "V3FeatureModels.h"
#import "V3AddressResolver.h"
#import "ZNTypedMachOBuilder.h"
#import "V3UnifiedBuildPlanner.h"
#include "ZNMixedDescriptor.hpp"
#import <mach-o/loader.h>
#import <sys/stat.h>
#include <string.h>

static NSError *P6Error(NSInteger code,NSString *reason){
 return [NSError errorWithDomain:@"ZonoePatch.V3.StaticBinaryExport" code:code userInfo:@{NSLocalizedDescriptionKey:reason?:@"Unknown error"}];
}
static NSData *P9FixedUTF8(NSString *value,NSUInteger capacity) {
 NSData *source=[value dataUsingEncoding:NSUTF8StringEncoding];
 if(!source.length||capacity==0)return [NSData data];
 NSUInteger length=MIN(capacity-1,source.length);
 while(length>0 && ![[NSString alloc]initWithBytes:source.bytes length:length encoding:NSUTF8StringEncoding])
  length--;
 return [source subdataWithRange:NSMakeRange(0,length)];
}
static BOOL P6CheckStaticArtifact(NSString *path,ZNV3StaticBuildPlan *plan,NSString **reason) {
 NSData *data=[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
 if(!data||data.length<sizeof(struct mach_header_64)){
  if(reason)*reason=@"生成结果为空或不是完整 Mach-O";return NO;
 }
 const uint8_t *p=(const uint8_t *)data.bytes;
 struct mach_header_64 mh={};memcpy(&mh,p,sizeof(mh));
 if(mh.magic!=MH_MAGIC_64||mh.cputype!=CPU_TYPE_ARM64||
    mh.sizeofcmds>data.length-sizeof(mh)){
  if(reason)*reason=@"生成结果 Mach-O Header 不合法";return NO;
 }
 NSUInteger commandOffset=sizeof(mh);
 BOOL haveText=NO,haveData=NO,uuidMatches=NO;
 uint64_t tableOffset=UINT64_MAX,tableSize=0;
 for(uint32_t i=0;i<mh.ncmds;i++){
  if(commandOffset>data.length||data.length-commandOffset<sizeof(struct load_command)){
   if(reason)*reason=@"生成结果 Load Command 越界";return NO;
  }
  struct load_command lc={};memcpy(&lc,p+commandOffset,sizeof(lc));
  if(lc.cmdsize<sizeof(lc)||lc.cmdsize>data.length-commandOffset){
   if(reason)*reason=@"生成结果 Load Command 长度无效";return NO;
  }
  if(lc.cmd==LC_SEGMENT_64&&lc.cmdsize>=sizeof(struct segment_command_64)){
   struct segment_command_64 seg={};memcpy(&seg,p+commandOffset,sizeof(seg));
   if(!strncmp(seg.segname,"__ZNTEXT",16))haveText=YES;
   if(!strncmp(seg.segname,"__ZNDATA",16)){
    haveData=YES;tableOffset=seg.fileoff;tableSize=seg.filesize;
   }
  }
  if(lc.cmd==LC_UUID&&lc.cmdsize>=sizeof(struct uuid_command)){
   struct uuid_command uuid={};memcpy(&uuid,p+commandOffset,sizeof(uuid));
   uuidMatches=[[[[NSUUID alloc]initWithUUIDBytes:uuid.uuid] UUIDString] isEqualToString:plan.imageUUID];
  }
  commandOffset+=lc.cmdsize;
 }
 if(!uuidMatches||!haveText||!haveData){
  if(reason)*reason=@"生成结果 UUID 或独立 Static Dispatch Segment 缺失";return NO;
 }
 // P9 acceptance: do not report success merely because the segments exist.
 // Verify every emitted row against the immutable selected BuildPlan.
 const uint64_t needed=sizeof(ZN44StaticHeader)+(uint64_t)plan.entries.count*sizeof(ZN44StaticEntry);
 if(tableOffset==UINT64_MAX||tableOffset>data.length||
    tableSize<needed||tableSize>data.length-tableOffset){
  if(reason)*reason=@"生成结果 Static Dispatch Table 越界";return NO;
 }
 ZN44StaticHeader header={};
 memcpy(&header,p+(NSUInteger)tableOffset,sizeof(header));
 BOOL multi=plan.featureCount>1;
 if(header.magic0!=ZN44_STATIC_MAGIC0||header.magic1!=ZN44_STATIC_MAGIC1||
    header.version!=ZN44_STATIC_VERSION_V2||
    header.entrySize!=sizeof(ZN44StaticEntry)||
    header.count!=plan.entries.count||
    ((header.flags&ZN44_STATIC_HEADER_FLAG_MULTI_FEATURE_V1)!=0)!=multi){
  if(reason)*reason=@"生成规则数量或多功能标记与选中功能不一致";return NO;
 }
 NSMutableSet<NSString *> *owners=[NSMutableSet set];
 for(NSUInteger i=0;i<plan.entries.count;i++){
  ZN44StaticEntry row={};
  memcpy(&row,p+(NSUInteger)tableOffset+sizeof(header)+i*sizeof(row),sizeof(row));
  ZNV3StaticBuildEntry *expected=plan.entries[i];
  NSString *title=multi?expected.featureName:plan.featureName;
  NSString *owner=multi?[expected.featureKey substringToIndex:MIN((NSUInteger)23,expected.featureKey.length)]:nil;
  // The entry ABI uses fixed UTF-8 fields. Reproduce the builder's truncation
  // through bounded prefix checks rather than accepting an arbitrary title.
  NSData *titleBytes=P9FixedUTF8(title,sizeof(row.title));
  NSData *ownerBytes=P9FixedUTF8(owner,sizeof(row.group));
  NSUInteger tlen=titleBytes.length;
  NSUInteger olen=ownerBytes.length;
  if(row.patchID!=i+1||row.canonicalIndex!=i||row.physicalID!=i+1||
     !(row.flags&ZN44_STATIC_ENTRY_FLAG_CANONICAL)||
     row.selectedTarget!=0||!titleBytes.length||
     memcmp(row.title,titleBytes.bytes,tlen)!=0||row.title[tlen]!=0||
     (multi&&(!ownerBytes.length||memcmp(row.group,ownerBytes.bytes,olen)!=0||
      row.group[olen]!=0))){
   if(reason)*reason=[NSString stringWithFormat:@"第 %lu 条规则的功能归属或 OFF 状态与构建计划不一致",(unsigned long)(i+1)];
   return NO;
  }
  if(multi)[owners addObject:[NSString stringWithUTF8String:row.group]?:@""];
 }
 if(multi&&owners.count!=plan.featureCount){
  if(reason)*reason=@"生成结果功能组数量与选中数量不一致";return NO;
 }
 return YES;
}
@implementation ZNV3StaticBinaryExport
+ (NSString *)generateMixedMetadataForFeatures:(NSArray<ZNV3Feature *> *)features error:(NSError **)error {
 NSError *e=nil;
 NSDictionary *preflight=[ZNV3UnifiedBuildPlanner preflightManifestForFeatures:features error:&e];
 if(!preflight){if(error)*error=e?:P6Error(30,@"混合 BuildPlan 预检失败");return nil;}
 NSMutableArray<ZNV3Feature *> *toggles=[NSMutableArray array],*numerics=[NSMutableArray array];
 for(ZNV3Feature *f in features)
  if(f.buttonType==ZNV3FeatureTypeToggle)[toggles addObject:f];else [numerics addObject:f];
 if(!toggles.count||!numerics.count){
  if(error)*error=P6Error(31,@"混合导出至少需要一个普通开关和一个数值功能");return nil;
 }
 ZNV3StaticBuildPlan *staticPlan=[ZNV3StaticBuildPlanner planForFeatures:toggles error:&e];
 if(!staticPlan){if(error)*error=e?:P6Error(32,@"静态开关预检失败");return nil;}
 if(![staticPlan.imageUUID isEqualToString:preflight[@"imageUUID"]]||
    ![staticPlan.sourcePath isEqualToString:preflight[@"sourcePath"]]){
  if(error)*error=P6Error(33,@"静态与数值规则的映像身份不一致");return nil;
 }
 ZNMixedDescriptor::Package package;
 for(ZNV3Feature *f in numerics){
  NSData *legacy=[ZNV3StaticBuildPlanner typedDescriptorForFeature:f error:&e];
  std::vector<ZNTypedDescriptor::Record> records;std::string reason;
  if(!legacy||!ZNTypedDescriptor::decode((const uint8_t *)legacy.bytes,legacy.length,
                                          records,reason)||records.empty()){
   if(error)*error=e?:P6Error(34,@"数值规则再次预检失败");return nil;
  }
  if(package.records.size()+records.size()>128){
   if(error)*error=P6Error(35,@"数值规则总数超过 128");return nil;
  }
  ZNMixedDescriptor::Feature owner;
  owner.id=std::string(f.identifier.UTF8String);
  owner.name=std::string(f.name.UTF8String);
  owner.start=(uint16_t)package.records.size();
  owner.count=(uint16_t)records.size();
  owner.kind=records.front().kind;
  owner.type=records.front().type;
  package.features.push_back(std::move(owner));
  package.records.insert(package.records.end(),records.begin(),records.end());
 }
 std::vector<uint8_t> encoded;std::string reason;
 if(!ZNMixedDescriptor::encode(package,encoded,reason)){
  if(error)*error=P6Error(36,[NSString stringWithFormat:@"ZNM2 编码失败：%s",reason.c_str()]);return nil;
 }
 NSData *descriptor=[NSData dataWithBytes:encoded.data() length:encoded.size()];
 NSFileManager *fm=NSFileManager.defaultManager;
 NSString *root=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/ZonoePatchOutput"];
 if(![fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:&e]){
  if(error)*error=e;return nil;
 }
 NSString *token=NSUUID.UUID.UUIDString;
 NSString *stage=[root stringByAppendingPathComponent:[@".p106-mixed-" stringByAppendingString:token]];
 NSString *dest=[root stringByAppendingPathComponent:[@"P10-Mixed-Metadata-" stringByAppendingString:token]];
 if(![fm createDirectoryAtPath:stage withIntermediateDirectories:NO attributes:nil error:&e]){
  if(error)*error=e;return nil;
 }
 NSString *failure=nil,*generated=nil;NSDictionary *metadata=nil,*signature=nil;
 NSString *name=staticPlan.sourcePath.lastPathComponent;BOOL succeeded=NO;
 do {
  if(![ZNV3StaticBinaryBuilder buildPlan:staticPlan inDirectory:stage
        outputPath:&generated metadata:&metadata error:&failure])break;
  NSString *mixed=[stage stringByAppendingPathComponent:[@".mixed-" stringByAppendingString:token]];
  if(![ZNTypedMachOBuilder embedMixedDescriptorIntoPreparedStatic:descriptor
                                        source:generated output:mixed error:&e]){
   failure=e.localizedDescription?:@"混合描述符写入失败";break;
  }
  if(!ZNAdhocResignMachOAtPath(mixed,&signature,&failure))break;
  if(![signature[@"verified"] boolValue]){failure=@"CodeDirectory 读回校验失败";break;}
  if(!P6CheckStaticArtifact(mixed,staticPlan,&failure))break;
  NSData *readback=[ZNTypedMachOBuilder extractDescriptor:mixed error:&e];
  if(![readback isEqualToData:descriptor]){
   failure=e.localizedDescription?:@"ZNM2 元数据读回不匹配";break;
  }
  NSString *finalFile=[stage stringByAppendingPathComponent:name];
  if(![fm moveItemAtPath:mixed toPath:finalFile error:&e]){
   failure=e.localizedDescription?:@"重命名混合 Mach-O 失败";break;
  }
  [fm removeItemAtPath:generated error:nil];
  NSDictionary *report=@{
   @"schema":@"com.zonoe.v3.mixed-metadata-export",@"version":@2,
   @"staticToggleExecutable":@YES,@"numericExecutionAvailable":@NO,
   @"numericMetadataOnly":@YES,@"finalPackageResignRequired":@YES,
   @"module":staticPlan.module?:@"",@"imageUUID":staticPlan.imageUUID?:@"",
   @"toggleFeatures":@(toggles.count),@"numericFeatures":@(numerics.count),
   @"numericRules":@(package.records.size()),@"features":preflight[@"features"]?:@[],
   @"output":name,@"signature":signature?:@{},@"builder":metadata?:@{}
  };
  NSData *json=[NSJSONSerialization dataWithJSONObject:report
         options:NSJSONWritingPrettyPrinted error:&e];
  if(!json||![json writeToFile:[stage stringByAppendingPathComponent:@"build_report.json"]
                       options:NSDataWritingAtomic error:&e]){
   failure=e.localizedDescription?:@"混合报告写入失败";break;
  }
  if([fm fileExistsAtPath:dest]||![fm moveItemAtPath:stage toPath:dest error:&e]){
   failure=e.localizedDescription?:@"发布混合输出失败";break;
  }
  succeeded=YES;
 }while(0);
 if(!succeeded){
  [fm removeItemAtPath:stage error:nil];
  if(error)*error=P6Error(37,failure?:@"混合构建失败");return nil;
 }
 return [dest stringByAppendingPathComponent:name];
}

+ (NSString *)generateTypedMetadataForFeature:(ZNV3Feature *)feature error:(NSError **)error {
 NSError *preflightError=nil;
 NSData *descriptor=[ZNV3StaticBuildPlanner typedDescriptorForFeature:feature error:&preflightError];
 if(!descriptor){if(error)*error=preflightError?:P6Error(20,@"Typed Descriptor 预检失败");return nil;}
 ZNV3PatchRule *first=feature.rules.firstObject;
 ZNV3ResolvedAddress *address=[ZNV3AddressResolver resolve:first.offsetText module:feature.module
    error:&preflightError];
 if(!address||!address.imagePath.length||!address.imageUUID.length){
  if(error)*error=preflightError?:P6Error(21,@"目标 Mach-O 不可用");return nil;
 }
 NSFileManager *fm=NSFileManager.defaultManager;
 NSString *root=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/ZonoePatchOutput"];
 if(![fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:&preflightError]){
  if(error)*error=preflightError;return nil;
 }
 NSString *token=NSUUID.UUID.UUIDString;
 NSString *stage=[root stringByAppendingPathComponent:[@".p10-typed-staging-" stringByAppendingString:token]];
 NSString *dest=[root stringByAppendingPathComponent:[@"P10-Typed-Metadata-" stringByAppendingString:token]];
 if(![fm createDirectoryAtPath:stage withIntermediateDirectories:NO attributes:nil error:&preflightError]){
  if(error)*error=preflightError;return nil;
 }
 NSString *sourceName=address.imagePath.lastPathComponent;
 NSString *staged=[stage stringByAppendingPathComponent:sourceName];
 NSString *failure=nil;NSDictionary *signature=nil;
 BOOL ok=NO;
 do {
  NSError *embeddingError=nil;
  if(![ZNTypedMachOBuilder embedDescriptor:descriptor source:address.imagePath
                                    output:staged error:&embeddingError]){
   failure=embeddingError.localizedDescription?:@"Typed Mach-O 生成失败";break;
  }
  if(!ZNAdhocResignMachOAtPath(staged,&signature,&failure))break;
  NSData *verified=[ZNTypedMachOBuilder extractDescriptor:staged error:&embeddingError];
  if(![verified isEqualToData:descriptor]){
   failure=embeddingError.localizedDescription?:@"生成后二进制描述符不匹配";break;
  }
  NSDictionary *report=@{
   @"schema":@"com.zonoe.v3.typed-metadata-export",
   @"version":@1,@"metadataOnly":@YES,
   @"runtimeNumericExecution":@NO,@"customerNumericUIAvailable":@NO,
   @"staticCodePatchGenerated":@NO,@"finalPackageResignRequired":@YES,
   @"imageUUID":address.imageUUID,
   @"module":feature.module,@"featureName":feature.name?:@"",
   @"numericType":ZNV3NumericTypeName(feature.valueConfig.valueType),
   @"descriptorBytes":@(descriptor.length),
   @"output":sourceName,
   @"signature":signature?:@{}
  };
  NSData *reportData=[NSJSONSerialization dataWithJSONObject:report
                                            options:NSJSONWritingPrettyPrinted error:&embeddingError];
  if(!reportData||![reportData writeToFile:[stage stringByAppendingPathComponent:@"build_report.json"]
                                 options:NSDataWritingAtomic error:&embeddingError]){
   failure=embeddingError.localizedDescription?:@"元数据报告写入失败";break;
  }
  if([fm fileExistsAtPath:dest]||![fm moveItemAtPath:stage toPath:dest error:&embeddingError]){
   failure=embeddingError.localizedDescription?:@"输出发布失败";break;
  }
  ok=YES;
 }while(0);
 if(!ok){
  [fm removeItemAtPath:stage error:nil];
  if(error)*error=P6Error(22,failure?:@"数值元数据导出失败");
  return nil;
 }
 return [dest stringByAppendingPathComponent:sourceName];
}
+ (NSString *)generate:(ZNV3StaticBuildPlan *)plan error:(NSError **)error {
 NSError *e=nil;
 if(!plan||![ZNV3StaticBuildPlan validateEntries:plan.entries error:&e]){
  if(error)*error=e?:P6Error(1,@"静态构建计划无效");return nil;
 }
 if([ZNV3PatchSession shared].status!=ZNV3PatchTransactionStatusDisabled){
  if(error)*error=P6Error(2,@"必须先恢复所有 Runtime Patch");return nil;
 }
 NSFileManager *fm=NSFileManager.defaultManager;
 NSString *root=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/ZonoePatchOutput"];
 if(![fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:&e]){
  if(error)*error=e;return nil;
 }
 NSString *token=NSUUID.UUID.UUIDString;
 NSString *stage=[root stringByAppendingPathComponent:[@".p6-staging-" stringByAppendingString:token]];
 NSString *dest=[root stringByAppendingPathComponent:[@"P6-" stringByAppendingString:token]];
 if(![fm createDirectoryAtPath:stage withIntermediateDirectories:NO attributes:nil error:&e]){
  if(error)*error=e;return nil;
 }
 NSString *failure=nil,*generated=nil;
 NSDictionary *metadata=nil,*signature=nil;
 NSString *name=plan.sourcePath.lastPathComponent;
 BOOL ok=NO;
 do {
  if(![ZNV3StaticBinaryBuilder buildPlan:plan inDirectory:stage
        outputPath:&generated metadata:&metadata error:&failure])break;
  if(!ZNAdhocResignMachOAtPath(generated,&signature,&failure))break;
  if(!P6CheckStaticArtifact(generated,plan,&failure))break;
  NSString *finalStageFile=[stage stringByAppendingPathComponent:name];
  if(![fm moveItemAtPath:generated toPath:finalStageFile error:&e]){
   failure=e.localizedDescription;break;
  }
  NSMutableDictionary *safeMetadata=[metadata mutableCopy]?:[NSMutableDictionary dictionary];
  safeMetadata[@"output"]=name;
  NSDictionary *report=@{
   @"schema":@"com.zonoe.v3.static-binary-export",@"version":@1,
   @"binaryGenerated":@YES,@"sourceUUID":plan.imageUUID,
   @"module":plan.module,@"featureCount":@(plan.featureCount),
   @"selectedFeatures":[[plan manifest] objectForKey:@"rules"]?:@[],
   @"ruleCount":@(plan.entries.count),
   @"output":name,@"builder":safeMetadata,
   @"signature":signature?:@{},@"finalPackageResignRequired":@YES,
   @"runtimeExecutableWrites":@NO
  };
  NSData *reportData=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:&e];
  if(!reportData||![reportData writeToFile:[stage stringByAppendingPathComponent:@"build_report.json"]
          options:NSDataWritingAtomic error:&e]){failure=e.localizedDescription?:@"无法写入报告";break;}
  if([fm fileExistsAtPath:dest]||![fm moveItemAtPath:stage toPath:dest error:&e]){
   failure=e.localizedDescription?:@"构建输出发布失败";break;
  }
  ok=YES;
 }while(0);
 if(!ok){
  [fm removeItemAtPath:stage error:nil];
  if(error)*error=P6Error(3,failure?:@"静态二进制生成失败");
  return nil;
 }
 return [dest stringByAppendingPathComponent:name];
}
@end
