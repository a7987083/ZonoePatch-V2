#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach/machine.h>
#import <mach/vm_prot.h>
#import "../ZNTypedMachOBuilder.h"
#import "../ZNAdhocMachOSigner.h"
#include "../ZNTypedDescriptor.hpp"
#include <cstring>
static int failed=0;
static void check(BOOL value,const char *label){if(!value){failed++;fprintf(stderr,"FAIL: %s\n",label);}}
static NSData *fixture(void){
 NSMutableData *data=[NSMutableData dataWithLength:0x8000];
 uint8_t *p=(uint8_t *)data.mutableBytes;
 struct mach_header_64 h={};h.magic=MH_MAGIC_64;h.cputype=CPU_TYPE_ARM64;
 h.cpusubtype=CPU_SUBTYPE_ARM64_ALL;h.filetype=MH_DYLIB;h.ncmds=4;
 h.sizeofcmds=sizeof(struct segment_command_64)*2+sizeof(struct section_64)+
              sizeof(struct uuid_command)+sizeof(struct linkedit_data_command);
 memcpy(p,&h,sizeof(h));size_t o=sizeof(h);
 struct segment_command_64 text={};text.cmd=LC_SEGMENT_64;
 text.cmdsize=sizeof(text)+sizeof(struct section_64);
 strncpy(text.segname,"__TEXT",16);text.vmaddr=0x100000000;
 text.vmsize=0x4000;text.fileoff=0;text.filesize=0x4000;
 text.initprot=VM_PROT_READ|VM_PROT_EXECUTE;text.maxprot=text.initprot;text.nsects=1;
 memcpy(p+o,&text,sizeof(text));o+=sizeof(text);
 struct section_64 sec={};
 strncpy(sec.segname,"__TEXT",16);strncpy(sec.sectname,"__text",16);
 sec.addr=text.vmaddr+0x1000;sec.size=0x1000;sec.offset=0x1000;
 sec.flags=S_REGULAR|S_ATTR_PURE_INSTRUCTIONS|S_ATTR_SOME_INSTRUCTIONS;
 memcpy(p+o,&sec,sizeof(sec));o+=sizeof(sec);
 struct segment_command_64 link={};link.cmd=LC_SEGMENT_64;
 link.cmdsize=sizeof(link);strncpy(link.segname,"__LINKEDIT",16);
 link.vmaddr=0x100004000;link.vmsize=0x4000;link.fileoff=0x4000;link.filesize=0x4000;
 link.initprot=VM_PROT_READ;link.maxprot=VM_PROT_READ;
 memcpy(p+o,&link,sizeof(link));o+=sizeof(link);
 struct uuid_command uuid={};uuid.cmd=LC_UUID;uuid.cmdsize=sizeof(uuid);
 for(int i=0;i<16;++i)uuid.uuid[i]=(uint8_t)(i+1);
 memcpy(p+o,&uuid,sizeof(uuid));o+=sizeof(uuid);
 struct linkedit_data_command sig={};sig.cmd=LC_CODE_SIGNATURE;
 sig.cmdsize=sizeof(sig);sig.dataoff=0x7000;sig.datasize=0x1000;
 memcpy(p+o,&sig,sizeof(sig));
 for(int i=0x1000;i<0x2000;i+=4){uint32_t nop=0xD503201F;memcpy(p+i,&nop,4);}
 return data;
}
static BOOL readSegment(NSString *path,NSString *name,struct segment_command_64 *out){
 NSData *data=[NSData dataWithContentsOfFile:path];
 if(data.length<sizeof(struct mach_header_64))return NO;
 const uint8_t *p=(const uint8_t *)data.bytes;struct mach_header_64 h={};
 memcpy(&h,p,sizeof(h));size_t o=sizeof(h);
 for(uint32_t i=0;i<h.ncmds;++i){
  if(o>data.length||data.length-o<sizeof(struct load_command))return NO;
  struct load_command lc={};memcpy(&lc,p+o,sizeof(lc));
  if(lc.cmdsize<sizeof(lc)||lc.cmdsize>data.length-o)return NO;
  if(lc.cmd==LC_SEGMENT_64&&lc.cmdsize>=sizeof(struct segment_command_64)){
   struct segment_command_64 seg={};memcpy(&seg,p+o,sizeof(seg));
   if([name isEqualToString:[NSString stringWithUTF8String:seg.segname]]){
    *out=seg;return YES;
   }
  } o+=lc.cmdsize;
 }
 return NO;
}
int main(){
 @autoreleasepool {
  NSString *dir=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  NSString *input=[dir stringByAppendingPathComponent:@"sample.dylib"];
  NSString *output=[dir stringByAppendingPathComponent:@"typed.dylib"];
  check([fixture() writeToFile:input atomically:YES],"source fixture");
  std::vector<ZNTypedDescriptor::Record> records={
   {ZNTypedDescriptor::FeatureKind::Input,ZNValueCodec::Type::UInt64,0x1020,false,
    "0","18446744073709551615","",""},
   {ZNTypedDescriptor::FeatureKind::Slider,ZNValueCodec::Type::Float32,0x2000,true,
    "0","10","0.25","2.5"}
  };
  std::vector<uint8_t> raw;std::string diagnostic;
  check(ZNTypedDescriptor::encode(records,raw,diagnostic),"encode typed metadata");
  NSData *descriptor=[NSData dataWithBytes:raw.data() length:raw.size()];
  NSError *e=nil;
  check([ZNTypedMachOBuilder embedDescriptor:descriptor source:input output:output error:&e],
        "embed metadata into signed-image-compatible segment");
  if(e)fprintf(stderr,"Builder diagnostic: %s\n",e.localizedDescription.UTF8String);
  NSData *extracted=[ZNTypedMachOBuilder extractDescriptor:output error:&e];
  check([extracted isEqualToData:descriptor],"exact descriptor bytes extracted");
  struct segment_command_64 typed={},link={};
  check(readSegment(output,@"__ZNTYPE",&typed),"owned metadata segment exists");
  check(readSegment(output,@"__LINKEDIT",&link),"LINKEDIT still exists");
  check(typed.initprot==VM_PROT_READ&&typed.maxprot==VM_PROT_READ&&
        typed.nsects==1&&typed.filesize==0x4000,"metadata is non-executable and read-only");
  check(link.fileoff==0x8000&&link.vmaddr==0x100008000,"LINKEDIT relocated after metadata");
  check(![[NSFileManager defaultManager] fileExistsAtPath:[dir stringByAppendingPathComponent:@"same.dylib"]],
        "no unexpected output");
  NSString *signError=nil;NSDictionary *signature=nil;
  check(ZNAdhocResignMachOAtPath(output,&signature,&signError),"resign typed Mach-O");
  if(signError)fprintf(stderr,"Signer diagnostic: %s\n",signError.UTF8String);
  check([[ZNTypedMachOBuilder extractDescriptor:output error:&e] isEqualToData:descriptor],
        "metadata survives rebuilt CodeDirectory");
  check(![ZNTypedMachOBuilder embedDescriptor:descriptor source:output
                                     output:[dir stringByAppendingPathComponent:@"again.dylib"] error:&e],
        "reject stacking metadata on previously generated Mach-O");
  NSMutableData *corrupt=[descriptor mutableCopy];
  ((uint8_t *)corrupt.mutableBytes)[0]^=0xFF;
  check(![ZNTypedMachOBuilder embedDescriptor:corrupt source:input
                                      output:[dir stringByAppendingPathComponent:@"bad.dylib"] error:&e],
        "reject invalid descriptor before file modification");
  [[NSFileManager defaultManager] removeItemAtPath:dir error:nil];
 }
 printf("P10.3 Typed Mach-O Embed: %s (%d failures)\n",failed?"FAIL":"PASS",failed);
 return failed?1:0;
}
