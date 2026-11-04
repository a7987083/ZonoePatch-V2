#import "ZNMixedCustomerRuntime.h"
#include "ZNMixedDescriptor.hpp"
#include "ZNMixedValueCoordinator.hpp"
#include "ZNLiveTypedValueBackend.hpp"
#include "ZNStaticPatchFormat.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/vm_prot.h>
#include <string>
#include <vector>
#include <memory>
#include <cstring>

static NSError *ZNMError(NSInteger c,NSString *s){
 return [NSError errorWithDomain:@"ZonoePatch.Customer.Mixed" code:c
 userInfo:@{NSLocalizedDescriptionKey:s?:@"Mixed runtime error"}];
}
static BOOL ZNMRead(uintptr_t a,void *dst,size_t n){
 if(!a||!dst||!n||a>UINTPTR_MAX-n)return NO;
 vm_size_t received=0;
 return vm_read_overwrite(mach_task_self(),(vm_address_t)a,(vm_size_t)n,
   (vm_address_t)dst,&received)==KERN_SUCCESS&&received==n;
}
static BOOL ZNMRegion(uintptr_t address,size_t n){
 if(!address||!n||address>UINTPTR_MAX-n)return NO;
 vm_address_t start=address;vm_size_t size=0;
 vm_region_basic_info_data_64_t info={};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;
 mach_port_t obj=MACH_PORT_NULL;
 kern_return_t kr=vm_region_64(mach_task_self(),&start,&size,VM_REGION_BASIC_INFO_64,
                               (vm_region_info_t)&info,&count,&obj);
 if(obj!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),obj);
 return kr==KERN_SUCCESS&&start<=address&&address-start<=size&&
        n<=size-(address-start)&&
        (info.protection&VM_PROT_READ)&&!(info.protection&(VM_PROT_WRITE|VM_PROT_EXECUTE));
}
static BOOL ZNMSlide(uint64_t va,intptr_t slide,uintptr_t *out){
 __int128 result=(__int128)va+(__int128)slide;
 if(result<=0||result>UINTPTR_MAX)return NO;
 *out=(uintptr_t)result;return YES;
}
static NSString *ZNMString(const std::string &s){
 return [[NSString alloc]initWithBytes:s.data() length:s.size() encoding:NSUTF8StringEncoding];
}
@interface ZNMixedCustomerFeature ()
@property(nonatomic,copy,readwrite) NSString *identifier;
@property(nonatomic,copy,readwrite) NSString *title;
@property(nonatomic,copy,readwrite) NSString *imageName;
@property(nonatomic,assign,readwrite) NSUInteger numericType;
@property(nonatomic,assign,readwrite) NSUInteger featureKind;
@property(nonatomic,assign,readwrite) NSUInteger ruleCount;
@property(nonatomic,assign,readwrite,getter=isEnabled) BOOL enabled;
@property(nonatomic,assign) uintptr_t imageHeader;
@property(nonatomic,copy) NSString *imageUUID;
@property(nonatomic,copy) NSData *descriptor;
@property(nonatomic,assign) NSUInteger featureIndex;
@end
@implementation ZNMixedCustomerFeature @end

