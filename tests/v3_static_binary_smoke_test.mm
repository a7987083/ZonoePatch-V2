#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach/machine.h>
#import <mach/vm_prot.h>
#import "../V3StaticBuildPlanner.h"
#import "../V3StaticBinaryBuilder.h"
#import "../ZNAdhocMachOSigner.h"
#include <stdint.h>
#include <string.h>
static int failures=0;
static void check(BOOL value,const char *message) {
 if(!value){fprintf(stderr,"FAIL %s\n",message);failures++;}
}
static NSData *fixture(NSUUID *uuid) {
 NSMutableData *bytes=[NSMutableData dataWithLength:0x8000];uint8_t *p=(uint8_t *)bytes.mutableBytes;
 struct mach_header_64 h={};h.magic=MH_MAGIC_64;h.cputype=CPU_TYPE_ARM64;
 h.cpusubtype=CPU_SUBTYPE_ARM64_ALL;h.filetype=MH_DYLIB;h.ncmds=4;
 h.sizeofcmds=(uint32_t)(sizeof(struct segment_command_64)+sizeof(struct section_64)+
    sizeof(struct segment_command_64)+sizeof(struct uuid_command)+sizeof(struct linkedit_data_command));
 memcpy(p,&h,sizeof(h));NSUInteger o=sizeof(h);
 struct segment_command_64 text={};text.cmd=LC_SEGMENT_64;
 text.cmdsize=sizeof(text)+sizeof(struct section_64);strncpy(text.segname,"__TEXT",16);
 text.vmaddr=0x100000000; text.vmsize=0x4000;text.fileoff=0;text.filesize=0x4000;
 text.maxprot=VM_PROT_READ|VM_PROT_EXECUTE;text.initprot=text.maxprot;text.nsects=1;
 memcpy(p+o,&text,sizeof(text));o+=sizeof(text);
 struct section_64 sec={};strncpy(sec.segname,"__TEXT",16);strncpy(sec.sectname,"__text",16);
 sec.addr=text.vmaddr+0x1000;sec.size=0x1000;sec.offset=0x1000;
 sec.flags=S_REGULAR|S_ATTR_PURE_INSTRUCTIONS|S_ATTR_SOME_INSTRUCTIONS;
 memcpy(p+o,&sec,sizeof(sec));o+=sizeof(sec);
 struct segment_command_64 link={};link.cmd=LC_SEGMENT_64;link.cmdsize=sizeof(link);
 strncpy(link.segname,"__LINKEDIT",16);link.vmaddr=0x100004000;link.vmsize=0x4000;
 link.fileoff=0x4000;link.filesize=0x4000;link.maxprot=VM_PROT_READ;link.initprot=VM_PROT_READ;
 memcpy(p+o,&link,sizeof(link));o+=sizeof(link);
 struct uuid_command uc={};uc.cmd=LC_UUID;uc.cmdsize=sizeof(uc);[uuid getUUIDBytes:uc.uuid];
 memcpy(p+o,&uc,sizeof(uc));o+=sizeof(uc);
 struct linkedit_data_command sig={};sig.cmd=LC_CODE_SIGNATURE;sig.cmdsize=sizeof(sig);
 sig.dataoff=0x7000;sig.datasize=0x1000;memcpy(p+o,&sig,sizeof(sig));
 const uint32_t NOP=0xD503201F;
 for(NSUInteger i=0x1000;i<0x2000;i+=4)memcpy(p+i,&NOP,4);
 return bytes;
}
static BOOL segments(NSString *path) {
 NSData *d=[NSData dataWithContentsOfFile:path];if(d.length<sizeof(struct mach_header_64))return NO;
 const uint8_t *p=(const uint8_t *)d.bytes;
 struct mach_header_64 h={};memcpy(&h,p,sizeof(h));
 NSUInteger o=sizeof(h);BOOL text=NO,data=NO;
 for(NSUInteger i=0;i<h.ncmds;i++){
  if(o> d.length||d.length-o<sizeof(struct load_command))return NO;
  struct load_command cmd={};memcpy(&cmd,p+o,sizeof(cmd));
  if(cmd.cmdsize<sizeof(cmd)||cmd.cmdsize>d.length-o)return NO;
  if(cmd.cmd==LC_SEGMENT_64 && cmd.cmdsize>=sizeof(struct segment_command_64)){
   struct segment_command_64 seg={};memcpy(&seg,p+o,sizeof(seg));
   if(!strncmp(seg.segname,"__ZNTEXT",16))text=YES;
   if(!strncmp(seg.segname,"__ZNDATA",16))data=YES;
  }
  o+=cmd.cmdsize;
 }
 return text&&data;
}
int main() {
 @autoreleasepool {
  NSUUID *uuid=[NSUUID UUID];
  NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
  NSFileManager *fm=NSFileManager.defaultManager;
  [fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
  NSString *src=[root stringByAppendingPathComponent:@"fixture"];
  check([fixture(uuid) writeToFile:src atomically:YES],"fixture write");
  const uint32_t NOP=0xD503201F,patched=0xD2800020;
  ZNV3StaticBuildEntry *entry=[[ZNV3StaticBuildEntry alloc]initWithRuleID:@"fixture-rule"
    uuid:uuid.UUIDString path:src rva:0x1000 fileOffset:0x1000
    original:[NSData dataWithBytes:&NOP length:4] patch:[NSData dataWithBytes:&patched length:4]];
  ZNV3StaticBuildPlan *plan=[[ZNV3StaticBuildPlan alloc]initWithModule:@"UnityFramework" entries:@[entry]];
  NSString *out=nil,*err=nil;NSDictionary *meta=nil;
  BOOL built=[ZNV3StaticBinaryBuilder buildPlan:plan inDirectory:root outputPath:&out metadata:&meta error:&err];
  if(!built)fprintf(stderr,"build error: %s\n",err.UTF8String?: "none");
  check(built,"V2 static builder produces Mach-O");
  if(built){
   check(segments(out),"generated Mach-O contains owned executable and data segments");
   NSDictionary *signature=nil;
   BOOL signedOutput=ZNAdhocResignMachOAtPath(out,&signature,&err);
   if(!signedOutput)fprintf(stderr,"sign error: %s\n",err.UTF8String?:"none");
   check(signedOutput,"generated CodeDirectory rebuilt and verified");
   check([signature[@"verified"] boolValue],"CodeDirectory page hashes read back");
  }
  ZNV3StaticBuildEntry *wrong=[[ZNV3StaticBuildEntry alloc]initWithRuleID:@"bad"
   uuid:NSUUID.UUID.UUIDString path:src rva:0x1000 fileOffset:0x1000
   original:[NSData dataWithBytes:&NOP length:4] patch:[NSData dataWithBytes:&patched length:4]];
  ZNV3StaticBuildPlan *badPlan=[[ZNV3StaticBuildPlan alloc]initWithModule:@"UnityFramework" entries:@[wrong]];
  check(![ZNV3StaticBinaryBuilder buildPlan:badPlan inDirectory:root outputPath:nil metadata:nil error:&err],
   "mismatched source UUID refuses write");
  ZNV3StaticBuildEntry *wrongOriginal=[[ZNV3StaticBuildEntry alloc]initWithRuleID:@"bad-original"
   uuid:uuid.UUIDString path:src rva:0x1000 fileOffset:0x1000
   original:[NSData dataWithBytes:&patched length:4] patch:[NSData dataWithBytes:&NOP length:4]];
  ZNV3StaticBuildPlan *wrongPlan=[[ZNV3StaticBuildPlan alloc]initWithModule:@"UnityFramework" entries:@[wrongOriginal]];
  check(![ZNV3StaticBinaryBuilder buildPlan:wrongPlan inDirectory:root outputPath:nil metadata:nil error:&err],
   "changed source Original refuses build");
  NSMutableData *encrypted=[fixture(uuid) mutableCopy];
  struct mach_header_64 eh={};memcpy(&eh,encrypted.mutableBytes,sizeof(eh));
  size_t newCommand=sizeof(struct mach_header_64)+eh.sizeofcmds;
  eh.ncmds++;eh.sizeofcmds+=sizeof(struct encryption_info_command_64);
  memcpy(encrypted.mutableBytes,&eh,sizeof(eh));
  struct encryption_info_command_64 crypt={};crypt.cmd=LC_ENCRYPTION_INFO_64;
  crypt.cmdsize=sizeof(crypt);crypt.cryptid=1;
  memcpy((uint8_t *)encrypted.mutableBytes+newCommand,&crypt,sizeof(crypt));
  NSString *encryptedPath=[root stringByAppendingPathComponent:@"encrypted-fixture"];
  check([encrypted writeToFile:encryptedPath atomically:YES],"encrypted fixture write");
  ZNV3StaticBuildEntry *encryptedRow=[[ZNV3StaticBuildEntry alloc]initWithRuleID:@"encrypted"
   uuid:uuid.UUIDString path:encryptedPath rva:0x1000 fileOffset:0x1000
   original:[NSData dataWithBytes:&NOP length:4] patch:[NSData dataWithBytes:&patched length:4]];
  ZNV3StaticBuildPlan *encryptedPlan=[[ZNV3StaticBuildPlan alloc]initWithModule:@"UnityFramework" entries:@[encryptedRow]];
  check(![ZNV3StaticBinaryBuilder buildPlan:encryptedPlan inDirectory:root outputPath:nil metadata:nil error:&err],
   "encrypted Mach-O must fail closed");
  [fm removeItemAtPath:root error:nil];
 }
 printf("P6 generated binary smoke: %s (%d failures)\n",failures?"FAIL":"PASS",failures);
 return failures?1:0;
}
