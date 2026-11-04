#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach/machine.h>
#import <mach/vm_prot.h>
#import "../V3StaticBuildPlanner.h"
#import "../V3StaticBinaryBuilder.h"
#import "../ZNAdhocMachOSigner.h"
#import "../ZNTypedMachOBuilder.h"
#include "../ZNTypedDescriptor.hpp"
#include "../ZNMixedDescriptor.hpp"
#include "../ZNArm64CodeSitePlan.hpp"
#include "../ZNArm64ValueCellPostprocess.hpp"
#include "../ZNCodeCellBinding.hpp"
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
  // P10.7.4: staging-only code-type numeric Value Cell inserted into a
  // real synthetic P9 Mach-O. Does NOT expose a production menu/export API.
  NSString *codeInput=[root stringByAppendingPathComponent:@"source-code-numeric"];
  NSMutableData *codeFixture=[fixture(uuid) mutableCopy];
  const uint32_t fmovOne=0x1e2e1000u,movzTen=0x52800140u;
  memcpy((uint8_t*)codeFixture.mutableBytes+0x1100,&fmovOne,4);
  memcpy((uint8_t*)codeFixture.mutableBytes+0x1120,&movzTen,4);
  check([codeFixture writeToFile:codeInput atomically:YES],"numeric code fixture written");
  ZNArm64CodeSitePlan::Candidate candidate{};
  candidate.featureID="code-slider";candidate.ruleID="code-slider-rule";
  candidate.imageUUID=std::string(uuid.UUIDString.UTF8String);
  candidate.sourcePath=std::string(codeInput.UTF8String);
  candidate.rva=0x1100;candidate.fileOffset=0x1100;
  candidate.type=ZNArm64NumericInstruction::ValueType::Float32;
  const uint32_t inspected[]={0x1e2e1000u,0xd503201fu,0xd503201fu,0xd503201fu};
  candidate.words=inspected;candidate.availableWords=4;
  std::vector<ZNArm64CodeSitePlan::CodeRegion> allCode={{
    0x1000,(const uint8_t*)codeFixture.bytes+0x1000,0x1000
  }};
  ZNArm64CodeSitePlan::Prepared codePrepared{};
  std::string planReason;
  BOOL codePreparedOK=ZNArm64CodeSitePlan::prepare(candidate,allCode,codePrepared,planReason);
  if(!codePreparedOK)fprintf(stderr,"numeric plan: %s\n",planReason.c_str());
  check(codePreparedOK,"numeric FMOV code staging prepared");
  candidate.featureID="code-input";candidate.ruleID="code-input-rule";
  candidate.rva=0x1120;candidate.fileOffset=0x1120;
  candidate.type=ZNArm64NumericInstruction::ValueType::Int32;
  const uint32_t inspectedInt[]={0x52800140u,0xd503201fu,0xd503201fu,0xd503201fu};
  candidate.words=inspectedInt;candidate.availableWords=4;
  ZNArm64CodeSitePlan::Prepared inputPrepared{};
  BOOL inputPreparedOK=ZNArm64CodeSitePlan::prepare(candidate,allCode,inputPrepared,planReason);
  if(!inputPreparedOK)fprintf(stderr,"input plan: %s\n",planReason.c_str());
  check(inputPreparedOK,"numeric MOVZ Int32 code staging prepared");
  if(codePreparedOK&&inputPreparedOK) {
   NSString *codeDir=[root stringByAppendingPathComponent:@"code-cell"];
   [fm createDirectoryAtPath:codeDir withIntermediateDirectories:YES attributes:nil error:nil];
   ZNV3StaticBuildEntry *codeToggle=[[ZNV3StaticBuildEntry alloc]
      initWithRuleID:@"code-toggle" featureKey:@"toggle-feature" featureName:@"Toggle"
      uuid:uuid.UUIDString path:codeInput rva:0x1000 fileOffset:0x1000
      original:[NSData dataWithBytes:&NOP length:4]
      patch:[NSData dataWithBytes:&patched length:4]];
   NSData *codeOriginal=[NSData dataWithBytes:codePrepared.originalBytes.data()
                                      length:codePrepared.originalBytes.size()];
   NSData *codeStaging=[NSData dataWithBytes:codePrepared.stagingNopBytes.data()
                                     length:codePrepared.stagingNopBytes.size()];
   ZNV3StaticBuildEntry *codeEntry=[[ZNV3StaticBuildEntry alloc]
      initWithRuleID:@"code-slider-rule" featureKey:@"code-slider" featureName:@"Code Float32"
      uuid:uuid.UUIDString path:codeInput rva:0x1100 fileOffset:0x1100
      original:codeOriginal patch:codeStaging];
   NSData *inputOriginal=[NSData dataWithBytes:inputPrepared.originalBytes.data()
                                      length:inputPrepared.originalBytes.size()];
   NSData *inputStaging=[NSData dataWithBytes:inputPrepared.stagingNopBytes.data()
                                     length:inputPrepared.stagingNopBytes.size()];
   ZNV3StaticBuildEntry *inputEntry=[[ZNV3StaticBuildEntry alloc]
      initWithRuleID:@"code-input-rule" featureKey:@"code-input" featureName:@"Code Int32"
      uuid:uuid.UUIDString path:codeInput rva:0x1120 fileOffset:0x1120
      original:inputOriginal patch:inputStaging];
   ZNV3StaticBuildPlan *codePlan=[[ZNV3StaticBuildPlan alloc]
      initWithModule:@"UnityFramework" name:@"P10.7.4 synthetic mixed"
      featureCount:3 entries:@[codeToggle,codeEntry,inputEntry]];
   check([ZNV3StaticBuildPlan validateEntries:codePlan.entries error:nil],
         "numeric synthetic P9 plan disjoint");
   NSString *codeOutput=nil,*codeBuildError=nil;
   BOOL codeBuilt=[ZNV3StaticBinaryBuilder buildPlan:codePlan inDirectory:codeDir
      outputPath:&codeOutput metadata:nil error:&codeBuildError];
   if(!codeBuilt)fprintf(stderr,"P10.7.4 P9 build: %s\n",codeBuildError.UTF8String?: "none");
   check(codeBuilt,"synthetic toggle+FMOV staging Mach-O built");
   if(codeBuilt) {
    ZNArm64ValueCellPostprocess::Installed installed{};
    std::string stageError;
    bool inserted=ZNArm64ValueCellPostprocess::install(
       std::string(codeOutput.UTF8String),codePrepared,1,0,2,installed,stageError);
    if(!inserted)fprintf(stderr,"P10.7.4 install: %s\n",stageError.c_str());
    check(inserted,"generated Float32 ON fragment converted to LDR and RW Value Cell");
    ZNArm64ValueCellPostprocess::Installed inputInstalled{};
    bool inputInserted=inserted&&ZNArm64ValueCellPostprocess::install(
       std::string(codeOutput.UTF8String),inputPrepared,2,1,2,inputInstalled,stageError);
    if(!inputInserted)fprintf(stderr,"P10.7.4 input install: %s\n",stageError.c_str());
    check(inputInserted,"generated Int32 ON fragment converted to LDR and RW Value Cell");
    check(installed.cellRVA!=inputInstalled.cellRVA,"Float32 and Int32 own separate RW cells");
    if(inserted&&inputInserted) {
     NSData *post=[NSData dataWithContentsOfFile:codeOutput];
     const uint8_t *raw=(const uint8_t*)post.bytes;
     struct mach_header_64 mh={};memcpy(&mh,raw,sizeof(mh));
     size_t p=sizeof(mh);bool sawCell=false,sawLDR=false;
     bool sawInputCell=false,sawInputLDR=false;
     for(uint32_t j=0;j<mh.ncmds;j++){
      struct load_command lc={};memcpy(&lc,raw+p,sizeof(lc));
      if(lc.cmd==LC_SEGMENT_64){
       struct segment_command_64 sg={};memcpy(&sg,raw+p,sizeof(sg));
       const uint64_t start=sg.vmaddr-0x100000000ULL;
       if(!strncmp(sg.segname,"__ZNTEXT",16)&&installed.onInstructionRVA>=start&&
          installed.onInstructionRVA-start+4<=sg.filesize) {
        uint32_t insn=0;memcpy(&insn,raw+sg.fileoff+installed.onInstructionRVA-start,4);
        sawLDR=insn==installed.ldrInstruction&&((insn&0xff00001fu)==0x1c000000u);
       }
       if(!strncmp(sg.segname,"__ZNTEXT",16)&&inputInstalled.onInstructionRVA>=start&&
          inputInstalled.onInstructionRVA-start+4<=sg.filesize){
        uint32_t insn=0;memcpy(&insn,raw+sg.fileoff+inputInstalled.onInstructionRVA-start,4);
        sawInputLDR=insn==inputInstalled.ldrInstruction&&((insn&0xff00001fu)==0x18000000u);
       }
       if(!strncmp(sg.segname,"__ZNDATA",16)&&installed.cellRVA>=start&&
          installed.cellRVA-start+4<=sg.filesize) {
        uint32_t value=0;memcpy(&value,raw+sg.fileoff+installed.cellRVA-start,4);
        sawCell=value==0x3f800000u;
       }
       if(!strncmp(sg.segname,"__ZNDATA",16)&&inputInstalled.cellRVA>=start&&
          inputInstalled.cellRVA-start+4<=sg.filesize){
        uint32_t value=0;memcpy(&value,raw+sg.fileoff+inputInstalled.cellRVA-start,4);
        sawInputCell=value==10u;
       }
      }
      p+=lc.cmdsize;
     }
     check(sawLDR&&sawCell&&sawInputLDR&&sawInputCell,
       "both Float32/Int32 LDR opcodes and original RW cell bytes read back");
     check(!ZNArm64ValueCellPostprocess::install(
       std::string(codeOutput.UTF8String),codePrepared,1,0,2,installed,stageError),
       "repeated Value Cell install is rejected");
     NSDictionary *codeSigned=nil;NSString *codeSignError=nil;
     check(ZNAdhocResignMachOAtPath(codeOutput,&codeSigned,&codeSignError),
       "staging Value Cell Mach-O can be re-signed");
     check([codeSigned[@"verified"] boolValue],
       "signed staging Value Cell CodeDirectory verified");
     // ZNM2 still records only writable numeric targets, which are now owned
     // __ZNDATA cells rather than the original R-X source instruction RVAs.
     ZNMixedDescriptor::Package codeMixed;
     codeMixed.records={
       {ZNTypedDescriptor::FeatureKind::Slider,ZNValueCodec::Type::Float32,
        installed.cellRVA,true,"0","100","1","1"},
       {ZNTypedDescriptor::FeatureKind::Input,ZNValueCodec::Type::Int32,
        inputInstalled.cellRVA,false,"0","1000","",""}
     };
     codeMixed.features={
       {"code-slider","FMOV Slider",0,1,
        ZNTypedDescriptor::FeatureKind::Slider,ZNValueCodec::Type::Float32},
       {"code-input","MOVZ Input",1,1,
        ZNTypedDescriptor::FeatureKind::Input,ZNValueCodec::Type::Int32}
     };
     std::vector<uint8_t> mixedBytes;std::string mixedError;
     check(ZNMixedDescriptor::encode(codeMixed,mixedBytes,mixedError),
       "ZNM2 code-cell dual-feature descriptor encoded");
     // ZCB1 binds the persisted numeric IDs to dedicated P9 Static Entry
     // patchIDs, so Customer never needs to infer associations by UI names.
     ZNCodeCellBinding::Package cellBindings;
     cellBindings.imageUUID=std::string(uuid.UUIDString.UTF8String);
     cellBindings.bindings={
      {"code-slider",2,0x1100,installed.cellRVA,8,1},
      {"code-input",3,0x1120,inputInstalled.cellRVA,4,1}
     };
     std::vector<uint8_t>zcbEncoded;std::string bindingError;
     check(ZNCodeCellBinding::encode(cellBindings,zcbEncoded,bindingError),
       "ZCB1 binds mixed numeric FeatureID to P9 patch ID and RW cell");
     ZNCodeCellBinding::Package bindingDecoded;
     check(ZNCodeCellBinding::decode(zcbEncoded.data(),zcbEncoded.size(),
        bindingDecoded,bindingError),"ZCB1 ownership survives binary format roundtrip");
     NSData *p9Code=[NSData dataWithContentsOfFile:codeOutput];
     std::vector<ZNCodeCellBinding::P9CodeEntry>p9Slots;
     const uint8_t *p9Raw=(const uint8_t*)p9Code.bytes;
     struct mach_header_64 ph={};memcpy(&ph,p9Raw,sizeof(ph));
     size_t cmdPos=sizeof(ph);
     for(uint32_t ci=0;ci<ph.ncmds;++ci){
      struct load_command command={};memcpy(&command,p9Raw+cmdPos,sizeof(command));
      if(command.cmd==LC_SEGMENT_64){
       struct segment_command_64 seg={};memcpy(&seg,p9Raw+cmdPos,sizeof(seg));
       if(!strncmp(seg.segname,"__ZNDATA",16)){
        ZN44StaticHeader sh={};memcpy(&sh,p9Raw+seg.fileoff,sizeof(sh));
        for(uint32_t ri=0;ri<sh.count;ri++){
         ZN44StaticEntry se={};memcpy(&se,p9Raw+seg.fileoff+sizeof(sh)+
           ri*sizeof(se),sizeof(se));
         p9Slots.push_back({se.patchID,se.siteRVA,
           (se.flags&ZN44_STATIC_ENTRY_FLAG_VALUE_CELL_V1)!=0});
        }
       }
      }
      cmdPos+=command.cmdsize;
     }
     std::vector<ZNCodeCellBinding::NumericCell>cellOwners;
     for(size_t ni=0;ni<codeMixed.features.size();ni++){
      const auto &feature=codeMixed.features[ni];
      cellOwners.push_back({feature.id,(uint8_t)feature.type,
                                codeMixed.records[feature.start].rva});
     }
     check(ZNCodeCellBinding::validateOwnership(bindingDecoded,p9Slots,
        cellOwners,bindingError),"ZCB1 actual P9 and ZNM2 ownership matches");
     auto invalidP9=p9Slots;
     if(invalidP9.size()>=2){
      invalidP9[1].valueCell=false;
      check(!ZNCodeCellBinding::validateOwnership(bindingDecoded,invalidP9,
        cellOwners,bindingError),"missing P9 value-cell marker rejected");
     }

     NSData *descriptor=[NSData dataWithBytes:mixedBytes.data() length:mixedBytes.size()];
     NSString *mixedCode=[codeDir stringByAppendingPathComponent:@"code-mixed-output"];
     NSError *embedCodeError=nil;
     BOOL codeEmbedded=[ZNTypedMachOBuilder embedMixedDescriptorIntoPreparedStatic:
         descriptor source:codeOutput output:mixedCode error:&embedCodeError];
     if(!codeEmbedded)fprintf(stderr,"P10.7.4 ZNM2 embed: %s\n",
         embedCodeError.localizedDescription.UTF8String?: "none");
     check(codeEmbedded,"P9+Float32 Slider+Int32 Input ZNM2 Mach-O generated");
     if(codeEmbedded){
      NSData *roundtrip=[ZNTypedMachOBuilder extractDescriptor:mixedCode error:&embedCodeError];
      check([roundtrip isEqualToData:descriptor],"both code-cell IDs/RVAs survive Mach-O embedding");
      NSDictionary *codeMixedSign=nil;NSString *codeMixedErr=nil;
      check(ZNAdhocResignMachOAtPath(mixedCode,&codeMixedSign,&codeMixedErr),
        "P9+dual-code-cell mixed Mach-O re-sign");
      check([codeMixedSign[@"verified"] boolValue],
        "dual-code-cell mixed CodeDirectory verifies");
      check([[ZNTypedMachOBuilder extractDescriptor:mixedCode error:&embedCodeError]
                isEqualToData:descriptor],"dual-code-cell ZNM2 survives signing");
     }
    }
   }
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
   ZNMixedDescriptor::Package owned;
   owned.records=numeric;
   owned.features={
    {"number-uuid","Number Display",0,1,ZNTypedDescriptor::FeatureKind::Input,ZNValueCodec::Type::Int32},
    {"slider-uuid","Slider Display",1,1,ZNTypedDescriptor::FeatureKind::Slider,ZNValueCodec::Type::Float64}
   };
   std::vector<uint8_t> packed;
   check(ZNMixedDescriptor::encode(owned,packed,diagnostic),"ZNM2 embedded identity encode");
   NSData *expected=[NSData dataWithBytes:packed.data() length:packed.size()];
   NSString *mixedPath=[p9dir stringByAppendingPathComponent:@"mixed-output"];
   NSError *embedError=nil;
   BOOL embedded=[ZNTypedMachOBuilder embedMixedDescriptorIntoPreparedStatic:expected
                                 source:p9out output:mixedPath error:&embedError];
   if(!embedded)fprintf(stderr,"P10.6 embedding: %s\\n",embedError.localizedDescription.UTF8String?: "unknown");
   check(embedded,"P10.6 attach typed segment to P9 static image");
   if(embedded) {
    ZNMixedDescriptor::Package decoded;std::string reason;
    NSData *readback=[ZNTypedMachOBuilder extractDescriptor:mixedPath error:&embedError];
    check(ZNMixedDescriptor::decode((const uint8_t *)readback.bytes,readback.length,decoded,reason),
          "ZNM2 mixed embedded descriptor decoded");
    check(decoded.features.size()==2&&decoded.features[0].id=="number-uuid"&&
          decoded.features[1].name=="Slider Display","ZNM2 distinct feature ID/name preserved");
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
    check(![ZNTypedMachOBuilder embedMixedDescriptorIntoPreparedStatic:expected source:src
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
      check(![ZNTypedMachOBuilder embedMixedDescriptorIntoPreparedStatic:expected source:damagedPath
                    output:[p9dir stringByAppendingPathComponent:@"corrupt-mixed"]
                    error:&embedError],"P10.6 rejects invalid P9 header before embed");
     }
    }
    check(![ZNTypedMachOBuilder embedDescriptor:expected source:p9out
               output:[p9dir stringByAppendingPathComponent:@"unsafe-stacking"]
               error:&embedError],"P10.6 old typed API still rejects P9 static image");
    check(![ZNTypedMachOBuilder embedMixedDescriptorIntoPreparedStatic:expected source:mixedPath
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
