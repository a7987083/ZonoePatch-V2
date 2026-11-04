#import "V3StaticBuildPlanner.h"
#import "V3FeatureModels.h"
#import "V3PatchValidator.h"
#import "V3AddressResolver.h"
#import "V3PatchSession.h"
#import <fcntl.h>
#import <sys/stat.h>
#import <mach-o/loader.h>
#import <mach/machine.h>
#import <unistd.h>
#include <stdint.h>
#include <string.h>
#import "ZNTypedDescriptor.hpp"
#import <mach/vm_prot.h>
#include <vector>
#include <string>

static NSError *ZNP6Error(NSInteger code,NSString *message){
 return [NSError errorWithDomain:@"ZonoePatch.V3.StaticBuild" code:code userInfo:@{NSLocalizedDescriptionKey:message}];
}
// The loaded image and the file used for generation must have the same LC_UUID.
static NSString *ZNP6DiskUUID(int fd) {
 struct mach_header_64 mh={};
 if(pread(fd,&mh,sizeof(mh),0)!=(ssize_t)sizeof(mh)||
    mh.magic!=MH_MAGIC_64||mh.cputype!=CPU_TYPE_ARM64||
    mh.ncmds==0||mh.ncmds>4096||mh.sizeofcmds>1024*1024||
    mh.sizeofcmds<sizeof(struct uuid_command))return nil;
 NSMutableData *commands=[NSMutableData dataWithLength:mh.sizeofcmds];
 if(pread(fd,commands.mutableBytes,commands.length,sizeof(mh))!=(ssize_t)commands.length)return nil;
 NSUInteger pos=0;
 for(uint32_t i=0;i<mh.ncmds;i++){
  if(pos>commands.length||commands.length-pos<sizeof(struct load_command))return nil;
  struct load_command lc={};memcpy(&lc,(const uint8_t *)commands.bytes+pos,sizeof(lc));
  if(lc.cmdsize<sizeof(lc)||lc.cmdsize>commands.length-pos)return nil;
  if(lc.cmd==LC_UUID) {
   if(lc.cmdsize<sizeof(struct uuid_command))return nil;
   struct uuid_command uc={};memcpy(&uc,(const uint8_t *)commands.bytes+pos,sizeof(uc));
   return [[[NSUUID alloc]initWithUUIDBytes:uc.uuid] UUIDString];
  }
  pos+=lc.cmdsize;
 }
 return nil;
}
@implementation ZNV3StaticBuildPlanner
+ (NSData *)typedDescriptorForFeature:(ZNV3Feature *)feature error:(NSError **)error {
 if([ZNV3PatchSession shared].status!=ZNV3PatchTransactionStatusDisabled){
  if(error)*error=ZNP6Error(14,@"先恢复 Runtime Patch，再执行数值预检");
  return nil;
 }
 BOOL numeric=feature.buttonType==ZNV3FeatureTypeNumberInput||feature.buttonType==ZNV3FeatureTypeSlider;
 if(!feature||!numeric||![@[@"主程序",@"UnityFramework"] containsObject:feature.module]||
    ![feature.valueConfig isValidForFeatureType:feature.buttonType]){
  if(error)*error=ZNP6Error(15,@"参数或功能类型无效：Typed Descriptor 只支持输入框与滑条");
  return nil;
 }
 ZNV3ValueConfig *config=feature.valueConfig;
 auto type=static_cast<ZNValueCodec::Type>(config.valueType);
 const size_t width=ZNValueCodec::width(type);
 if(!width||!feature.rules.count||feature.rules.count>128){
  if(error)*error=ZNP6Error(16,@"数值类型或规则数量无效");return nil;
 }
 // P10.3 preflight still consumes the legacy double range model. Int64/UInt64
 // full precision requires a later exact-string UI/JSON migration.
 NSString *min=[NSString stringWithFormat:@"%.17g",config.minimum];
 NSString *max=[NSString stringWithFormat:@"%.17g",config.maximum];
 NSString *step=[NSString stringWithFormat:@"%.17g",config.step];
 NSString *def=[NSString stringWithFormat:@"%.17g",config.defaultValue];
 std::vector<ZNTypedDescriptor::Record> records;
 NSString *sourceUUID=nil,*sourcePath=nil;
 for(ZNV3PatchRule *rule in feature.rules){
  NSError *resolveError=nil;
  ZNV3ResolvedAddress *addr=[ZNV3AddressResolver resolve:rule.offsetText module:feature.module error:&resolveError];
  if(!addr){
   if(error)*error=resolveError?:ZNP6Error(17,@"数值 Offset 无法解析");return nil;
  }
  if(!addr.fileBacked||!(addr.segmentInitialProtection & VM_PROT_READ)||
     !(addr.segmentInitialProtection & VM_PROT_WRITE)||
     !addr.imageUUID.length||!addr.imagePath.length||
     addr.rva==0||addr.rva%width||
     addr.preferredVA<addr.segmentVMAddress||
     addr.preferredVA-addr.segmentVMAddress>addr.segmentFileSize||
     width>addr.segmentFileSize-(addr.preferredVA-addr.segmentVMAddress)||
     addr.fileOffset>INT64_MAX||width>INT64_MAX-addr.fileOffset){
   if(error)*error=ZNP6Error(18,@"数值 Offset 必须落在可读写、文件映射且按类型宽度对齐的数据段；代码地址不能直接按数值写入");
   return nil;
  }
  if(sourceUUID && (![sourceUUID isEqualToString:addr.imageUUID]||
                    ![sourcePath isEqualToString:addr.imagePath])){
   if(error)*error=ZNP6Error(19,@"规则的 Mach-O 身份不一致");return nil;
  }
  int fd=open(addr.imagePath.fileSystemRepresentation,O_RDONLY|O_CLOEXEC);
  struct stat st={};
  BOOL diskValid=fd>=0&&fstat(fd,&st)==0&&S_ISREG(st.st_mode)&&st.st_size>=0&&
   (uint64_t)st.st_size>=addr.fileOffset&&width<=(uint64_t)st.st_size-addr.fileOffset&&
   [[ZNP6DiskUUID(fd) uppercaseString] isEqualToString:[addr.imageUUID uppercaseString]];
  if(fd>=0)close(fd);
  if(!diskValid){
   if(error)*error=ZNP6Error(20,@"目标文件 UUID 或磁盘范围校验失败");return nil;
  }
  sourceUUID=addr.imageUUID;sourcePath=addr.imagePath;
  BOOL slider=feature.buttonType==ZNV3FeatureTypeSlider;
  records.push_back({slider?ZNTypedDescriptor::FeatureKind::Slider:
                             ZNTypedDescriptor::FeatureKind::Input,
    type,addr.rva,slider,
    std::string(min.UTF8String),std::string(max.UTF8String),
    slider?std::string(step.UTF8String):std::string(),
    slider?std::string(def.UTF8String):std::string()});
 }
 std::vector<uint8_t> encoded;std::string message;
 if(!ZNTypedDescriptor::encode(records,encoded,message)){
  if(error)*error=ZNP6Error(21,[NSString stringWithFormat:@"Typed Descriptor 预检失败：%s",message.c_str()]);
  return nil;
 }
 // No existing exporter consumes this result yet. Never report binary generated.
 return [NSData dataWithBytes:encoded.data() length:encoded.size()];
}

