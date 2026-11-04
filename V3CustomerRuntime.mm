#import "V3CustomerRuntime.h"
#import "V3StaticSlotTransaction.h"
#import "ZNStaticPatchFormat.h"
#import "ZNStaticEntryVisibility.hpp"
#import "ZNStaticRVAProtection.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/vm_prot.h>
#include <vector>
#include <string.h>
#include <stdint.h>

static NSError *ZNCError(NSInteger code,NSString *reason){
 return [NSError errorWithDomain:@"ZonoePatch.Customer" code:code
   userInfo:@{NSLocalizedDescriptionKey:reason?:@"Runtime error"}];
}
static BOOL ZNCRead(uintptr_t address,void *dst,size_t len){
 if(!address||!dst||!len||len>1024*1024||len>UINTPTR_MAX-address)return NO;
 vm_size_t got=0;
 return vm_read_overwrite(mach_task_self(),(vm_address_t)address,(vm_size_t)len,
  (vm_address_t)dst,&got)==KERN_SUCCESS&&got==len;
}
static BOOL ZNCRegion(uintptr_t addr,size_t len,vm_prot_t prot){
 if(!addr||!len||len>UINTPTR_MAX-addr)return NO;
 vm_address_t start=(vm_address_t)addr;vm_size_t size=0;
 vm_region_basic_info_data_64_t info={};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;
 mach_port_t object=MACH_PORT_NULL;
 kern_return_t k=vm_region_64(mach_task_self(),&start,&size,VM_REGION_BASIC_INFO_64,
    (vm_region_info_t)&info,&count,&object);
 if(object!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),object);
 return k==KERN_SUCCESS&&start<=addr&&len<=size&&addr-start<=size-len&&
    (info.protection&prot)==prot;
}
static BOOL ZNCSlide(uint64_t preferred,intptr_t slide,uintptr_t *out){
 __int128 sum=(__int128)preferred+(__int128)slide;
 if(sum<0||sum>UINTPTR_MAX)return NO;
 *out=(uintptr_t)sum;return YES;
}
static NSString *ZNCString(const char *bytes,size_t len){
 size_t n=strnlen(bytes,len);
 if(!n)return @"";
 NSString *s=[[NSString alloc]initWithBytes:bytes length:n encoding:NSUTF8StringEncoding];
 return s?:@"";
}
@interface ZNCCell : NSObject
@property(nonatomic,assign) uintptr_t slot;
@property(nonatomic,assign) uint64_t offTarget;
@property(nonatomic,assign) uint64_t onTarget;
@end
@implementation ZNCCell @end
@interface ZNV3CustomerFeature ()
@property(nonatomic,copy,readwrite) NSString *identifier;
@property(nonatomic,copy,readwrite) NSString *title;
@property(nonatomic,copy,readwrite) NSString *imageName;
@property(nonatomic,assign,readwrite) NSUInteger ruleCount;
@property(nonatomic,assign,readwrite) BOOL enabled;
@property(nonatomic,assign) uintptr_t header;
@property(nonatomic,copy) NSString *imageUUID;
@property(nonatomic,strong) NSArray<ZNCCell *> *cells;
@end
@implementation ZNV3CustomerFeature @end

@interface ZNCCellBackend : NSObject <ZNV3StaticSlotBackend>
@end
@implementation ZNCCellBackend
- (BOOL)readAt:(uintptr_t)address value:(uint64_t *)out error:(NSError **)error {
 if((address&7u)||!ZNCRegion(address,8,VM_PROT_READ)||!ZNCRead(address,out,8)){
  if(error)*error=ZNCError(1,@"Slot 无法读取或映像已经卸载");return NO;
 }return YES;
}
- (BOOL)writeAt:(uintptr_t)address value:(uint64_t)value error:(NSError **)error {
 if((address&7u)||!ZNCRegion(address,8,VM_PROT_READ|VM_PROT_WRITE)){
  if(error)*error=ZNCError(2,@"Slot 不可写；不会修改可执行内存");return NO;
 }
 __atomic_store_n((uint64_t *)address,value,__ATOMIC_RELEASE);
 return YES;
}
@end

