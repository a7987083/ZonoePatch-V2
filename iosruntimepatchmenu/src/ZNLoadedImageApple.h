#pragma once
#include "ZNLoadedImage.h"
#include "ZNImageGeneration.h"
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <mach-o/loader.h>
inline bool ZNImageVMCopy(void *,uint64_t address,void *out,size_t length){
 if(address>UINTPTR_MAX)return false;
 vm_size_t copied=0;
 return vm_read_overwrite(mach_task_self(),(vm_address_t)address,(vm_size_t)length,(vm_address_t)out,&copied)==KERN_SUCCESS&&copied==length;
}
inline uint64_t ZNImageReadGeneration(void *){return ZNCurrentImageGeneration();}
inline std::shared_ptr<const znimage::Snapshot> ZNCaptureLoadedImage(uintptr_t address,const char **error=nullptr){
 return znimage::Snapshot::capture(address,{nullptr,ZNImageVMCopy,ZNImageReadGeneration},error);
}
