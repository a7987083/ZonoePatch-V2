#include "ZNImageOperationLease.h"
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <cassert>
#include <iostream>
int main(int argc,char **argv){
 assert(argc==2);uint64_t before=ZNCurrentImageGeneration();void *handle=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);assert(handle);assert(ZNCurrentImageGeneration()>before);
 uintptr_t header=0;for(uint32_t i=0;i<_dyld_image_count();i++)if(strstr(_dyld_get_image_name(i),"loaded-image-fixture"))header=(uintptr_t)_dyld_get_image_header(i);
 assert(header);auto owner=znimage::Snapshot::capture(header,{nullptr,ZNImageVMCopy,ZNImageReadGeneration},nullptr,false);assert(owner);
 void *symbol=dlsym(handle,"ZNImageFixture");assert(symbol);uint32_t instruction=0;assert(owner->read((uintptr_t)symbol,&instruction,4));
 auto lifetime=ZNImageLifetimeForHeader(header);assert(lifetime);auto lease=ZNImageOperationLease::acquire(header,argv[1],lifetime->incarnation,false);assert(lease);assert(dlclose(handle)==0);assert(lifetime->live&&owner->valid());assert(((int(*)(void))symbol)()==42);lease.reset();assert(!lifetime->live);assert(!ZNImageOperationLease::acquire(header,argv[1],lifetime->incarnation,false));assert(!owner->valid());uint32_t unchanged=99;assert(!owner->read((uintptr_t)symbol,&unchanged,4)&&unchanged==99);
 uint8_t byte=99;assert(!ZNImageVMCopy(nullptr,1,&byte,1));
 std::cout<<"production Mach VM reader / actual dyld load-unload generation / stale snapshot PASS\n";
}