// P6-C generator emits one static table per image and one physical site per logical entry.
// Reject foreign/legacy tables and shared-site formats instead of guessing ownership.
static NSArray<ZNV3CustomerFeature *> *ZNCCatalogImage(uint32_t imageIndex){
 const struct mach_header *raw=_dyld_get_image_header(imageIndex);
 const char *rawName=_dyld_get_image_name(imageIndex);
 if(!raw||raw->magic!=MH_MAGIC_64||raw->cputype!=CPU_TYPE_ARM64)return nil;
 uintptr_t mappedHeader=(uintptr_t)raw;
 intptr_t slide=_dyld_get_image_vmaddr_slide(imageIndex);
 struct mach_header_64 h={};if(!ZNCRead(mappedHeader,&h,sizeof(h))||
    h.ncmds==0||h.ncmds>4096||h.sizeofcmds==0||h.sizeofcmds>1024*1024)return nil;
 std::vector<uint8_t> commands(h.sizeofcmds);
 if(mappedHeader>UINTPTR_MAX-sizeof(h)||!ZNCRead(mappedHeader+sizeof(h),commands.data(),commands.size()))return nil;
 uint64_t textVM=UINT64_MAX,codeVM=0,codeSize=0,dataSize=0,sectionVM=0,sectionSize=0;
 NSString *uuid=nil;NSUInteger offset=0,codeCount=0,dataCount=0,uuidCount=0;
 for(uint32_t i=0;i<h.ncmds;i++){
  if(offset>commands.size()||commands.size()-offset<sizeof(struct load_command))return nil;
  struct load_command lc={};memcpy(&lc,commands.data()+offset,sizeof(lc));
  if(lc.cmdsize<sizeof(lc)||lc.cmdsize>commands.size()-offset)return nil;
  if(lc.cmd==LC_UUID){
   if(lc.cmdsize<sizeof(struct uuid_command))return nil;
   struct uuid_command u={};memcpy(&u,commands.data()+offset,sizeof(u));
   uuid=[[[NSUUID alloc]initWithUUIDBytes:u.uuid] UUIDString];uuidCount++;
  }
  if(lc.cmd==LC_SEGMENT_64){
   if(lc.cmdsize<sizeof(struct segment_command_64))return nil;
   struct segment_command_64 seg={};memcpy(&seg,commands.data()+offset,sizeof(seg));
   if(!strncmp(seg.segname,"__TEXT",16))textVM=seg.vmaddr;
   if(!strncmp(seg.segname,"__ZNTEXT",16)){
    codeCount++;codeVM=seg.vmaddr;codeSize=seg.vmsize;
    if((seg.initprot&(VM_PROT_READ|VM_PROT_EXECUTE))!=(VM_PROT_READ|VM_PROT_EXECUTE))return nil;
   }
   if(!strncmp(seg.segname,"__ZNDATA",16)){
    dataCount++;dataSize=seg.vmsize;
    if((seg.initprot&(VM_PROT_READ|VM_PROT_WRITE))!=(VM_PROT_READ|VM_PROT_WRITE)||
        seg.nsects!=1||lc.cmdsize<sizeof(seg)+sizeof(struct section_64))return nil;
    struct section_64 sec={};memcpy(&sec,commands.data()+offset+sizeof(seg),sizeof(sec));
    if(strncmp(sec.sectname,"__zndata",16)||sec.addr<seg.vmaddr||
       sec.size>seg.vmsize||sec.addr-seg.vmaddr>seg.vmsize-sec.size)return nil;
    sectionVM=sec.addr;sectionSize=sec.size;
   }
  }
  offset+=lc.cmdsize;
 }
 if(uuidCount!=1||!uuid.length||codeCount!=1||dataCount!=1||textVM==UINT64_MAX||
   !codeSize||!dataSize||!sectionSize||sectionSize<sizeof(ZN44StaticHeader))return nil;
 uintptr_t code=0,table=0;
 if(!ZNCSlide(codeVM,slide,&code)||!ZNCSlide(sectionVM,slide,&table)||
    codeSize>SIZE_MAX||sectionSize>SIZE_MAX||
    !ZNCRegion(code,(size_t)codeSize,VM_PROT_READ|VM_PROT_EXECUTE)||
    !ZNCRegion(table,(size_t)sectionSize,VM_PROT_READ|VM_PROT_WRITE))return nil;
 ZN44StaticHeader header={};
 if(!ZNCRead(table,&header,sizeof(header))||
    header.magic0!=ZN44_STATIC_MAGIC0||header.magic1!=ZN44_STATIC_MAGIC1||
    header.version!=ZN44_STATIC_VERSION_V2||header.count==0||header.count>128||
    header.entrySize!=sizeof(ZN44StaticEntry)||
    !(header.flags&ZN44_STATIC_HEADER_FLAG_PAYLOAD_PROTECTION_V2)||
    !(header.flags&ZN44_STATIC_HEADER_FLAG_GENERATED_LAYOUT_V1))return nil;
 uint64_t body=sizeof(header)+(uint64_t)header.count*sizeof(ZN44StaticEntry);
 uint64_t descOff=(body+7u)&~UINT64_C(7);
 uint64_t descSize=sizeof(ZN44FeatureDescriptionHeader)+(uint64_t)header.count*sizeof(ZN44FeatureDescriptionEntry);
 if(descOff>sectionSize||descSize>sectionSize-descOff)return nil;
 std::vector<ZN44StaticEntry> entries(header.count);
 std::vector<ZN44FeatureDescriptionEntry> descs(header.count);
 if(!ZNCRead(table+sizeof(header),entries.data(),entries.size()*sizeof(ZN44StaticEntry)))return nil;
 ZN44FeatureDescriptionHeader desc={};
 if(!ZNCRead(table+(uintptr_t)descOff,&desc,sizeof(desc))||
    desc.magic0!=ZN44_FEATURE_DESC_MAGIC0||desc.magic1!=ZN44_FEATURE_DESC_MAGIC1||
    desc.count!=header.count||desc.entrySize!=sizeof(ZN44FeatureDescriptionEntry)||
    !ZNCRead(table+(uintptr_t)descOff+sizeof(desc),descs.data(),descs.size()*sizeof(ZN44FeatureDescriptionEntry))||
    !ZN55ValidateProtectedHeader(&header,entries.data()))return nil;

 BOOL multi=(header.flags&ZN44_STATIC_HEADER_FLAG_MULTI_FEATURE_V1)!=0;
 NSMutableDictionary<NSString *,NSMutableArray<ZNCCell *> *> *groups=[NSMutableDictionary dictionary];
 NSMutableDictionary<NSString *,NSString *> *titles=[NSMutableDictionary dictionary];
 NSMutableDictionary<NSString *,NSNumber *> *activeCounts=[NSMutableDictionary dictionary];
 NSMutableArray<NSString *> *order=[NSMutableArray array];
 NSString *legacyTitle=ZNCString(entries[0].title,sizeof(entries[0].title));
 for(uint32_t i=0;i<header.count;i++){
  const ZN44StaticEntry &entry=entries[i];
  if(entry.patchID!=i+1||entry.canonicalIndex!=i||entry.physicalID!=i+1||
     !(entry.flags&ZN44_STATIC_ENTRY_FLAG_CANONICAL)||
     entry.enabledLength==0||entry.enabledLength>256||(entry.enabledLength&3u))return nil;
  const ZN44FeatureDescriptionEntry &d=descs[i];
  NSString *marker=[[NSString alloc]initWithBytes:d.text length:MIN((NSUInteger)d.length,sizeof(d.text))
     encoding:NSUTF8StringEncoding];
  if(d.patchID!=entry.patchID||d.length!=69||![marker hasPrefix:@"P6C1:"])return nil;
  for(NSUInteger j=5;j<marker.length;j++){
   unichar ch=[marker characterAtIndex:j];
   if(!((ch>='0'&&ch<='9')||(ch>='A'&&ch<='F')))return nil;
  }
  NSString *title=ZNCString(entry.title,sizeof(entry.title));
  NSString *key=multi?ZNCString(entry.group,sizeof(entry.group)):@"legacy";
  if(!key.length||!title.length)return nil;
  if(!multi && ![title isEqualToString:legacyTitle])return nil;
  if(titles[key] && ![titles[key] isEqualToString:title])return nil;
  ZN55DecodedRVAs rvas={};
  if(!ZN55DecodeEntryRVAs(&header,&entry,i,&rvas)||
     rvas.onRVA>UINTPTR_MAX-mappedHeader||rvas.offRVA>UINTPTR_MAX-mappedHeader)return nil;
  uint64_t codeRVA=codeVM-textVM;
  if(codeVM<textVM||rvas.onRVA<codeRVA||rvas.offRVA<codeRVA||
     rvas.onRVA-codeRVA>=codeSize||rvas.offRVA-codeRVA>=codeSize)return nil;
  uintptr_t on=mappedHeader+(uintptr_t)rvas.onRVA,off=mappedHeader+(uintptr_t)rvas.offRVA;
  if(!ZNCRegion(on,4,VM_PROT_EXECUTE)||!ZNCRegion(off,4,VM_PROT_EXECUTE))return nil;
  uintptr_t slot=table+sizeof(header)+(uintptr_t)i*sizeof(ZN44StaticEntry);
  if((slot&7u)||!ZNCRegion(slot,8,VM_PROT_READ|VM_PROT_WRITE))return nil;
  uint64_t value=0;
  if(!ZNCRead(slot,&value,8)||(value!=0&&value!=off&&value!=on))return nil;
  // Do not surface code-numeric P9 implementation slots as ordinary toggles.
  // A future numeric controller must validate ZCB1 before controlling these.
  if(!ZNCustomerP9EntryVisibleAsToggle(entry))continue;
  if(!groups[key]){groups[key]=[NSMutableArray array];titles[key]=title;[order addObject:key];}
  if(value==on)activeCounts[key]=@([activeCounts[key] unsignedIntegerValue]+1);
  ZNCCell *cell=[ZNCCell new];cell.slot=slot;cell.onTarget=on;cell.offTarget=off;
  [groups[key] addObject:cell];
 }
 NSMutableArray<ZNV3CustomerFeature *> *result=[NSMutableArray arrayWithCapacity:order.count];
 for(NSString *key in order){
  NSArray<ZNCCell *> *cells=[groups[key] copy];
  NSUInteger active=[activeCounts[key] unsignedIntegerValue];
  if(active>0 && active!=cells.count)return nil;
  ZNV3CustomerFeature *feature=[ZNV3CustomerFeature new];
  feature.imageName=rawName?[[NSString stringWithUTF8String:rawName] lastPathComponent]:@"Mach-O";
  feature.imageUUID=uuid;
  feature.identifier=multi?[NSString stringWithFormat:@"%@:%p:%@",uuid,(void *)mappedHeader,key]:
    [NSString stringWithFormat:@"%@:%p",uuid,(void *)mappedHeader];
  feature.title=titles[key];
  feature.ruleCount=cells.count;feature.enabled=(active==cells.count);
  feature.header=mappedHeader;feature.cells=cells;[result addObject:feature];
 }
 return result;
}

