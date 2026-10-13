#pragma once
#include "ZNLoadedImageApple.h"
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <string>
// Ephemeral loader retain, balanced on scope exit; never retained by records or
// caches. Main executable cannot unload and needs no artificial loader retain.
class ZNImageOperationLease {
 void *handle=nullptr;std::shared_ptr<znimage::Lifetime> lifetime;
 std::unique_lock<std::recursive_mutex> gate;
 ZNImageOperationLease(void *h,std::shared_ptr<znimage::Lifetime> s):handle(h),lifetime(std::move(s)),gate(lifetime->operations){}
public:
 std::shared_ptr<const znimage::Snapshot> image;
 ~ZNImageOperationLease(){gate.unlock();if(handle)dlclose(handle);}
 ZNImageOperationLease(const ZNImageOperationLease&)=delete;
 void *nativeHandle()const{return handle;}
 uint64_t incarnation()const{return lifetime->incarnation;}
 bool valid()const{return lifetime->live.load(std::memory_order_acquire)&&image&&image->valid();}
 static std::unique_ptr<ZNImageOperationLease> acquire(uintptr_t base,const char *path,uint64_t expected=0,bool arm64=true){
  auto state=ZNImageLifetimeForHeader(base);if(!state||!state->live||(expected&&state->incarnation!=expected))return {};
  const bool main=base==(uintptr_t)_dyld_get_image_header(0);
  void *h=main?nullptr:((path&&*path)?dlopen(path,RTLD_NOLOAD|RTLD_LAZY):nullptr);
  if(!main&&!h)return {};
  if(ZNImageLifetimeForHeader(base)!=state||!state->live){if(h)dlclose(h);return {};}
  auto lease=std::unique_ptr<ZNImageOperationLease>(new ZNImageOperationLease(h,state));
  lease->image=znimage::Snapshot::capture(base,{nullptr,ZNImageVMCopy,ZNImageReadGeneration},nullptr,arm64);
  if(!lease->valid())return {};
  return lease;
 }
 bool load64(uintptr_t address,uint64_t *out){if(!out||(address&7)||!valid()||!image->contains(address,8,VM_PROT_READ))return false;*out=__atomic_load_n((const uint64_t *)address,__ATOMIC_ACQUIRE);return valid();}
 bool store(uintptr_t address,uint64_t value,size_t width){if((width!=4&&width!=8)||(address&(width-1))||!valid()||!image->contains(address,width,VM_PROT_READ|VM_PROT_WRITE))return false;if(width==8)__atomic_store_n((uint64_t *)address,value,__ATOMIC_RELEASE);else __atomic_store_n((uint32_t *)address,(uint32_t)value,__ATOMIC_RELEASE);return valid();}
};
inline std::string ZNImagePathForHeader(uintptr_t base){
 for(uint32_t i=0;i<_dyld_image_count();++i){if((uintptr_t)_dyld_get_image_header(i)!=base)continue;const char *name=_dyld_get_image_name(i);if(!name)return {};std::string result;for(size_t n=0;n<4096;n++){char c=0;if(!ZNImageVMCopy(nullptr,(uintptr_t)name+n,&c,1))return {};if(!c)return result;result.push_back(c);}return {};}
 return {};
}
inline std::unique_ptr<ZNImageOperationLease> ZNLeaseForHeader(uintptr_t base,uint64_t expected=0){auto path=ZNImagePathForHeader(base);return ZNImageOperationLease::acquire(base,path.c_str(),expected);}
