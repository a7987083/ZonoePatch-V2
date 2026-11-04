#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach/machine.h>
#import <mach/vm_prot.h>
#import "../V3StaticBuildPlanner.h"
#import "../V3StaticBinaryBuilder.h"
#import "../ZNAdhocMachOSigner.h"
#import "../ZNTypedMachOBuilder.h"
#include "../ZNTypedDescriptor.hpp"
#import "../ZNStaticPatchFormat.h"
#import "../V3StaticRuleIdentity.h"
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
static BOOL bindingMatches(NSString *path,NSString *expected,NSString *name) {
 NSData *file=[NSData dataWithContentsOfFile:path];
 if(file.length<sizeof(struct mach_header_64))return NO;
 const uint8_t *p=(const uint8_t *)file.bytes;struct mach_header_64 mh={};
 memcpy(&mh,p,sizeof(mh));
 NSUInteger commandOffset=sizeof(mh);uint64_t dataFile=UINT64_MAX;
 for(uint32_t i=0;i<mh.ncmds;i++){
  if(commandOffset>file.length||file.length-commandOffset<sizeof(struct load_command))return NO;
  struct load_command lc={};memcpy(&lc,p+commandOffset,sizeof(lc));
  if(lc.cmdsize<sizeof(lc)||lc.cmdsize>file.length-commandOffset)return NO;
  if(lc.cmd==LC_SEGMENT_64&&lc.cmdsize>=sizeof(struct segment_command_64)){
   struct segment_command_64 seg={};memcpy(&seg,p+commandOffset,sizeof(seg));
   if(!strncmp(seg.segname,"__ZNDATA",16))dataFile=seg.fileoff;
  }
  commandOffset+=lc.cmdsize;
 }
 if(dataFile==UINT64_MAX||dataFile>file.length||file.length-dataFile<sizeof(ZN44StaticHeader))return NO;
 ZN44StaticHeader header={};memcpy(&header,p+dataFile,sizeof(header));
 if(header.count!=1||header.entrySize!=sizeof(ZN44StaticEntry))return NO;
 ZN44StaticEntry entry={};
 if(file.length-dataFile<sizeof(header)+sizeof(entry))return NO;
 memcpy(&entry,p+dataFile+sizeof(header),sizeof(entry));
 size_t titleLength=strnlen(entry.title,sizeof(entry.title));
 NSString *title=[[NSString alloc]initWithBytes:entry.title length:titleLength encoding:NSUTF8StringEncoding];
 if(!title.length||![name hasPrefix:title]||titleLength>sizeof(entry.title)-1)return NO;
 if(entry.selectedTarget!=0||entry.offRVA==0||entry.onRVA==0||
    entry.canonicalIndex!=0||!(entry.flags&ZN44_STATIC_ENTRY_FLAG_CANONICAL))
  return NO;
 uint64_t descOff=(sizeof(header)+(uint64_t)header.count*sizeof(ZN44StaticEntry)+7)&~UINT64_C(7);
 uint64_t offset=dataFile+descOff;
 if(offset>file.length||file.length-offset<sizeof(ZN44FeatureDescriptionHeader)+sizeof(ZN44FeatureDescriptionEntry))return NO;
 ZN44FeatureDescriptionHeader desc={};memcpy(&desc,p+offset,sizeof(desc));
 if(desc.count!=1||desc.entrySize!=sizeof(ZN44FeatureDescriptionEntry))return NO;
 ZN44FeatureDescriptionEntry value={};memcpy(&value,p+offset+sizeof(desc),sizeof(value));
 if(value.length>ZN44_FEATURE_DESC_MAX_UTF8)return NO;
 NSString *text=[[NSString alloc]initWithBytes:value.text length:value.length encoding:NSUTF8StringEncoding];
 return [text isEqualToString:expected];
}
static NSUInteger staticEntryCount(NSString *path) {
 NSData *data=[NSData dataWithContentsOfFile:path];
 if(data.length<sizeof(struct mach_header_64))return 0;
 const uint8_t *bytes=(const uint8_t *)data.bytes;
 struct mach_header_64 header={};memcpy(&header,bytes,sizeof(header));
 NSUInteger off=sizeof(header);
 for(uint32_t i=0;i<header.ncmds;i++) {
  if(off>data.length||data.length-off<sizeof(struct load_command))return 0;
  struct load_command lc={};memcpy(&lc,bytes+off,sizeof(lc));
  if(lc.cmdsize<sizeof(lc)||lc.cmdsize>data.length-off)return 0;
  if(lc.cmd==LC_SEGMENT_64&&lc.cmdsize>=sizeof(struct segment_command_64)){
   struct segment_command_64 segment={};memcpy(&segment,bytes+off,sizeof(segment));
   if(!strncmp(segment.segname,"__ZNDATA",16)){
    if(segment.fileoff>data.length||data.length-segment.fileoff<sizeof(ZN44StaticHeader))return 0;
    ZN44StaticHeader table={};memcpy(&table,bytes+segment.fileoff,sizeof(table));
    if(table.magic0!=ZN44_STATIC_MAGIC0||table.magic1!=ZN44_STATIC_MAGIC1||
       table.entrySize!=sizeof(ZN44StaticEntry)||table.count>128)return 0;
    return table.count;
   }
  }
  off+=lc.cmdsize;
 }
 return 0;
}
static BOOL p9Grouping(NSString *path) {
 NSData *data=[NSData dataWithContentsOfFile:path];
 if(data.length<sizeof(struct mach_header_64))return NO;
 const uint8_t *bytes=(const uint8_t *)data.bytes;
 struct mach_header_64 mh={};memcpy(&mh,bytes,sizeof(mh));
 NSUInteger off=sizeof(mh);
 for(uint32_t i=0;i<mh.ncmds;i++){
  if(off>data.length||data.length-off<sizeof(struct load_command))return NO;
  struct load_command lc={};memcpy(&lc,bytes+off,sizeof(lc));
  if(lc.cmdsize<sizeof(lc)||lc.cmdsize>data.length-off)return NO;
  if(lc.cmd==LC_SEGMENT_64 && lc.cmdsize>=sizeof(struct segment_command_64)){
   struct segment_command_64 seg={};memcpy(&seg,bytes+off,sizeof(seg));
   if(!strncmp(seg.segname,"__ZNDATA",16)){
    if(seg.fileoff>data.length||data.length-seg.fileoff<sizeof(ZN44StaticHeader)+2*sizeof(ZN44StaticEntry))return NO;
    ZN44StaticHeader table={};memcpy(&table,bytes+seg.fileoff,sizeof(table));
    if(table.count!=2||!(table.flags&ZN44_STATIC_HEADER_FLAG_MULTI_FEATURE_V1))return NO;
    ZN44StaticEntry rows[2]={};memcpy(rows,bytes+seg.fileoff+sizeof(table),sizeof(rows));
    return !strncmp(rows[0].title,"Feature A",9)&&!strncmp(rows[1].title,"Feature B",9)&&
     !strncmp(rows[0].group,"owner-a",7)&&!strncmp(rows[1].group,"owner-b",7)&&
     rows[0].selectedTarget==0&&rows[1].selectedTarget==0;
   }
  }
  off+=lc.cmdsize;
 }
 return NO;
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
  NSString *featureName=@"中文用户功能菜单名称超过四十八个字节仍能正常显示";
   ZNV3StaticBuildPlan *plan=[[ZNV3StaticBuildPlan alloc]initWithModule:@"UnityFramework" name:featureName entries:@[entry]];
  NSString *out=nil,*err=nil;NSDictionary *meta=nil;
  BOOL built=[ZNV3StaticBinaryBuilder buildPlan:plan inDirectory:root outputPath:&out metadata:&meta error:&err];
  if(!built)fprintf(stderr,"build error: %s\n",err.UTF8String?: "none");
  check(built,"V2 static builder produces Mach-O");
  if(built){
   check(segments(out),"generated Mach-O contains owned executable and data segments");
   NSString *identity=ZNP6RuleBinding(uuid.UUIDString,@"fixture-rule",0x1000,
      [NSData dataWithBytes:&patched length:4]);
   check(bindingMatches(out,identity,featureName),"generated descriptor binds UUID, rule ID, RVA and Patch bytes");
   check(!bindingMatches(out,ZNP6RuleBinding(uuid.UUIDString,@"fixture-rule",0x1000,
      [NSData dataWithBytes:&NOP length:4]),featureName),"changed Patch cannot reuse old static descriptor");
   NSDictionary *signature=nil;
   BOOL signedOutput=ZNAdhocResignMachOAtPath(out,&signature,&err);
   if(!signedOutput)fprintf(stderr,"sign error: %s\n",err.UTF8String?:"none");
   check(signedOutput,"generated CodeDirectory rebuilt and verified");
   check([signature[@"verified"] boolValue],"CodeDirectory page hashes read back");
  }
  // P8: one feature with two independent rules must produce two static dispatch entries.
  ZNV3StaticBuildEntry *second=[[ZNV3StaticBuildEntry alloc]initWithRuleID:@"fixture-second"
    uuid:uuid.UUIDString path:src rva:0x1020 fileOffset:0x1020
    original:[NSData dataWithBytes:&NOP length:4] patch:[NSData dataWithBytes:&patched length:4]];
  NSString *multiDir=[root stringByAppendingPathComponent:@"multi"];
  [fm createDirectoryAtPath:multiDir withIntermediateDirectories:YES attributes:nil error:nil];
  ZNV3StaticBuildPlan *multiPlan=[[ZNV3StaticBuildPlan alloc]initWithModule:@"UnityFramework"
    name:@"多组静态生成回归" entries:@[entry,second]];
  NSString *multiOut=nil;NSDictionary *multiMetadata=nil;
  BOOL multiBuilt=[ZNV3StaticBinaryBuilder buildPlan:multiPlan inDirectory:multiDir
    outputPath:&multiOut metadata:&multiMetadata error:&err];
  if(!multiBuilt)fprintf(stderr,"multi build error: %s\\n",err.UTF8String?:"none");
  check(multiBuilt,"two-rule saved feature generates a Mach-O");
  if(multiBuilt){
   check(staticEntryCount(multiOut)==2,"both independent dispatch entries retained");
   NSDictionary *signature=nil;
   check(ZNAdhocResignMachOAtPath(multiOut,&signature,&err),"two-rule Mach-O signing");
   check([signature[@"verified"] boolValue],"two-rule signature verifies");
  }
  // P9: two separately owned features share one signed Mach-O, not one UI switch.
  ZNV3StaticBuildEntry *ownerA=[[ZNV3StaticBuildEntry alloc]
    initWithRuleID:@"p9-a" featureKey:@"owner-a" featureName:@"Feature A"
    uuid:uuid.UUIDString path:src rva:0x1000 fileOffset:0x1000
    original:[NSData dataWithBytes:&NOP length:4] patch:[NSData dataWithBytes:&patched length:4]];
  ZNV3StaticBuildEntry *ownerB=[[ZNV3StaticBuildEntry alloc]
    initWithRuleID:@"p9-b" featureKey:@"owner-b" featureName:@"Feature B"
    uuid:uuid.UUIDString path:src rva:0x1020 fileOffset:0x1020
    original:[NSData dataWithBytes:&NOP length:4] patch:[NSData dataWithBytes:&patched length:4]];
  NSString *p9dir=[root stringByAppendingPathComponent:@"p9"];
  [fm createDirectoryAtPath:p9dir withIntermediateDirectories:YES attributes:nil error:nil];
  ZNV3StaticBuildPlan *p9plan=[[ZNV3StaticBuildPlan alloc]
    initWithModule:@"UnityFramework" name:@"P9 Multi-Feature"
    featureCount:2 entries:@[ownerA,ownerB]];
  NSString *p9out=nil;
  BOOL p9built=[ZNV3StaticBinaryBuilder buildPlan:p9plan inDirectory:p9dir
    outputPath:&p9out metadata:nil error:&err];
  if(!p9built)fprintf(stderr,"P9 build: %s\n",err.UTF8String?:"none");
  check(p9built,"P9 two independent features produce one Mach-O");
  if(p9built){
   check(p9Grouping(p9out),"P9 on-disk feature ownership and OFF slots");
   NSDictionary *signature=nil;
   check(ZNAdhocResignMachOAtPath(p9out,&signature,&err),"P9 Mach-O signing");
   check([signature[@"verified"] boolValue],"P9 signed CodeDirectory verifies");
  }
  // P10.6.2: P9 code/table survives explicit insertion of typed metadata.
  // This is a mixed-image layout test, not mixed Customer runtime execution.
  if(p9built) {
   std::vector<ZNTypedDescriptor::Record> numeric={
    {ZNTypedDescriptor::FeatureKind::Input,ZNValueCodec::Type::Int32,0x2000,false,
      "0","100","",""},
    {ZNTypedDescriptor::FeatureKind::Slider,ZNValueCodec::Type::Float64,0x2010,true,
      "0","100","1","10"}
   };
   std::vector<uint8_t> encoded;std::string diagnostic;
   check(ZNTypedDescriptor::encode(numeric,encoded,diagnostic),"P10.6 mixed typed descriptor encoding");
   NSData *expected=[NSData dataWithBytes:encoded.data() length:encoded.size()];
   NSString *mixedPath=[p9dir stringByAppendingPathComponent:@"mixed-output"];
   NSError *embedError=nil;
   BOOL embedded=[ZNTypedMachOBuilder embedDescriptorIntoPreparedStatic:expected
                                 source:p9out output:mixedPath error:&embedError];
   if(!embedded)fprintf(stderr,"P10.6 embedding: %s\\n",embedError.localizedDescription.UTF8String?: "unknown");
   check(embedded,"P10.6 attach typed segment to P9 static image");
   if(embedded) {
    check(segments(mixedPath),"P10.6 P9 segments preserved");
    check(p9Grouping(mixedPath),"P10.6 P9 names, owners and OFF state preserved");
    check(staticEntryCount(mixedPath)==2,"P10.6 original P9 static rules retained");
    check([[ZNTypedMachOBuilder extractDescriptor:mixedPath error:&embedError]
            isEqualToData:expected],"P10.6 all typed numeric records read back");
    NSDictionary *mixedSign=nil;NSString *mixedSignError=nil;
    check(ZNAdhocResignMachOAtPath(mixedPath,&mixedSign,&mixedSignError),
      "P10.6 mixed Mach-O re-sign");
    check([mixedSign[@"verified"] boolValue],"P10.6 mixed CodeDirectory verified");
    check([[ZNTypedMachOBuilder extractDescriptor:mixedPath error:&embedError]
           isEqualToData:expected],"P10.6 mixed descriptor survives signing");
    check(p9Grouping(mixedPath),"P10.6 P9 table survives signing");
    check(![ZNTypedMachOBuilder embedDescriptorIntoPreparedStatic:expected source:src
               output:[p9dir stringByAppendingPathComponent:@"no-static"]
               error:&embedError],"P10.6 explicit mixed API rejects unprepared input");
    NSMutableData *damaged=[[NSData dataWithContentsOfFile:p9out] mutableCopy];
    if(damaged.length>=sizeof(struct mach_header_64)) {
     uint8_t *raw=(uint8_t *)damaged.mutableBytes;
     struct mach_header_64 mh={};memcpy(&mh,raw,sizeof(mh));
     size_t off=sizeof(mh);BOOL corrupted=NO;
     for(uint32_t ci=0;ci<mh.ncmds;++ci) {
      if(off>damaged.length||damaged.length-off<sizeof(struct load_command))break;
      struct load_command lc={};memcpy(&lc,raw+off,sizeof(lc));
      if(lc.cmdsize<sizeof(lc)||lc.cmdsize>damaged.length-off)break;
      if(lc.cmd==LC_SEGMENT_64&&lc.cmdsize>=sizeof(struct segment_command_64)) {
       struct segment_command_64 seg={};memcpy(&seg,raw+off,sizeof(seg));
       if(!strncmp(seg.segname,"__ZNDATA",16)&&seg.fileoff<=damaged.length-8) {
        raw[seg.fileoff]^=0xff;corrupted=YES;break;
       }
      }
      off+=lc.cmdsize;
     }
     check(corrupted,"P10.6 malformed fixture prepared");
     if(corrupted) {
      NSString *damagedPath=[p9dir stringByAppendingPathComponent:@"corrupt-static"];
      check([damaged writeToFile:damagedPath atomically:YES],"P10.6 corrupted fixture written");
      check(![ZNTypedMachOBuilder embedDescriptorIntoPreparedStatic:expected source:damagedPath
                    output:[p9dir stringByAppendingPathComponent:@"corrupt-mixed"]
                    error:&embedError],"P10.6 rejects invalid P9 header before embed");
     }
    }
    check(![ZNTypedMachOBuilder embedDescriptor:expected source:p9out
               output:[p9dir stringByAppendingPathComponent:@"unsafe-stacking"]
               error:&embedError],"P10.6 old typed API still rejects P9 static image");
    check(![ZNTypedMachOBuilder embedDescriptorIntoPreparedStatic:expected source:mixedPath
               output:[p9dir stringByAppendingPathComponent:@"duplicate-stacking"]
               error:&embedError],"P10.6 repeat typed segment rejected");
   }
  }
  check(![ZNV3StaticBuildPlan validateEntries:@[ownerA,ownerA] error:nil],
    "P9 duplicate rule rejected");
  ZNV3StaticBuildEntry *overlap=[[ZNV3StaticBuildEntry alloc]
    initWithRuleID:@"p9-overlap" featureKey:@"owner-b" featureName:@"Feature B"
    uuid:uuid.UUIDString path:src rva:0x1000 fileOffset:0x1000
    original:[NSData dataWithBytes:&NOP length:4] patch:[NSData dataWithBytes:&patched length:4]];
  check(![ZNV3StaticBuildPlan validateEntries:@[ownerA,overlap] error:nil],
    "P9 overlapping ownership rejected before write");
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
