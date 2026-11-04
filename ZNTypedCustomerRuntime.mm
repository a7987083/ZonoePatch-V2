#import "ZNTypedCustomerRuntime.h"
#include "ZNLiveTypedValueBackend.hpp"
#include "ZNTypedDescriptor.hpp"
#include "ZNTypedValueTransaction.hpp"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/vm_prot.h>
#include <memory>
#include <string>
#include <vector>
#include <cstring>

static NSError *ZNTCustomerError(NSInteger code,NSString *reason) {
 return [NSError errorWithDomain:@"ZonoePatch.Customer.Typed" code:code
  userInfo:@{NSLocalizedDescriptionKey:reason?:@"Typed value error"}];
}
static BOOL ZNTRead(uintptr_t address,void *out,size_t length) {
 if(!address||!out||!length||address>UINTPTR_MAX-length)return NO;
 vm_size_t got=0;
 return vm_read_overwrite(mach_task_self(),(vm_address_t)address,
   (vm_size_t)length,(vm_address_t)out,&got)==KERN_SUCCESS&&got==length;
}
static BOOL ZNTSlide(uint64_t preferred,intptr_t slide,uintptr_t *out) {
 __int128 sum=(__int128)preferred+(__int128)slide;
 if(sum<=0||sum>UINTPTR_MAX)return NO;
 *out=(uintptr_t)sum;return YES;
}
static BOOL ZNTRegion(uintptr_t address,size_t length,vm_prot_t required) {
 if(!address||!length||address>UINTPTR_MAX-length)return NO;
 vm_address_t start=address;vm_size_t size=0;
 vm_region_basic_info_data_64_t info={};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;
 mach_port_t object=MACH_PORT_NULL;
 kern_return_t k=vm_region_64(mach_task_self(),&start,&size,VM_REGION_BASIC_INFO_64,
                                  (vm_region_info_t)&info,&count,&object);
 if(object!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),object);
 return k==KERN_SUCCESS&&start<=address&&length<=size&&address-start<=size-length&&
    (info.protection&required)==required&&!(info.protection&VM_PROT_WRITE)&&
    !(info.protection&VM_PROT_EXECUTE);
}
@interface ZNTypedCustomerFeature ()
@property(nonatomic,copy,readwrite) NSString *identifier;
@property(nonatomic,copy,readwrite) NSString *imageName;
@property(nonatomic,copy,readwrite) NSString *title;
@property(nonatomic,copy,readwrite) NSString *minimum;
@property(nonatomic,copy,readwrite) NSString *maximum;
@property(nonatomic,copy,readwrite) NSString *step;
@property(nonatomic,copy,readwrite) NSString *defaultValue;
@property(nonatomic,assign,readwrite) NSUInteger numericType;
@property(nonatomic,assign,readwrite) NSUInteger featureKind;
@property(nonatomic,assign,readwrite) NSUInteger ruleCount;
@property(nonatomic,assign,readwrite,getter=isEnabled) BOOL enabled;
@property(nonatomic,assign) uintptr_t imageHeader;
@property(nonatomic,copy) NSString *imageUUID;
@property(nonatomic,copy) NSData *descriptorBytes;
@end
@implementation ZNTypedCustomerFeature @end

@interface ZNTypedSession : NSObject {
 @public std::unique_ptr<ZNLiveTypedValue::Backend> backend;
 @public std::unique_ptr<ZNTypedValue::Transaction> transaction;
}
@property(nonatomic,copy) NSData *descriptorBytes;
@property(nonatomic,assign) uintptr_t imageHeader;
@end
@implementation ZNTypedSession @end