static NSArray<ZNMixedCustomerFeature *> *ZNMCatalog(uint32_t imageIndex){
 const struct mach_header *raw=_dyld_get_image_header(imageIndex);
 if(!raw||raw->magic!=MH_MAGIC_64||raw->cputype!=CPU_TYPE_ARM64)return nil;
 uintptr_t base=(uintptr_t)raw;struct mach_header_64 header={};
 if(!ZNMRead(base,&header,sizeof(header))||header.ncmds==0||header.ncmds>4096||
    !header.sizeofcmds||header.sizeofcmds>1024*1024||
    base>UINTPTR_MAX-sizeof(header)||
    header.sizeofcmds>UINTPTR_MAX-base-sizeof(header))return nil;
 std::vector<uint8_t> commands(header.sizeofcmds);
 if(!ZNMRead(base+sizeof(header),commands.data(),commands.size()))return nil;
 uint64_t text=UINT64_MAX,metadata=0,metadataLen=0,staticDataVM=0,staticDataLen=0;
 uint32_t uuidCount=0,typeCount=0,codeCount=0,dataCount=0;
 NSString *uuid=nil;size_t pos=0;const intptr_t slide=_dyld_get_image_vmaddr_slide(imageIndex);
 for(uint32_t i=0;i<header.ncmds;i++){
  if(pos>commands.size()||commands.size()-pos<sizeof(struct load_command))return nil;
  struct load_command cmd={};std::memcpy(&cmd,commands.data()+pos,sizeof(cmd));
  if(cmd.cmdsize<sizeof(cmd)||cmd.cmdsize>commands.size()-pos)return nil;
  if(cmd.cmd==LC_UUID){
   if(cmd.cmdsize<sizeof(struct uuid_command))return nil;
   struct uuid_command u={};std::memcpy(&u,commands.data()+pos,sizeof(u));
   uuid=[[[NSUUID alloc]initWithUUIDBytes:u.uuid] UUIDString];uuidCount++;
  }
  if(cmd.cmd==LC_SEGMENT_64){
   if(cmd.cmdsize<sizeof(struct segment_command_64))return nil;
   struct segment_command_64 seg={};std::memcpy(&seg,commands.data()+pos,sizeof(seg));
   if(!std::strncmp(seg.segname,"__TEXT",16)&&seg.fileoff==0){
    if(text!=UINT64_MAX)return nil;
    text=seg.vmaddr;
   }
   if(!std::strncmp(seg.segname,"__ZNTEXT",16)){
    if(seg.initprot!=(VM_PROT_READ|VM_PROT_EXECUTE)||seg.nsects!=1)return nil;
    codeCount++;
   }
   if(!std::strncmp(seg.segname,"__ZNDATA",16)){
    if(seg.initprot!=(VM_PROT_READ|VM_PROT_WRITE)||seg.nsects!=1||
       seg.filesize<sizeof(ZN44StaticHeader))return nil;
    dataCount++;staticDataVM=seg.vmaddr;staticDataLen=seg.filesize;
   }
   if(!std::strncmp(seg.segname,"__ZNTYPE",16)){
    if(seg.initprot!=VM_PROT_READ||seg.maxprot!=VM_PROT_READ||
       seg.nsects!=1||cmd.cmdsize<sizeof(seg)+sizeof(struct section_64))return nil;
    struct section_64 sec={};std::memcpy(&sec,commands.data()+pos+sizeof(seg),sizeof(sec));
    if(std::strncmp(sec.sectname,"__zntype",16)||
       std::strncmp(sec.segname,"__ZNTYPE",16)||
       sec.addr<seg.vmaddr||sec.size<12||sec.size>65536||
       sec.size>seg.vmsize||sec.addr-seg.vmaddr>seg.vmsize-sec.size||
       sec.offset<seg.fileoff||sec.offset-seg.fileoff>seg.filesize||
       sec.size>seg.filesize-(sec.offset-seg.fileoff))return nil;
    typeCount++;metadata=sec.addr;metadataLen=sec.size;
   }
  }
  pos+=cmd.cmdsize;
 }
 if(uuidCount!=1||typeCount!=1||codeCount!=1||dataCount!=1||
    text==UINT64_MAX||!uuid.length||!metadata||!staticDataVM)return nil;
 uintptr_t runtimeText=0,runtimeMeta=0,runtimeData=0;
 if(!ZNMSlide(text,slide,&runtimeText)||runtimeText!=base||
    !ZNMSlide(metadata,slide,&runtimeMeta)||
    !ZNMSlide(staticDataVM,slide,&runtimeData)||
    !ZNMRegion(runtimeMeta,(size_t)metadataLen))return nil;
 ZN44StaticHeader staticHeader={};
 if(!ZNMRead(runtimeData,&staticHeader,sizeof(staticHeader))||
    staticHeader.magic0!=ZN44_STATIC_MAGIC0||
    staticHeader.magic1!=ZN44_STATIC_MAGIC1||
    staticHeader.version!=ZN44_STATIC_VERSION_V2||
    staticHeader.entrySize!=sizeof(ZN44StaticEntry)||
    !staticHeader.count||staticHeader.count>128||
    sizeof(ZN44StaticHeader)+uint64_t(staticHeader.count)*sizeof(ZN44StaticEntry)>staticDataLen)
  return nil;
 NSMutableData *bytes=[NSMutableData dataWithLength:(NSUInteger)metadataLen];
 if(!ZNMRead(runtimeMeta,bytes.mutableBytes,bytes.length))return nil;
 ZNMixedDescriptor::Package package;std::string reason;
 if(!ZNMixedDescriptor::decode((const uint8_t*)bytes.bytes,bytes.length,package,reason))return nil;
 const char *name=_dyld_get_image_name(imageIndex);
 NSString *image=name?[[NSString stringWithUTF8String:name] lastPathComponent]:@"Mach-O";
 NSMutableArray<ZNMixedCustomerFeature *> *found=[NSMutableArray array];
 for(size_t i=0;i<package.features.size();i++){
  const auto &entry=package.features[i];
  ZNMixedCustomerFeature *f=[ZNMixedCustomerFeature new];
  f.identifier=ZNMString(entry.id);f.title=ZNMString(entry.name);
  if(!f.identifier.length||!f.title.length)return nil;
  f.imageName=image;f.imageUUID=uuid;f.imageHeader=base;
  f.descriptor=bytes;f.featureIndex=i;
  f.numericType=static_cast<uint8_t>(entry.type);
  f.featureKind=static_cast<uint8_t>(entry.kind);f.ruleCount=entry.count;
  [found addObject:f];
 }
 return found;
}
@interface ZNMixedCustomerRuntime () {
 ZNMixedValue::Coordinator _coordinator;
}
@property(nonatomic,copy,readwrite) NSString *lastDiagnostic;
@end
@implementation ZNMixedCustomerRuntime
+ (instancetype)shared {
 static ZNMixedCustomerRuntime *instance;static dispatch_once_t once;
 dispatch_once(&once,^{instance=[self new];});return instance;
}
- (instancetype)init {if((self=[super init]))_lastDiagnostic=@"";return self;}
- (BOOL)recoveryFailed {
 @synchronized(self){return _coordinator.recoveryFailed();}
}
- (NSString *)imageKey:(ZNMixedCustomerFeature *)f{
 return [NSString stringWithFormat:@"%@:%llX",f.imageUUID,(unsigned long long)f.imageHeader];
}
- (NSArray<ZNMixedCustomerFeature *> *)discover {
 @synchronized(self){
  NSMutableArray *found=[NSMutableArray array];
  for(uint32_t i=0;i<_dyld_image_count();i++){
   NSArray *features=ZNMCatalog(i);
   for(ZNMixedCustomerFeature *f in features){
    NSString *image=[self imageKey:f];
    f.enabled=_coordinator.active(std::string(image.UTF8String),std::string(f.identifier.UTF8String));
    [found addObject:f];
   }
  }
  return found;
 }
}
- (ZNMixedCustomerFeature *)currentFor:(ZNMixedCustomerFeature *)submitted error:(NSError **)error{
 if(!submitted.identifier.length||!submitted.imageUUID.length||!submitted.descriptor.length){
  if(error)*error=ZNMError(1,@"Feature ID 或映像信息无效");return nil;
 }
 for(ZNMixedCustomerFeature *f in [self discover])
  if([f.identifier isEqualToString:submitted.identifier]&&
     [f.imageUUID isEqualToString:submitted.imageUUID]&&
     f.imageHeader==submitted.imageHeader&&f.featureIndex==submitted.featureIndex&&
     [f.descriptor isEqualToData:submitted.descriptor])return f;
 if(error)*error=ZNMError(2,@"Feature ID、原始 ZNM2 或映像身份已发生变化");
 return nil;
}
- (BOOL)applyValue:(NSString *)decimal feature:(ZNMixedCustomerFeature *)feature error:(NSError **)error{
 @synchronized(self){
  if(_coordinator.recoveryFailed()){
   if(error)*error=ZNMError(3,@"恢复失败锁定，禁止继续写入");return NO;
  }
  ZNMixedCustomerFeature *f=[self currentFor:feature error:error];
  if(!f)return NO;
  if(![decimal isKindOfClass:NSString.class]||!decimal.length||decimal.length>128){
   if(error)*error=ZNMError(4,@"数值输入无效");return NO;
  }
  ZNMixedDescriptor::Package package;std::string reason;
  if(!ZNMixedDescriptor::decode((const uint8_t*)f.descriptor.bytes,f.descriptor.length,package,reason)||
     f.featureIndex>=package.features.size()){
   if(error)*error=ZNMError(5,@"ZNM2 记录不可信");return NO;
  }
  const auto &owner=package.features[f.featureIndex];
  std::vector<ZNLiveTypedValue::Cell> approved;
  std::vector<ZNTypedValue::Target> targets;
  for(size_t index=owner.start;index<owner.start+owner.count;index++){
   const auto &r=package.records[index];
   if(r.rva>UINTPTR_MAX-f.imageHeader){
    if(error)*error=ZNMError(6,@"数值 RVA 溢出");return NO;
   }
   approved.push_back({f.imageHeader,std::string(f.imageUUID.UTF8String),r.rva,r.type});
   targets.push_back({f.imageHeader+(uintptr_t)r.rva,r});
  }
  NSString *image=[self imageKey:f];
  auto backend=std::make_unique<ZNLiveTypedValue::Backend>(std::move(approved));
  BOOL ok=_coordinator.apply(std::string(image.UTF8String),std::string(f.identifier.UTF8String),
                             std::move(backend),targets,std::string(decimal.UTF8String),reason);
  self.lastDiagnostic=ok?@"独立数值事务已写入并读回验证":(ZNMString(reason)?:@"数值事务失败");
  if(!ok&&error)*error=ZNMError(7,self.lastDiagnostic);
  return ok;
 }
}
- (BOOL)restoreFeature:(ZNMixedCustomerFeature *)feature error:(NSError **)error {
 @synchronized(self){
  if(_coordinator.recoveryFailed()){
   if(error)*error=ZNMError(8,@"存在恢复失败锁定，不允许自动覆盖");return NO;
  }
  ZNMixedCustomerFeature *f=[self currentFor:feature error:error];
  if(!f)return NO;
  std::string reason;NSString *image=[self imageKey:f];
  BOOL ok=_coordinator.restore(std::string(image.UTF8String),
                   std::string(f.identifier.UTF8String),reason);
  self.lastDiagnostic=ok?@"该功能 Original 已读回验证":(ZNMString(reason)?:@"恢复失败");
  if(!ok&&error)*error=ZNMError(9,self.lastDiagnostic);
  return ok;
 }
}
@end
