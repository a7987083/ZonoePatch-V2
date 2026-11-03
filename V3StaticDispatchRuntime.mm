#import "V3StaticDispatchRuntime.h"
#import "V3StaticSlotTransaction.h"
#import "V3StaticRuleIdentity.h"
#import "V3FeatureModels.h"
#import "V3AddressResolver.h"
#import "V3PatchCodec.h"
#import "V3ModuleResolver.h"
#import "ZNStaticPatchFormat.h"
#import "ZNStaticRVAProtection.h"
#import <mach-o/loader.h>
#import <mach/vm_prot.h>
#import <mach/mach.h>
#import <string.h>
#include <vector>
#include <unordered_set>
#include <stdint.h>

static NSError *ZNSTError(NSInteger code,NSString *reason){
 return [NSError errorWithDomain:@"ZonoePatch.V3.StaticRuntime" code:code
  userInfo:@{NSLocalizedDescriptionKey:reason?:@"Static runtime error"}];
}
static BOOL ZNSTRead(uintptr_t address,void *out,size_t size) {
 if(!address||!out||!size||size>1024*1024||size>UINTPTR_MAX-address)return NO;
 vm_size_t got=0;
 kern_return_t kr=vm_read_overwrite(mach_task_self(),(vm_address_t)address,
   (vm_size_t)size,(vm_address_t)out,&got);
 return kr==KERN_SUCCESS&&got==size;
}
static BOOL ZNSTRegion(uintptr_t address,size_t size,vm_prot_t required) {
 if(!address||size>UINTPTR_MAX-address)return NO;
 vm_address_t start=(vm_address_t)address;vm_size_t length=0;
 vm_region_basic_info_data_64_t info={};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;
 mach_port_t object=MACH_PORT_NULL;
 kern_return_t kr=vm_region_64(mach_task_self(),&start,&length,
   VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&object);
 if(object!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),object);
 return kr==KERN_SUCCESS&&start<=address&&length>=size&&
   address-start<=length-size&&(info.protection&required)==required;
}
@interface ZNSTSlotBackend : NSObject <ZNV3StaticSlotBackend>
@end
@implementation ZNSTSlotBackend
- (BOOL)readAt:(uintptr_t)address value:(uint64_t *)value error:(NSError **)error {
 if((address&7)||!ZNSTRegion(address,8,VM_PROT_READ)||!ZNSTRead(address,value,8)){
  if(error)*error=ZNSTError(10,@"静态 Slot 不可读取或已卸载");return NO;
 }
 return YES;
}
- (BOOL)writeAt:(uintptr_t)address value:(uint64_t)value error:(NSError **)error {
 if((address&7)||!ZNSTRegion(address,8,VM_PROT_READ|VM_PROT_WRITE)){
  if(error)*error=ZNSTError(11,@"静态 Slot 不可写，拒绝修改 RX 代码页");return NO;
 }
 __atomic_store_n((uint64_t *)address,value,__ATOMIC_RELEASE);
 return YES;
}
@end

@interface ZNSTEntry : NSObject
@property(nonatomic,assign) uintptr_t slot;
@property(nonatomic,assign) uint64_t offTarget;
@property(nonatomic,assign) uint64_t onTarget;
@end
@implementation ZNSTEntry @end

