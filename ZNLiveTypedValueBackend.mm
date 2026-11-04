#include "ZNLiveTypedValueBackend.hpp"
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/vm_prot.h>
#include <cstring>
#include <limits>

namespace ZNLiveTypedValue {
namespace {
static bool memoryRead(uintptr_t address,void *dst,size_t length){
 if(!address||!dst||!length||length>8||address>UINTPTR_MAX-length)return false;
 vm_size_t got=0;
 return vm_read_overwrite(mach_task_self(),(vm_address_t)address,(vm_size_t)length,
                          (vm_address_t)dst,&got)==KERN_SUCCESS&&got==length;
}
static bool region(uintptr_t address,size_t n,vm_prot_t protection){
 if(!address||!n||address>UINTPTR_MAX-n)return false;
 vm_address_t start=(vm_address_t)address;vm_size_t size=0;
 vm_region_basic_info_data_64_t info={};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;
 mach_port_t object=MACH_PORT_NULL;
 kern_return_t result=vm_region_64(mach_task_self(),&start,&size,VM_REGION_BASIC_INFO_64,
                                  (vm_region_info_t)&info,&count,&object);
 if(object!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),object);
 return result==KERN_SUCCESS&&start<=address&&n<=size&&address-start<=size-n&&
        (info.protection&protection)==protection&&
        !(info.protection&VM_PROT_EXECUTE);
}
static uint64_t little(const uint8_t *bytes,size_t length){
 uint64_t value=0;
 for(size_t i=0;i<length;i++)value|=static_cast<uint64_t>(bytes[i])<<(8*i);
 return value;
}
static bool store(uintptr_t address,const uint8_t *bytes,size_t width){
 switch(width){
  case 1:__atomic_store_n((uint8_t *)address,(uint8_t)little(bytes,width),__ATOMIC_SEQ_CST);return true;
  case 2:__atomic_store_n((uint16_t *)address,(uint16_t)little(bytes,width),__ATOMIC_SEQ_CST);return true;
  case 4:__atomic_store_n((uint32_t *)address,(uint32_t)little(bytes,width),__ATOMIC_SEQ_CST);return true;
  case 8:__atomic_store_n((uint64_t *)address,(uint64_t)little(bytes,width),__ATOMIC_SEQ_CST);return true;
  default:return false;
 }
}
} // namespace
Backend::Backend(std::vector<Cell> approved):approved_(std::move(approved)){}
bool Backend::validate(uintptr_t address,size_t width,bool writing,std::string &error)const{
 if(!address||!(width==1||width==2||width==4||width==8)||address%width){
  error="invalid or unaligned numeric address";return false;
 }
 const Cell *cell=nullptr;
 for(const Cell &candidate:approved_){
  if(ZNValueCodec::width(candidate.type)!=width)continue;
  if(candidate.imageHeader>UINTPTR_MAX-candidate.rva)continue;
  if(candidate.imageHeader+candidate.rva==address){
   if(cell){error="ambiguous approved numeric address";return false;}
   cell=&candidate;
  }
 }
 if(!cell){error="numeric address not in approved descriptor cells";return false;}
 bool loaded=false;
 for(uint32_t i=0;i<_dyld_image_count();++i)
  if((uintptr_t)_dyld_get_image_header(i)==cell->imageHeader){loaded=true;break;}
 if(!loaded){error="target image unloaded or changed";return false;}
 struct mach_header_64 h={};
 vm_size_t got=0;
 if(vm_read_overwrite(mach_task_self(),(vm_address_t)cell->imageHeader,sizeof(h),
       (vm_address_t)&h,&got)!=KERN_SUCCESS||got!=sizeof(h)||h.magic!=MH_MAGIC_64||
    h.cputype!=CPU_TYPE_ARM64||!h.ncmds||h.ncmds>4096||
    !h.sizeofcmds||h.sizeofcmds>1024*1024){
  error="invalid live arm64 image header";return false;
 }
 if(cell->imageHeader>UINTPTR_MAX-sizeof(h)||
    h.sizeofcmds>UINTPTR_MAX-cell->imageHeader-sizeof(h)){
  error="load commands address overflow";return false;
 }
 std::vector<uint8_t> commands(h.sizeofcmds);
 got=0;
 if(vm_read_overwrite(mach_task_self(),(vm_address_t)(cell->imageHeader+sizeof(h)),
     (vm_size_t)commands.size(),(vm_address_t)commands.data(),&got)!=KERN_SUCCESS||
    got!=commands.size()){error="live load commands unreadable";return false;}
 NSString *expected=[NSString stringWithUTF8String:cell->imageUUID.c_str()];
 if(!expected.length){error="missing expected image UUID";return false;}
 BOOL uuidMatched=NO;
 NSUInteger position=0,uuidCount=0;
 uint64_t textPreferred=UINT64_MAX;
 std::vector<struct segment_command_64> segments;
 for(uint32_t i=0;i<h.ncmds;++i){
  if(position>commands.size()||commands.size()-position<sizeof(struct load_command)){
   error="truncated load commands";return false;
  }
  struct load_command cmd={};memcpy(&cmd,commands.data()+position,sizeof(cmd));
  if(cmd.cmdsize<sizeof(cmd)||cmd.cmdsize>commands.size()-position){
   error="corrupt load command size";return false;
  }
  if(cmd.cmd==LC_UUID){
   if(cmd.cmdsize<sizeof(struct uuid_command)){error="invalid LC_UUID";return false;}
   struct uuid_command uuid={};memcpy(&uuid,commands.data()+position,sizeof(uuid));
   NSString *actual=[[[NSUUID alloc]initWithUUIDBytes:uuid.uuid] UUIDString];
   uuidMatched=[actual caseInsensitiveCompare:expected]==NSOrderedSame;
   ++uuidCount;
  }else if(cmd.cmd==LC_SEGMENT_64){
   if(cmd.cmdsize<sizeof(struct segment_command_64)){error="invalid LC_SEGMENT";return false;}
   struct segment_command_64 seg={};memcpy(&seg,commands.data()+position,sizeof(seg));
   if(!std::strncmp(seg.segname,"__TEXT",16))textPreferred=seg.vmaddr;
   segments.push_back(seg);
  }
  position+=cmd.cmdsize;
 }
 if(uuidCount!=1||!uuidMatched||textPreferred==UINT64_MAX){
  error="live image UUID mismatch";return false;
 }
 bool inRWData=false;
 for(const auto &seg:segments){
  if(seg.vmaddr<textPreferred||seg.vmaddr-textPreferred>cell->rva)continue;
  uint64_t relative=cell->rva-(seg.vmaddr-textPreferred);
  if(relative>seg.filesize||width>seg.filesize-relative)continue;
  // A code segment, including __TEXT, is never an allowed numeric destination.
  if((seg.initprot&(VM_PROT_READ|VM_PROT_WRITE))!=(VM_PROT_READ|VM_PROT_WRITE)||
     (seg.initprot&VM_PROT_EXECUTE))continue;
  inRWData=true;break;
 }
 if(!inRWData||!region(address,width,VM_PROT_READ|(writing?VM_PROT_WRITE:0))){
  error="typed target is not in a current file-backed RW data segment";return false;
 }
 return true;
}
bool Backend::read(uintptr_t address,uint8_t *dst,size_t n,std::string &error){
 if(!dst||!validate(address,n,false,error))return false;
 if(!memoryRead(address,dst,n)){error="numeric data read failed";return false;}
 error.clear();return true;
}
bool Backend::write(uintptr_t address,const uint8_t *src,size_t n,std::string &error){
 if(!src||!validate(address,n,true,error))return false;
 if(!store(address,src,n)){error="unsupported atomic numeric width";return false;}
 error.clear();return true;
}
} // namespace ZNLiveTypedValue
