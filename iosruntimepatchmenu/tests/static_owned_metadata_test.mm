#import "ZNStaticPatchRecordInternal.h"
#include "ZNImageOperationLease.h"
#include "ZNStaticValueCellAccess.h"
#include "ZNStaticValueCellWriter.h"
#include <cassert>
#include <thread>
#include "ZNStaticOperationGate.h"
#import <dlfcn.h>
@interface ZNStaticDispatchRuntime (FixtureConsume)
- (BOOL)zn44_consumeHeader:(const ZN44StaticHeader *)header address:(uintptr_t)address regionEnd:(uintptr_t)end runtimeHeader:(uintptr_t)base targetName:(NSString *)name found:(NSMutableArray *)found liveSiteKeys:(NSMutableSet *)keys;
@end
int main(int argc,char **argv){@autoreleasepool{
 assert(argc==2);ZNCurrentImageGeneration();void *handle=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);assert(handle);auto tableFn=(void*(*)(void))dlsym(handle,"ZNFixtureTable");assert(tableFn);uintptr_t table=(uintptr_t)tableFn();Dl_info info={};assert(dladdr((void*)tableFn,&info));uintptr_t base=(uintptr_t)info.dli_fbase;uint64_t off=(uintptr_t)dlsym(handle,"ZNFixtureOff")-base,onA=(uintptr_t)dlsym(handle,"ZNFixtureA")-base,onB=(uintptr_t)dlsym(handle,"ZNFixtureB")-base;
 auto header=(ZN44StaticHeader *)table;*header={};header->magic0=ZN44_STATIC_MAGIC0;header->magic1=ZN44_STATIC_MAGIC1;header->version=ZN44_STATIC_VERSION_V2;header->flags=ZN44_STATIC_HEADER_FLAG_VALUE_CELLS_V1;header->count=2;header->entrySize=sizeof(ZN44StaticEntry);auto entries=(ZN44StaticEntry *)(header+1);
 for(unsigned i=0;i<2;i++){entries[i]={};entries[i].flags=ZN44_STATIC_ENTRY_FLAG_VALUE_CELL_V1|ZN44StaticValueCellTypeFlags(ZNValueTypeI32);entries[i].patchID=i+1;entries[i].physicalID=1;entries[i].canonicalIndex=0;entries[i].offRVA=off;entries[i].onRVA=i?onB:onA;entries[i].siteRVA=off;strcpy(entries[i].title,i?"B":"A");}entries[0].selectedTarget=base+off;
 ZNStaticDispatchRuntime *runtime=[ZNStaticDispatchRuntime sharedRuntime];NSMutableArray *found=[NSMutableArray array];assert([runtime zn44_consumeHeader:header address:table regionEnd:table+64+2*128+24+2*128 runtimeHeader:base targetName:@"fixture" found:found liveSiteKeys:[NSMutableSet set]]);assert(found.count==2);[runtime setValue:found forKey:@"records"];ZNStaticPatchRecord *a=found[0],*b=found[1];assert(a.entry!=entries&&a.entryAddress==(uintptr_t)entries);strcpy(entries[0].title,"changed");assert(strcmp(a.entry->title,"A")==0);NSString *error=nil;
 assert([runtime setEnabled:YES forRecord:a error:&error]&&entries[0].selectedTarget==base+onA);assert([runtime setEnabled:YES forRecord:b error:&error]&&entries[0].selectedTarget==base+onB);assert([runtime setEnabled:NO forRecord:b error:&error]&&entries[0].selectedTarget==base+onA);assert([runtime setEnabled:NO forRecord:a error:&error]&&entries[0].selectedTarget==base+off);
 {auto writeLease=ZNLeaseForHeader(base,a.imageIncarnation);assert(writeLease);ZNValueType type=ZNValueTypeAuto;uintptr_t cell=ZNStaticValueCellAddressForRecord(a,*writeLease,&type,&error);assert(cell&&type==ZNValueTypeI32);assert(writeLease->store(cell,123,4));uint32_t value=0;assert(writeLease->image->read(cell,&value,4)&&value==123);assert(ZNM56WriteTextToCell(@"2147483647",type,cell,*writeLease,&error));assert(!ZNM56WriteTextToCell(@"2147483648",type,cell,*writeLease,&error));assert(!ZNM56WriteTextToCell(@"1e100",ZNValueTypeF32,cell,*writeLease,&error));assert(!ZNM56WriteTextToCell(@"nan",ZNValueTypeF64,cell,*writeLease,&error));assert(!ZNM56WriteTextToCell(@"1",type,cell+1,*writeLease,&error));
 uint32_t savedCount=header->count,savedVersion=header->version;header->count=ZN44_STATIC_MAX_ENTRIES;assert(!ZNStaticValueCellAddressForRecord(a,*writeLease,&type,&error));header->count=savedCount;header->version=UINT32_MAX;assert(!ZNStaticValueCellAddressForRecord(a,*writeLease,&type,&error));header->version=savedVersion;
 a.entryIndex=UINT32_MAX;assert(!ZNStaticValueCellAddressForRecord(a,*writeLease,&type,&error));a.entryIndex=0;}
 std::thread writer([&]{@autoreleasepool{for(int i=0;i<100;i++){NSString *e=nil;assert([runtime setEnabled:YES forRecord:a error:&e]);assert([runtime setEnabled:NO forRecord:a error:&e]);}}});
 std::thread cellWriter([&]{@autoreleasepool{for(int i=0;i<100;i++){std::lock_guard<std::recursive_mutex> g(ZNStaticOperationGate());auto lease=ZNLeaseForHeader(base,a.imageIncarnation);assert(lease);ZNValueType t=ZNValueTypeAuto;NSString *e=nil;uintptr_t cell=ZNStaticValueCellAddressForRecord(a,*lease,&t,&e);assert(cell&&lease->store(cell,i,4));assert([runtime setEnabled:YES forRecord:b error:&e]);}}});std::thread observer([&]{@autoreleasepool{for(int i=0;i<100;i++){NSArray *snapshot=runtime.records;assert(snapshot.count==2);assert([runtime diagnosticLines].count>=2);for(ZNStaticPatchRecord *r in snapshot){(void)r.isEnabled;assert(r.entry);}}}});writer.join();cellWriter.join();observer.join();
 uint64_t savedOff=entries[0].offRVA,savedTarget=entries[0].selectedTarget;entries[0].offRVA=UINT64_MAX;assert(![runtime zn44_consumeHeader:header address:table regionEnd:table+64+2*128+24+2*128 runtimeHeader:base targetName:@"malformed" found:[NSMutableArray array] liveSiteKeys:[NSMutableSet set]]);assert(entries[0].selectedTarget==savedTarget);entries[0].offRVA=savedOff;
 uint64_t savedSecondOff=entries[1].offRVA;uint32_t savedCanonical=entries[1].canonicalIndex;
 entries[0].selectedTarget=1;entries[1].canonicalIndex=1;entries[1].offRVA=UINT64_MAX;
 NSMutableArray *rejected=[NSMutableArray array];NSMutableSet *rejectedKeys=[NSMutableSet set];
 assert(![runtime zn44_consumeHeader:header address:table regionEnd:table+64+2*128+24+2*128 runtimeHeader:base targetName:@"late-malformed" found:rejected liveSiteKeys:rejectedKeys]);
 assert(entries[0].selectedTarget==1&&rejected.count==0&&rejectedKeys.count==0);
 entries[0].selectedTarget=savedTarget;entries[1].canonicalIndex=savedCanonical;entries[1].offRVA=savedSecondOff;
 {auto revoked=ZNLeaseForHeader(base,a.imageIncarnation);assert(revoked);ZNValueType t=ZNValueTypeAuto;uintptr_t cell=ZNStaticValueCellAddressForRecord(a,*revoked,&t,&error);assert(cell);auto state=ZNImageLifetimeForHeader(base);state->live=false;assert(!ZNM56WriteTextToCell(@"7",t,cell,*revoked,&error));state->live=true;}
 uint64_t incarnation=a.imageIncarnation;assert(dlclose(handle)==0);assert(strcmp(a.entry->title,"A")==0);assert(![runtime setEnabled:YES forRecord:a error:&error]);assert(error.length);handle=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);assert(handle);assert(!ZNLeaseForHeader(base,incarnation));assert(![runtime setEnabled:YES forRecord:a error:&error]);assert(dlclose(handle)==0);
 puts("production Static Dispatch owned entries/shared-owner activation/scoped write/unload/reload stale-record rejection PASS");
}}