// Refuse unknown/unprepared images. Only a single owned __ZNDATA descriptor table is accepted.
static NSArray<ZNSTEntry *> *ZNSTResolve(ZNV3Feature *feature,NSError **error) {
 ZNV3ModuleInfo *image=[ZNV3ModuleResolver resolveModule:feature.module];
 if(!image){if(error)*error=ZNSTError(20,@"目标模块尚未加载");return nil;}
 struct mach_header_64 mh={};
 if(!ZNSTRead(image.imageBase,&mh,sizeof(mh))||mh.magic!=MH_MAGIC_64||
    mh.cputype!=CPU_TYPE_ARM64||mh.ncmds>4096||mh.sizeofcmds>1024*1024){
  if(error)*error=ZNSTError(21,@"已加载 Mach-O Header 不合法");return nil;
 }
 std::vector<uint8_t> commands(mh.sizeofcmds);
 if(!mh.sizeofcmds||!ZNSTRead(image.imageBase+sizeof(mh),commands.data(),commands.size())){
  if(error)*error=ZNSTError(22,@"无法读取已加载 Load Commands");return nil;
 }
 uint64_t textVM=UINT64_MAX,dataVM=0,dataSize=0,codeVM=0,codeSize=0;
 uint64_t sectionVM=0,sectionSize=0;
 NSString *uuid=nil;
 NSUInteger pos=0,ownedCount=0,codeCount=0,uuidCount=0;
 BOOL commandsValid=YES;
 for(uint32_t i=0;i<mh.ncmds;i++){
  if(pos>commands.size()||commands.size()-pos<sizeof(struct load_command)){commandsValid=NO;break;}
  struct load_command lc={};memcpy(&lc,commands.data()+pos,sizeof(lc));
  if(lc.cmdsize<sizeof(lc)||lc.cmdsize>commands.size()-pos){commandsValid=NO;break;}
  if(lc.cmd==LC_UUID&&lc.cmdsize>=sizeof(struct uuid_command)){
   struct uuid_command u={};memcpy(&u,commands.data()+pos,sizeof(u));
   uuid=[[[NSUUID alloc]initWithUUIDBytes:u.uuid] UUIDString];uuidCount++;
  }
  if(lc.cmd==LC_SEGMENT_64&&lc.cmdsize>=sizeof(struct segment_command_64)){
   struct segment_command_64 seg={};memcpy(&seg,commands.data()+pos,sizeof(seg));
   if(!strncmp(seg.segname,"__TEXT",16))textVM=seg.vmaddr;
   if(!strncmp(seg.segname,"__ZNTEXT",16)){
    codeVM=seg.vmaddr;codeSize=seg.vmsize;codeCount++;
    if((seg.initprot&(VM_PROT_READ|VM_PROT_EXECUTE))!=(VM_PROT_READ|VM_PROT_EXECUTE))codeCount+=1000;
   }
   if(!strncmp(seg.segname,"__ZNDATA",16)){
    dataVM=seg.vmaddr;dataSize=seg.vmsize;ownedCount++;
    if((seg.initprot&(VM_PROT_READ|VM_PROT_WRITE))!=(VM_PROT_READ|VM_PROT_WRITE))ownedCount+=1000;
    if(seg.nsects!=1||lc.cmdsize<sizeof(seg)+sizeof(struct section_64)){ownedCount+=1000;}
    else {
     struct section_64 sec={};
     memcpy(&sec,commands.data()+pos+sizeof(seg),sizeof(sec));
     if(strncmp(sec.sectname,"__zndata",16)||sec.addr<seg.vmaddr||
        sec.size>seg.vmsize||sec.addr-seg.vmaddr>seg.vmsize-sec.size)ownedCount+=1000;
     else {sectionVM=sec.addr;sectionSize=sec.size;}
    }
   }
  }
  pos+=lc.cmdsize;
 }
 if(!commandsValid||uuidCount!=1||!uuid.length||textVM==UINT64_MAX||ownedCount!=1||codeCount!=1||
    dataVM<textVM||codeVM<textVM||sectionVM<textVM||
    dataSize==0||codeSize==0||sectionSize<sizeof(ZN44StaticHeader)){
  if(error)*error=ZNSTError(23,@"没有找到唯一且完整的 P6 预埋描述符");return nil;
 }
 uint64_t dataDelta=sectionVM-textVM,codeDelta=codeVM-textVM;
 if(dataDelta>UINTPTR_MAX-image.imageBase||codeDelta>UINTPTR_MAX-image.imageBase){
  if(error)*error=ZNSTError(24,@"Segment 映射地址溢出");return nil;
 }
 uintptr_t table=image.imageBase+(uintptr_t)dataDelta;
 uintptr_t codeStart=image.imageBase+(uintptr_t)codeDelta;
 if(sectionSize>SIZE_MAX||!ZNSTRegion(table,sectionSize,VM_PROT_READ|VM_PROT_WRITE)||
    !ZNSTRegion(codeStart,codeSize,VM_PROT_READ|VM_PROT_EXECUTE)){
  if(error)*error=ZNSTError(25,@"预埋 Segment 内存保护与描述不一致");return nil;
 }
 ZN44StaticHeader header={};
 if(!ZNSTRead(table,&header,sizeof(header))||
    header.magic0!=ZN44_STATIC_MAGIC0||header.magic1!=ZN44_STATIC_MAGIC1||
    header.version!=ZN44_STATIC_VERSION_V2||header.entrySize!=sizeof(ZN44StaticEntry)||
    header.count==0||header.count>128||
    !(header.flags&ZN44_STATIC_HEADER_FLAG_PAYLOAD_PROTECTION_V2)){
  if(error)*error=ZNSTError(26,@"Static Dispatch ABI 或 Header 不兼容");return nil;
 }
 uint64_t entriesSize=(uint64_t)header.count*sizeof(ZN44StaticEntry);
 uint64_t baseSize=sizeof(header)+entriesSize;
 uint64_t descOff=(baseSize+7u)&~UINT64_C(7);
 uint64_t descBytes=sizeof(ZN44FeatureDescriptionHeader)+(uint64_t)header.count*sizeof(ZN44FeatureDescriptionEntry);
 if(baseSize>sectionSize||descOff>sectionSize||descBytes>sectionSize-descOff){
  if(error)*error=ZNSTError(27,@"Static Dispatch 描述符越界");return nil;
 }
 std::vector<ZN44StaticEntry> entries(header.count);
 std::vector<ZN44FeatureDescriptionEntry> descriptions(header.count);
 if(!ZNSTRead(table+sizeof(header),entries.data(),entriesSize)){
  if(error)*error=ZNSTError(28,@"Static Entry 读取失败");return nil;
 }
 ZN44FeatureDescriptionHeader d={};
 uintptr_t descAddress=table+(uintptr_t)descOff;
 if(!ZNSTRead(descAddress,&d,sizeof(d))||
    d.magic0!=ZN44_FEATURE_DESC_MAGIC0||d.magic1!=ZN44_FEATURE_DESC_MAGIC1||
    d.count!=header.count||d.entrySize!=sizeof(ZN44FeatureDescriptionEntry)||
    !ZNSTRead(descAddress+sizeof(d),descriptions.data(),descriptions.size()*sizeof(ZN44FeatureDescriptionEntry))||
    !ZN55ValidateProtectedHeader(&header,entries.data())){
  if(error)*error=ZNSTError(29,@"描述符身份表损坏或 RVA 校验失败");return nil;
 }
 NSUInteger ruleCount=0;
 for(ZNV3PatchRule *rule in feature.rules)
  if(rule.offsetText.length||rule.patchText.length)ruleCount++;
 if(ruleCount!=header.count){if(error)*error=ZNSTError(30,@"生成二进制与当前功能规则数量不匹配");return nil;}
 NSMutableArray<ZNSTEntry *> *result=[NSMutableArray array];
 NSMutableSet<NSNumber *> *used=[NSMutableSet set];
 for(ZNV3PatchRule *rule in feature.rules){
  if(!rule.offsetText.length&&!rule.patchText.length)continue;
  NSError *addressError=nil;
  ZNV3ResolvedAddress *resolved=[ZNV3AddressResolver resolve:rule.offsetText module:feature.module error:&addressError];
  NSData *patch=[ZNV3PatchCodec codeBytesFromText:rule.patchText error:&addressError];
  if(!resolved||!patch){if(error)*error=addressError?:ZNSTError(31,@"规则地址/字节无效");return nil;}
  NSString *binding=ZNP6RuleBinding(uuid,rule.identifier,resolved.rva,patch);
  BOOL found=NO;
  for(uint32_t i=0;i<header.count;i++){
   if([used containsObject:@(i)])continue;
   ZN44StaticEntry &entry=entries[i];
   ZN44FeatureDescriptionEntry &desc=descriptions[i];
   if(desc.patchID!=entry.patchID||desc.length>ZN44_FEATURE_DESC_MAX_UTF8)continue;
   NSString *descText=[[NSString alloc]initWithBytes:desc.text length:desc.length encoding:NSUTF8StringEncoding];
   ZN55DecodedRVAs rvas={};
   if(![descText isEqualToString:binding]||
      !ZN55DecodeEntryRVAs(&header,&entry,i,&rvas)||
      rvas.siteRVA!=resolved.rva||entry.enabledLength!=patch.length||
      entry.canonicalIndex!=i||!(entry.flags&ZN44_STATIC_ENTRY_FLAG_CANONICAL))continue;
   if(rvas.offRVA<codeDelta||rvas.offRVA-codeDelta>=codeSize||
      rvas.onRVA<codeDelta||rvas.onRVA-codeDelta>=codeSize||
      rvas.offRVA>UINTPTR_MAX-image.imageBase||
      rvas.onRVA>UINTPTR_MAX-image.imageBase)continue;
   uintptr_t off=image.imageBase+(uintptr_t)rvas.offRVA;
   uintptr_t on=image.imageBase+(uintptr_t)rvas.onRVA;
   uintptr_t slot=table+sizeof(header)+(uintptr_t)i*sizeof(ZN44StaticEntry);
   if(!ZNSTRegion(off,4,VM_PROT_EXECUTE)||!ZNSTRegion(on,4,VM_PROT_EXECUTE)||
      !ZNSTRegion(slot,8,VM_PROT_READ|VM_PROT_WRITE))continue;
   ZNSTEntry *e=[ZNSTEntry new];e.slot=slot;e.offTarget=off;e.onTarget=on;
   [result addObject:e];[used addObject:@(i)];found=YES;break;
  }
  if(!found){if(error)*error=ZNSTError(32,@"静态规则身份不匹配（需要用当前 P6-C 重新生成二进制）");return nil;}
 }
 if(result.count!=header.count){if(error)*error=ZNSTError(33,@"静态规则绑定不完整");return nil;}
 return result;
}
@interface ZNV3StaticDispatchRuntime ()
@property(nonatomic,strong) ZNV3StaticSlotTransaction *transaction;
@property(nonatomic,strong) id<ZNV3StaticSlotBackend> backend;
@property(nonatomic,copy) NSString *activeFeatureID;
@property(nonatomic,strong) NSArray<ZNSTEntry *> *activeEntries;
@property(nonatomic,copy) NSArray<NSNumber *> *activePreviousValues;
@end
@implementation ZNV3StaticDispatchRuntime
+ (instancetype)shared{
 static ZNV3StaticDispatchRuntime *instance;static dispatch_once_t once;
 dispatch_once(&once,^{instance=[ZNV3StaticDispatchRuntime new];});return instance;
}
- (instancetype)init{
 if((self=[super init])){_backend=[ZNSTSlotBackend new];
  _transaction=[[ZNV3StaticSlotTransaction alloc]initWithBackend:_backend];}return self;
}
- (BOOL)recoveryFailed{return self.transaction.recoveryFailed;}
- (NSString *)lastDiagnostic{return self.transaction.lastDiagnostic;}
- (BOOL)isEnabledForFeature:(NSString *)identifier {
 @synchronized(self){return identifier.length&&[self.activeFeatureID isEqualToString:identifier]&&
  !self.transaction.recoveryFailed;}
}
- (BOOL)setEnabled:(BOOL)enabled forFeature:(ZNV3Feature *)feature error:(NSError **)error {
 @synchronized(self){
  if(self.transaction.recoveryFailed){
   if(error)*error=ZNSTError(40,@"Static Slot 回滚失败，已锁定");return NO;
  }
  if(!feature.identifier.length){if(error)*error=ZNSTError(41,@"功能 ID 为空");return NO;}
  if(enabled&&self.activeFeatureID.length){
   if(error)*error=ZNSTError(42,@"已有静态功能活动，请先恢复；暂不支持多功能并发");return NO;
  }
  if(!enabled&&![self.activeFeatureID isEqualToString:feature.identifier]){
   if(error)*error=ZNSTError(43,@"目标功能没有可恢复的静态事务");return NO;
  }
  NSError *resolveError=nil;
  NSArray<ZNSTEntry *> *entries=ZNSTResolve(feature,&resolveError);
  if(!entries){if(error)*error=resolveError;return NO;}
  if(!enabled){
   if(entries.count!=self.activeEntries.count){
    if(error)*error=ZNSTError(44,@"活动事务规则数量已发生变化");return NO;
   }
   for(NSUInteger i=0;i<entries.count;i++)
    if(entries[i].slot!=self.activeEntries[i].slot||
       entries[i].onTarget!=self.activeEntries[i].onTarget){
     if(error)*error=ZNSTError(45,@"活动静态映像身份或 Slot 地址发生变化");return NO;
    }
  }
  NSMutableArray *ops=[NSMutableArray arrayWithCapacity:entries.count];
  NSMutableArray<NSNumber *> *previous=[NSMutableArray arrayWithCapacity:entries.count];
  for(ZNSTEntry *entry in entries) {
   uint64_t before=0;
   if(![self.backend readAt:entry.slot value:&before error:error])return NO;
   if(enabled){
    [previous addObject:@(before)];
    if(before!=0&&before!=entry.offTarget){
     if(error)*error=ZNSTError(46,@"静态 Slot 已有未知活动目标，拒绝覆盖");return NO;
    }
    [ops addObject:[[ZNV3StaticSlotOperation alloc]initWithAddress:entry.slot expected:before desired:entry.onTarget]];
   }else{
    if(before!=entry.onTarget){if(error)*error=ZNSTError(47,@"静态 Slot 状态发生变化，拒绝盲目恢复");return NO;}
    // Restore the exact prior OFF representation (0 or canonical OFF pointer).
    // Both execute Original, but restoring exact values avoids changing external slot state.
    if(self.activePreviousValues.count!=entries.count){
     if(error)*error=ZNSTError(48,@"缺少原始静态 Slot 快照");return NO;
    }
    uint64_t oldValue=self.activePreviousValues[ops.count].unsignedLongLongValue;
    if(oldValue!=0&&oldValue!=entry.offTarget){
     if(error)*error=ZNSTError(49,@"原始 Slot 快照已无效");return NO;
    }
    [ops addObject:[[ZNV3StaticSlotOperation alloc]initWithAddress:entry.slot expected:before desired:oldValue]];
   }
  }
  if(![self.transaction apply:ops error:error])return NO;
  self.activeFeatureID=enabled?feature.identifier:nil;
  self.activeEntries=enabled?entries:nil;
  self.activePreviousValues=enabled?[previous copy]:nil;
  return YES;
 }
}
@end
