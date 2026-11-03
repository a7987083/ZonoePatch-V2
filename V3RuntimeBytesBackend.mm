#import "V3RuntimeBytesBackend.h"
#import "V3AddressResolver.h"
#import <mach/mach.h>
#import <mach/mach_vm.h>
#import <mach/vm_region.h>
#import <libkern/OSCacheControl.h>
#import <sys/mman.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>
#include <stdint.h>

static NSError *ZNBytesError(NSInteger code,NSString *reason){
 return [NSError errorWithDomain:@"ZonoePatch.V3.BytesBackend" code:code userInfo:@{NSLocalizedDescriptionKey:reason}];
}
static BOOL ZNCheckRX(uintptr_t start,NSUInteger length,NSError **error){
 // All covered pages must be readable/executable and must not already be writable.
 mach_vm_address_t position=(mach_vm_address_t)start,limit=(mach_vm_address_t)start+length;
 while(position<limit){
  mach_vm_address_t region=position;mach_vm_size_t regionSize=0;
  vm_region_basic_info_data_64_t info={};
  mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;
  mach_port_t object=MACH_PORT_NULL;
  kern_return_t kr=mach_vm_region(mach_task_self(),&region,&regionSize,
                      VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&object);
  if(object!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),object);
  if(kr!=KERN_SUCCESS||region>position||!regionSize||regionSize>UINT64_MAX-region||
     (info.protection&(VM_PROT_READ|VM_PROT_EXECUTE))!=(VM_PROT_READ|VM_PROT_EXECUTE)||
     (info.protection&VM_PROT_WRITE)){
   if(error)*error=ZNBytesError(2,@"Target must be mapped RX code pages; refused");
   return NO;
  }
  mach_vm_address_t end=region+regionSize;
  position=end<limit?end:limit;
 }
 return YES;
}
@implementation ZNV3RuntimeBytesBackend
- (BOOL)validateOperation:(ZNV3PatchOperation *)operation error:(NSError **)error {
 if(!operation.moduleUUID.length||!operation.patchBytes.length||!operation.address){
  if(error)*error=ZNBytesError(7,@"Missing executable target identity");return NO;
 }
 NSUInteger n=operation.patchBytes.length;
 if(n>UINTPTR_MAX-operation.address){
  if(error)*error=ZNBytesError(7,@"Patch range overflow");return NO;
 }
 NSString *firstText=[NSString stringWithFormat:@"runtime:0x%llX",(unsigned long long)operation.address];
 NSString *lastText=[NSString stringWithFormat:@"runtime:0x%llX",(unsigned long long)(operation.address+n-1)];
 for(NSString *module in @[@"主程序",@"UnityFramework"]){
  ZNV3ResolvedAddress *first=[ZNV3AddressResolver resolve:firstText module:module error:nil];
  if(!first)continue;
  ZNV3ResolvedAddress *last=[ZNV3AddressResolver resolve:lastText module:module error:nil];
  BOOL same=last&&first.fileBacked&&last.fileBacked&&
    first.segmentVMAddress==last.segmentVMAddress&&
    first.segmentFileOffset==last.segmentFileOffset&&
    last.fileOffset==first.fileOffset+n-1&&
    [first.imageUUID isEqualToString:operation.moduleUUID]&&
    [last.imageUUID isEqualToString:operation.moduleUUID]&&
    (first.segmentInitialProtection & 5u)==5u;
  if(same)return YES;
  if(error)*error=ZNBytesError(7,[NSString stringWithFormat:@"%@ identity/segment/UUID mismatch",module]);
  return NO;
 }
 if(error)*error=ZNBytesError(7,@"Runtime address is not inside allowed loaded Mach-O code segment");
 return NO;
}
- (NSData *)readAt:(uintptr_t)address length:(NSUInteger)length error:(NSError **)error{
 if(!address||!length||length>256||length-1>UINTPTR_MAX-address){
  if(error)*error=ZNBytesError(1,@"Invalid read range");return nil;
 }
 NSMutableData *data=[NSMutableData dataWithLength:length];
 vm_size_t copied=0;
 kern_return_t kr=vm_read_overwrite(mach_task_self(),(vm_address_t)address,
       (vm_size_t)length,(vm_address_t)data.mutableBytes,&copied);
 if(kr!=KERN_SUCCESS||copied!=length){
  if(error)*error=ZNBytesError(3,[NSString stringWithFormat:@"vm_read_overwrite failed kr=%d",kr]);
  return nil;
 }
 return data;
}
- (BOOL)writeAt:(uintptr_t)address bytes:(NSData *)bytes error:(NSError **)error{
 @synchronized(self){
  NSUInteger n=bytes.length;
  if(!address||!n||n>256||n-1>UINTPTR_MAX-address){
   if(error)*error=ZNBytesError(1,@"Invalid write range");return NO;
  }
  long ps=sysconf(_SC_PAGESIZE);
  if(ps<=0||((unsigned long)ps&((unsigned long)ps-1))!=0){
   if(error)*error=ZNBytesError(4,@"Unsupported page size");return NO;
  }
  uintptr_t mask=(uintptr_t)ps-1,begin=address&~mask;
  if(n>UINTPTR_MAX-address-mask){
   if(error)*error=ZNBytesError(1,@"Page range overflow");return NO;
  }
  uintptr_t end=(address+n+mask)&~mask;
  if(!ZNCheckRX(begin,end-begin,error))return NO;
  if(mprotect((void *)begin,end-begin,PROT_READ|PROT_WRITE)!=0){
   if(error)*error=ZNBytesError(5,[NSString stringWithFormat:@"UNSUPPORTED RX->RW errno=%d (%s)",errno,strerror(errno)]);
   return NO;
  }
  memcpy((void *)address,bytes.bytes,n);
  // Never report success if restoring executable permission failed.
  int rc=mprotect((void *)begin,end-begin,PROT_READ|PROT_EXEC);
  int savedErrno=errno;
  sys_icache_invalidate((void *)address,n);
  if(rc!=0){
   if(error)*error=ZNBytesError(6,[NSString stringWithFormat:@"CRITICAL: failed to restore RX errno=%d (%s)",savedErrno,strerror(savedErrno)]);
   return NO;
  }
  return YES;
 }
}
@end