static ZNTypedCustomerFeature *ZNTCatalogImage(uint32_t index) {
 const struct mach_header *raw=_dyld_get_image_header(index);
 if(!raw||raw->magic!=MH_MAGIC_64||raw->cputype!=CPU_TYPE_ARM64)return nil;
 uintptr_t imageHeader=(uintptr_t)raw;
 struct mach_header_64 h={};
 if(!ZNTRead(imageHeader,&h,sizeof(h))||!h.ncmds||h.ncmds>4096||
    !h.sizeofcmds||h.sizeofcmds>1024*1024||
    imageHeader>UINTPTR_MAX-sizeof(h)||
    h.sizeofcmds>UINTPTR_MAX-imageHeader-sizeof(h))return nil;
 std::vector<uint8_t> commands(h.sizeofcmds);
 if(!ZNTRead(imageHeader+sizeof(h),commands.data(),commands.size()))return nil;
 uint64_t textVM=UINT64_MAX,sectionVM=0,sectionSize=0;
 NSUInteger position=0,uuidCount=0,segmentCount=0;
 NSString *uuid=nil;
 intptr_t slide=_dyld_get_image_vmaddr_slide(index);
 for(uint32_t i=0;i<h.ncmds;++i){
  if(position>commands.size()||commands.size()-position<sizeof(struct load_command))return nil;
  struct load_command cmd={};std::memcpy(&cmd,commands.data()+position,sizeof(cmd));
  if(cmd.cmdsize<sizeof(cmd)||cmd.cmdsize>commands.size()-position)return nil;
  if(cmd.cmd==LC_UUID){
   if(cmd.cmdsize<sizeof(struct uuid_command))return nil;
   struct uuid_command u={};std::memcpy(&u,commands.data()+position,sizeof(u));
   uuid=[[[NSUUID alloc]initWithUUIDBytes:u.uuid] UUIDString];uuidCount++;
  }
  if(cmd.cmd==LC_SEGMENT_64){
   if(cmd.cmdsize<sizeof(struct segment_command_64))return nil;
   struct segment_command_64 s={};std::memcpy(&s,commands.data()+position,sizeof(s));
   if(!std::strncmp(s.segname,"__TEXT",16)&&s.fileoff==0){
    if(textVM!=UINT64_MAX)return nil;
    textVM=s.vmaddr;
   }
   if(!std::strncmp(s.segname,"__ZNTYPE",16)){
    segmentCount++;
    if(s.initprot!=VM_PROT_READ||s.maxprot!=VM_PROT_READ||
       s.nsects!=1||cmd.cmdsize<sizeof(s)+sizeof(struct section_64))return nil;
    struct section_64 sec={};
    std::memcpy(&sec,commands.data()+position+sizeof(s),sizeof(sec));
    if(std::strncmp(sec.sectname,"__zntype",16)||
       std::strncmp(sec.segname,"__ZNTYPE",16)||
       sec.addr<s.vmaddr||sec.size>s.vmsize||
       sec.addr-s.vmaddr>s.vmsize-sec.size||
       sec.size<12||sec.size>12+128*48||
       sec.offset<s.fileoff||sec.offset-s.fileoff>s.filesize||
       sec.size>s.filesize-(sec.offset-s.fileoff))return nil;
    sectionVM=sec.addr;sectionSize=sec.size;
   }
  }
  position+=cmd.cmdsize;
 }
 if(segmentCount!=1||uuidCount!=1||!uuid.length||textVM==UINT64_MAX||
    !sectionVM||!sectionSize)return nil;
 uintptr_t runtimeText=0,sectionAddr=0;
 if(!ZNTSlide(textVM,slide,&runtimeText)||runtimeText!=imageHeader||
    !ZNTSlide(sectionVM,slide,&sectionAddr)||
    !ZNTRegion(sectionAddr,(size_t)sectionSize,VM_PROT_READ))return nil;
 NSMutableData *data=[NSMutableData dataWithLength:(NSUInteger)sectionSize];
 if(!ZNTRead(sectionAddr,data.mutableBytes,data.length))return nil;
 std::vector<ZNTypedDescriptor::Record> records;std::string diagnostic;
 if(!ZNTypedDescriptor::decode((const uint8_t *)data.bytes,data.length,records,diagnostic)||
    records.empty())return nil;
 const auto &first=records.front();
 // P10.3.2 exports a single numeric feature per image. Treat all its rules
 // as one transaction; never silently split a group into separate controls.
 for(const auto &r:records)
  if(r.type!=first.type||r.kind!=first.kind||
     r.minimum!=first.minimum||r.maximum!=first.maximum||
     r.step!=first.step||r.defaultValue!=first.defaultValue||
     r.requiresEnableSwitch!=first.requiresEnableSwitch)return nil;
 ZNTypedCustomerFeature *feature=[ZNTypedCustomerFeature new];
 feature.imageHeader=imageHeader;feature.imageUUID=uuid;feature.descriptorBytes=data;
 feature.identifier=[NSString stringWithFormat:@"typed:%@:%llX",uuid,
                         (unsigned long long)imageHeader];
 const char *image=_dyld_get_image_name(index);
 feature.imageName=image?[[NSString stringWithUTF8String:image] lastPathComponent]:@"Mach-O";
 feature.title=[NSString stringWithFormat:@"数值功能 · %@",feature.imageName];
 feature.numericType=(NSUInteger)first.type;
 feature.featureKind=(NSUInteger)first.kind;feature.ruleCount=records.size();
 feature.minimum=[NSString stringWithUTF8String:first.minimum.c_str()];
 feature.maximum=[NSString stringWithUTF8String:first.maximum.c_str()];
 feature.step=[NSString stringWithUTF8String:first.step.c_str()];
 feature.defaultValue=[NSString stringWithUTF8String:first.defaultValue.c_str()];
 return feature;
}
@interface ZNTypedCustomerRuntime ()
@property(nonatomic,strong) NSMutableDictionary<NSString *,ZNTypedSession *> *activeSessions;
@property(nonatomic,copy,readwrite) NSString *lastDiagnostic;
@end
@implementation ZNTypedCustomerRuntime
+ (instancetype)shared {
 static ZNTypedCustomerRuntime *instance;static dispatch_once_t once;
 dispatch_once(&once,^{instance=[self new];});return instance;
}
- (instancetype)init {
 if((self=[super init])){_activeSessions=[NSMutableDictionary dictionary];_lastDiagnostic=@"";}
 return self;
}
- (BOOL)recoveryFailed {
 @synchronized(self) {
  for(ZNTypedSession *s in self.activeSessions.allValues)
   if(s->transaction&&s->transaction->recoveryFailed())return YES;
  return NO;
 }
}
- (NSArray<ZNTypedCustomerFeature *> *)discover {
 @synchronized(self) {
  NSMutableArray<ZNTypedCustomerFeature *> *features=[NSMutableArray array];
  for(uint32_t i=0;i<_dyld_image_count();++i){
   ZNTypedCustomerFeature *feature=ZNTCatalogImage(i);
   if(!feature)continue;
   ZNTypedSession *session=self.activeSessions[feature.identifier];
   feature.enabled=session&&session->transaction&&session->transaction->active()&&
                    [session.descriptorBytes isEqualToData:feature.descriptorBytes];
   [features addObject:feature];
  }
  return features;
 }
}
- (ZNTypedCustomerFeature *)currentFor:(ZNTypedCustomerFeature *)feature
                                error:(NSError **)error {
 if(!feature.identifier.length||!feature.descriptorBytes.length){
  if(error)*error=ZNTCustomerError(10,@"数值功能身份无效");return nil;
 }
 for(ZNTypedCustomerFeature *current in [self discover])
  if([current.identifier isEqualToString:feature.identifier] &&
     current.imageHeader==feature.imageHeader &&
     [current.imageUUID isEqualToString:feature.imageUUID] &&
     [current.descriptorBytes isEqualToData:feature.descriptorBytes])return current;
 if(error)*error=ZNTCustomerError(11,@"映像卸载、UUID 或 Typed Descriptor 已变化");
 return nil;
}
- (BOOL)applyValue:(NSString *)decimal feature:(ZNTypedCustomerFeature *)feature
             error:(NSError **)error {
 @synchronized(self) {
  if(self.recoveryFailed){if(error)*error=ZNTCustomerError(12,@"存在回滚失败，数值执行已锁定");return NO;}
  ZNTypedCustomerFeature *current=[self currentFor:feature error:error];
  if(!current)return NO;
  if(self.activeSessions[current.identifier]){
   if(error)*error=ZNTCustomerError(13,@"该数值功能已经提交或处于锁定状态");return NO;
  }
  if(![decimal isKindOfClass:NSString.class]||!decimal.length||decimal.length>128){
   if(error)*error=ZNTCustomerError(14,@"输入数值无效");return NO;
  }
  std::vector<ZNTypedDescriptor::Record> records;std::string diagnostic;
  if(!ZNTypedDescriptor::decode((const uint8_t *)current.descriptorBytes.bytes,
       current.descriptorBytes.length,records,diagnostic)){
   if(error)*error=ZNTCustomerError(15,@"数值描述符损坏");return NO;
  }
  std::vector<ZNLiveTypedValue::Cell> cells;std::vector<ZNTypedValue::Target> targets;
  for(const auto &r:records){
   if(r.rva>UINTPTR_MAX-current.imageHeader){
    if(error)*error=ZNTCustomerError(16,@"数值地址溢出");return NO;
   }
   uintptr_t address=current.imageHeader+(uintptr_t)r.rva;
   cells.push_back({current.imageHeader,std::string(current.imageUUID.UTF8String),r.rva,r.type});
   targets.push_back({address,r});
  }
  // One metadata section per image. Multiple active transactions on the same
  // address space are disallowed to avoid overlapping rollback ownership.
  for(ZNTypedSession *s in self.activeSessions.allValues)
   if(s.imageHeader==current.imageHeader){
    if(error)*error=ZNTCustomerError(17,@"此映像已有未恢复的数值事务");return NO;
   }
  ZNTypedSession *session=[ZNTypedSession new];
  session.imageHeader=current.imageHeader;session.descriptorBytes=current.descriptorBytes;
  session->backend=std::make_unique<ZNLiveTypedValue::Backend>(std::move(cells));
  session->transaction=std::make_unique<ZNTypedValue::Transaction>(*session->backend);
  if(!session->transaction->commit(targets,std::string(decimal.UTF8String),diagnostic)){
   self.lastDiagnostic=[NSString stringWithUTF8String:diagnostic.c_str()];
   if(session->transaction->recoveryFailed())self.activeSessions[current.identifier]=session;
   if(error)*error=ZNTCustomerError(18,self.lastDiagnostic);return NO;
  }
  self.activeSessions[current.identifier]=session;
  self.lastDiagnostic=@"数值写入及读回校验成功";
  return YES;
 }
}
- (BOOL)restoreFeature:(ZNTypedCustomerFeature *)feature error:(NSError **)error {
 @synchronized(self) {
  if(self.recoveryFailed){if(error)*error=ZNTCustomerError(19,@"存在回滚失败，自动恢复已锁定");return NO;}
  ZNTypedSession *session=self.activeSessions[feature.identifier];
  if(!session||!session->transaction||!session->transaction->active()){
   if(error)*error=ZNTCustomerError(20,@"没有需要恢复的数值事务");return NO;
  }
  if(![self currentFor:feature error:error])return NO;
  std::string diagnostic;
  if(!session->transaction->restore(diagnostic)){
   self.lastDiagnostic=[NSString stringWithUTF8String:diagnostic.c_str()];
   if(error)*error=ZNTCustomerError(21,self.lastDiagnostic);return NO;
  }
  [self.activeSessions removeObjectForKey:feature.identifier];
  self.lastDiagnostic=@"Original 恢复并读回验证成功";
  return YES;
 }
}
@end
