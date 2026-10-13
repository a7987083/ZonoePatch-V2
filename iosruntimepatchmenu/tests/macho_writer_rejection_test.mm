#import "ZNStaticRVAProtection.h"
#import <mach-o/loader.h>
#import <mach/machine.h>
#include <cassert>
int main(){@autoreleasepool{
 NSString *folder=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];NSString *path=[folder stringByAppendingPathComponent:@"bad.dylib"];
 for(unsigned scenario=0;scenario<4;scenario++){
  NSMutableData *data=[NSMutableData dataWithLength:256];uint8_t *p=(uint8_t*)data.mutableBytes;mach_header_64 h={};h.magic=MH_MAGIC_64;h.cputype=CPU_TYPE_ARM64;h.ncmds=1;h.sizeofcmds=72;memcpy(p,&h,sizeof(h));segment_command_64 seg={};seg.cmd=LC_SEGMENT_64;seg.cmdsize=72;
  switch(scenario){case 0:((mach_header_64*)p)->sizeofcmds=UINT32_MAX;break;case 1:seg.cmdsize=8;break;case 2:seg.nsects=UINT32_MAX;break;case 3:seg.vmaddr=UINT64_MAX;seg.vmsize=16;break;}
  memcpy(p+sizeof(h),&seg,sizeof(seg));assert([data writeToFile:path atomically:YES]);NSString *error=nil;NSUInteger count=99;
  assert(!ZN55ProtectStaticRVAsAtPath(path,&count,&error));assert(error.length&&count==0);assert([data isEqualToData:[NSData dataWithContentsOfFile:path]]);
 }
 [NSFileManager.defaultManager removeItemAtPath:folder error:nil];NSLog(@"production RVA writer malformed rejection / file unchanged PASS");
}}