@interface ZNV3CustomerRuntime ()
@property(nonatomic,strong) id<ZNV3StaticSlotBackend> backend;
@property(nonatomic,strong) ZNV3StaticSlotTransaction *transaction;
@property(nonatomic,copy) NSString *lastDiagnostic;
@property(nonatomic,strong) NSMutableDictionary<NSString *,NSArray<NSNumber *> *> *originalSlots;
@end
@implementation ZNV3CustomerRuntime
+ (instancetype)shared{static ZNV3CustomerRuntime *v;static dispatch_once_t once;dispatch_once(&once,^{v=[self new];});return v;}
- (instancetype)init{if((self=[super init])){
 _backend=[ZNCCellBackend new];_transaction=[[ZNV3StaticSlotTransaction alloc]initWithBackend:_backend];
 _originalSlots=[NSMutableDictionary dictionary];}return self;}
- (BOOL)recoveryFailed{return self.transaction.recoveryFailed;}
- (NSString *)lastDiagnostic{return self.transaction.lastDiagnostic?:_lastDiagnostic?:@"";}
- (NSArray<ZNV3CustomerFeature *> *)discover{
 @synchronized(self){
  NSMutableArray *found=[NSMutableArray array];
  uint32_t count=_dyld_image_count();
  for(uint32_t i=0;i<count;i++){
   NSArray<ZNV3CustomerFeature *> *features=ZNCCatalogImage(i);
   if(features.count)[found addObjectsFromArray:features];
  }
  return found;
 }
}
- (BOOL)setEnabled:(BOOL)enabled feature:(ZNV3CustomerFeature *)feature error:(NSError **)error{
 @synchronized(self){
  if(self.transaction.recoveryFailed){if(error)*error=ZNCError(40,@"前次回滚失败，静态菜单已锁定");return NO;}
  ZNV3CustomerFeature *current=nil;
  for(ZNV3CustomerFeature *candidate in [self discover])
   if([candidate.identifier isEqualToString:feature.identifier]){current=candidate;break;}
  if(!current||current.cells.count!=feature.cells.count){
   if(error)*error=ZNCError(41,@"已加载 Mach-O 已变化，拒绝写入");return NO;
  }
  if(current.enabled==enabled){if(error)*error=ZNCError(42,@"当前状态已经变化，请刷新菜单");return NO;}
  for(NSUInteger i=0;i<current.cells.count;i++)
   if(current.cells[i].slot!=feature.cells[i].slot||
      current.cells[i].onTarget!=feature.cells[i].onTarget){
    if(error)*error=ZNCError(43,@"Static Slot 身份变化");return NO;
   }
  NSMutableArray<ZNV3StaticSlotOperation *> *ops=[NSMutableArray array];
  NSMutableArray<NSNumber *> *old=[NSMutableArray array];
  for(ZNCCell *c in current.cells){
   uint64_t value=0;
   if(![self.backend readAt:c.slot value:&value error:error])return NO;
   if(enabled){
    if(value!=0&&value!=c.offTarget){if(error)*error=ZNCError(44,@"Slot 被其他组件修改");return NO;}
    [old addObject:@(value)];
    [ops addObject:[[ZNV3StaticSlotOperation alloc]initWithAddress:c.slot expected:value desired:c.onTarget]];
   }else{
    if(value!=c.onTarget){if(error)*error=ZNCError(45,@"Static Slot 不在 ON 状态");return NO;}
    NSArray<NSNumber *> *previous=self.originalSlots[current.identifier];
    NSUInteger position=ops.count;
    uint64_t desired=previous.count==current.cells.count?previous[position].unsignedLongLongValue:0;
    if(desired!=0&&desired!=c.offTarget){if(error)*error=ZNCError(46,@"Original Slot 快照无效");return NO;}
    [ops addObject:[[ZNV3StaticSlotOperation alloc]initWithAddress:c.slot expected:value desired:desired]];
   }
  }
  if(![self.transaction apply:ops error:error])return NO;
  if(enabled)self.originalSlots[current.identifier]=[old copy];
  else [self.originalSlots removeObjectForKey:current.identifier];
  return YES;
 }
}
@end