+ (ZNV3StaticBuildPlan *)planForFeature:(ZNV3Feature *)feature error:(NSError **)error {
 if([ZNV3PatchSession shared].status!=ZNV3PatchTransactionStatusDisabled) {
  if(error)*error=ZNP6Error(4,@"Restore active Runtime Patch before static build planning");
  return nil;
 }
 if(!feature||![@[@"主程序",@"UnityFramework"] containsObject:feature.module]){
  if(error)*error=ZNP6Error(5,@"Invalid feature module");return nil;
 }
 // P10.1 is a type-contract milestone, not a typed execution backend.
 // Never export Action/NumberInput/Slider as a misleading two-state switch.
 if(feature.buttonType!=ZNV3FeatureTypeToggle){
  if(error)*error=ZNP6Error(13,[NSString stringWithFormat:
   @"%@ 的静态执行协议尚未实现；P10.1 仅支持开关构建",ZNV3FeatureTypeTitle(feature.buttonType)]);
  return nil;
 }
 NSMutableArray *entries=[NSMutableArray array];
 for(ZNV3PatchRule *rule in feature.rules){
  if(!rule.offsetText.length&&!rule.patchText.length)continue;
  NSError *e=nil;
  ZNV3PatchValidation *v=[ZNV3PatchValidator validateOffset:rule.offsetText patch:rule.patchText module:feature.module error:&e];
  if(!v){if(error)*error=e?:ZNP6Error(6,@"Runtime preflight failed");return nil;}
  ZNV3ResolvedAddress *address=v.address;
  NSUInteger n=v.patchBytes.length;
  if(address.fileOffset>INT64_MAX||n>(uint64_t)(INT64_MAX-address.fileOffset)){
   if(error)*error=ZNP6Error(7,@"File offset exceeds pread range");return nil;
  }
  int fd=open(address.imagePath.fileSystemRepresentation,O_RDONLY|O_CLOEXEC);
  if(fd<0){if(error)*error=ZNP6Error(8,@"Cannot open target Mach-O source");return nil;}
  struct stat st={};NSMutableData *disk=[NSMutableData dataWithLength:n];
  NSString *diskUUID=ZNP6DiskUUID(fd);
  BOOL ok=diskUUID.length&&[diskUUID isEqualToString:address.imageUUID]&&
   fstat(fd,&st)==0&&S_ISREG(st.st_mode)&&st.st_size>=0&&
   address.fileOffset<=(uint64_t)st.st_size&&n<=(uint64_t)st.st_size-address.fileOffset&&
   pread(fd,disk.mutableBytes,n,(off_t)address.fileOffset)==(ssize_t)n&&
   [disk isEqualToData:v.originalBytes];
  close(fd);
  if(!ok){if(error)*error=ZNP6Error(9,@"Disk/loaded UUID or Original mismatch; no build may proceed");return nil;}
  [entries addObject:[[ZNV3StaticBuildEntry alloc]initWithRuleID:rule.identifier
      featureKey:feature.identifier?:@"" featureName:feature.name?:@""
      uuid:address.imageUUID path:address.imagePath rva:address.rva
      fileOffset:address.fileOffset original:disk patch:v.patchBytes]];
 }
 if(![ZNV3StaticBuildPlan validateEntries:entries error:error])return nil;
 return [[ZNV3StaticBuildPlan alloc]initWithModule:feature.module name:feature.name.length?feature.name:feature.module entries:entries];
}
+ (ZNV3StaticBuildPlan *)planForFeatures:(NSArray<ZNV3Feature *> *)features error:(NSError **)error {
 if(features.count==1)return [self planForFeature:features.firstObject error:error];
 if(features.count<2||features.count>128){
  if(error)*error=ZNP6Error(10,@"P9 requires 2–128 features");return nil;
 }
 NSMutableArray<ZNV3StaticBuildEntry *> *merged=[NSMutableArray array];
 NSMutableSet<NSString *> *keys=[NSMutableSet set];
 NSString *module=features.firstObject.module;
 for(ZNV3Feature *feature in features){
  if(!feature.identifier.length||![feature.module isEqualToString:module]){
   if(error)*error=ZNP6Error(11,@"P9 multi-feature selection must share one Mach-O module");return nil;
  }
  NSString *key=[feature.identifier substringToIndex:MIN((NSUInteger)23,feature.identifier.length)];
  if([keys containsObject:key]){
   if(error)*error=ZNP6Error(12,@"P9 duplicate feature ownership key");return nil;
  }
  [keys addObject:key];
  ZNV3StaticBuildPlan *part=[self planForFeature:feature error:error];
  if(!part)return nil;
  [merged addObjectsFromArray:part.entries];
 }
 if(![ZNV3StaticBuildPlan validateEntries:merged error:error])return nil;
 return [[ZNV3StaticBuildPlan alloc]initWithModule:module name:@"P9 Multi-Feature"
   featureCount:features.count entries:merged];
}

@end
