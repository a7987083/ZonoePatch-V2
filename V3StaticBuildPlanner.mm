#import "V3StaticBuildPlanner.h"
#import "V3FeatureModels.h"
#import "V3PatchValidator.h"
#import "V3AddressResolver.h"
#import "V3PatchSession.h"
#import <fcntl.h>
#import <sys/stat.h>
#import <unistd.h>
#include <stdint.h>
static NSError *ZNP6Error(NSInteger code,NSString *message){
 return [NSError errorWithDomain:@"ZonoePatch.V3.StaticBuild" code:code userInfo:@{NSLocalizedDescriptionKey:message}];
}
@implementation ZNV3StaticBuildPlanner
+ (ZNV3StaticBuildPlan *)planForFeature:(ZNV3Feature *)feature error:(NSError **)error {
 if([ZNV3PatchSession shared].status!=ZNV3PatchTransactionStatusDisabled) {
  if(error)*error=ZNP6Error(4,@"Restore active Runtime Patch before static build planning");
  return nil;
 }
 if(!feature||![@[@"主程序",@"UnityFramework"] containsObject:feature.module]){
  if(error)*error=ZNP6Error(5,@"Invalid feature module");return nil;
 }
 NSMutableArray *entries=[NSMutableArray array];
 for(ZNV3PatchRule *rule in feature.rules){
  if(!rule.offsetText.length&&!rule.patchText.length)continue;
  NSError *e=nil;
  ZNV3PatchValidation *v=[ZNV3PatchValidator validateOffset:rule.offsetText patch:rule.patchText module:feature.module error:&e];
  if(!v){if(error)*error=e?:ZNP6Error(6,@"Runtime preflight failed");return nil;}
  ZNV3ResolvedAddress *address=v.address;
  NSUInteger n=v.patchBytes.length;
  if(address.fileOffset>INT64_MAX||n>(uint64_t)(INT64_MAX-address.fileOffset)){
   if(error)*error=ZNP6Error(7,@"File offset exceeds pread range");return nil;
  }
  int fd=open(address.imagePath.fileSystemRepresentation,O_RDONLY|O_CLOEXEC);
  if(fd<0){if(error)*error=ZNP6Error(8,@"Cannot open target Mach-O source");return nil;}
  struct stat st={};NSMutableData *disk=[NSMutableData dataWithLength:n];
  BOOL ok=fstat(fd,&st)==0&&S_ISREG(st.st_mode)&&st.st_size>=0&&
   address.fileOffset<=(uint64_t)st.st_size&&n<=(uint64_t)st.st_size-address.fileOffset&&
   pread(fd,disk.mutableBytes,n,(off_t)address.fileOffset)==(ssize_t)n&&
   [disk isEqualToData:v.originalBytes];
  close(fd);
  if(!ok){if(error)*error=ZNP6Error(9,@"Disk/loaded Original mismatch; no build may proceed");return nil;}
  [entries addObject:[[ZNV3StaticBuildEntry alloc]initWithRuleID:rule.identifier
      uuid:address.imageUUID path:address.imagePath rva:address.rva
      fileOffset:address.fileOffset original:disk patch:v.patchBytes]];
 }
 if(![ZNV3StaticBuildPlan validateEntries:entries error:error])return nil;
 return [[ZNV3StaticBuildPlan alloc]initWithModule:feature.module entries:entries];
}
@end
