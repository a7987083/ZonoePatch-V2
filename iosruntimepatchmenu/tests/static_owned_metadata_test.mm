#import "ZNStaticPatchRecordInternal.h"
#include "ZNImageOperationLease.h"
#include <cassert>
#import <dlfcn.h>
@interface ZNStaticDispatchRuntime (FixtureConsume)
- (BOOL)zn44_consumeHeader:(const ZN44StaticHeader *)header address:(uintptr_t)address regionEnd:(uintptr_t)end runtimeHeader:(uintptr_t)base targetName:(NSString *)name found:(NSMutableArray *)found liveSiteKeys:(NSMutableSet *)keys;
@end
int main(int argc,char **argv){@autoreleasepool{
 assert(argc==2);ZNCurrentImageGeneration();void *handle=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);assert(handle);auto tableFn=(void*(*)(void))dlsym(handle,"ZNFixtureTable");assert(tableFn);uintptr_t table=(uintptr_t)tableFn();Dl_info info={};assert(dladdr((void*)tableFn,&info));uintptr_t base=(uintptr_t)info.dli_fbase;uint64_t off=(uintptr_t)dlsym(handle,"ZNFixtureOff")-base,onA=(uintptr_t)dlsym(handle,"ZNFixtureA")-base,onB=(uintptr_t)dlsym(handle,"ZNFixtureB")-base;
 auto header=(ZN44StaticHeader *)table;*header={};header->magic0=ZN44_STATIC_MAGIC0;header->magic1=ZN44_STATIC_MAGIC1;header->version=ZN44_STATIC_VERSION_V2;header->count=2;header->entrySize=sizeof(ZN44StaticEntry);auto entries=(ZN44StaticEntry *)(header+1);
 for(unsigned i=0;i<2;i++){entries[i]={};entries[i].patchID=i+1;entries[i].physicalID=1;entries[i].canonicalIndex=0;entries[i].offRVA=off;entries[i].onRVA=i?onB:onA;entries[i].siteRVA=off;strcpy(entries[i].title,i?"B":"A");}entries[0].selectedTarget=base+off;
 ZNStaticDispatchRuntime *runtime=[ZNStaticDispatchRuntime sharedRuntime];NSMutableArray *found=[NSMutableArray array];assert([runtime zn44_consumeHeader:header address:table regionEnd:table+64+2*128+24+2*128 runtimeHeader:base targetName:@"fixture" found:found liveSiteKeys:[NSMutableSet set]]);assert(found.count==2);[runtime setValue:found forKey:@"records"];ZNStaticPatchRecord *a=found[0],*b=found[1];assert(a.entry!=entries&&a.entryAddress==(uintptr_t)entries);strcpy(entries[0].title,"changed");assert(strcmp(a.entry->title,"A")==0);NSString *error=nil;
 assert([runtime setEnabled:YES forRecord:a error:&error]&&entries[0].selectedTarget==base+onA);assert([runtime setEnabled:YES forRecord:b error:&error]&&entries[0].selectedTarget==base+onB);assert([runtime setEnabled:NO forRecord:b error:&error]&&entries[0].selectedTarget==base+onA);assert([runtime setEnabled:NO forRecord:a error:&error]&&entries[0].selectedTarget==base+off);
 uint64_t incarnation=a.imageIncarnation;assert(dlclose(handle)==0);assert(strcmp(a.entry->title,"A")==0);assert(![runtime setEnabled:YES forRecord:a error:&error]);assert(error.length);handle=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);assert(handle);assert(!ZNLeaseForHeader(base,incarnation));assert(![runtime setEnabled:YES forRecord:a error:&error]);assert(dlclose(handle)==0);
 puts("production Static Dispatch owned entries/shared-owner activation/scoped write/unload/reload stale-record rejection PASS");
}}
