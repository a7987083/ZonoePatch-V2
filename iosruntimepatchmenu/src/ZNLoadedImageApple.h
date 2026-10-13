#pragma once
#include "ZNLoadedImage.h"
#include "ZNImageGeneration.h"
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <mach-o/loader.h>
inline bool ZNImageVMCopy(void *,uint64_t address,void *out,size_t length){
 mach_vm_size_t copied=0;
 return mach_vm_read_overwrite(mach_task_self(),(mach_vm_address_t)address,(mach_vm_size_t)length,(mach_vm_address_t)out,&copied)==KERN_SUCCESS&&copied==length;
}
inline uint64_t ZNImageReadGeneration(void *){return ZNCurrentImageGeneration();}
inline std::shared_ptr<const znimage::Snapshot> ZNCaptureLoadedImage(uintptr_t address,const char **error=nullptr){
 return znimage::Snapshot::capture(address,{nullptr,ZNImageVMCopy,ZNImageReadGeneration},error);
}
