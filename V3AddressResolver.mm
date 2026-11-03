#import "V3AddressResolver.h"
#import "V3ModuleResolver.h"
#import <mach/mach.h>
#import <mach-o/loader.h>
#include <vector>
#include <cstring>
#include <cerrno>
#include <cstdlib>
#include <cstdint>
#include <limits>

namespace {
enum Kind { Auto, RVA, Preferred, Runtime, File };
struct Segment {
 uint64_t vm, vs, off, fs;
 uint32_t initprot;
 char name[17];
};
struct Candidate { Kind kind; uint64_t preferred, runtime, file; bool backed; const Segment *seg; };
static bool add(uint64_t a,uint64_t b,uint64_t &out) {
 if(a>UINT64_MAX-b)return false;out=a+b;return true;
}
static bool contains(uint64_t start,uint64_t size,uint64_t value) {
 return size>0 && value>=start && value-start<size;
}
static const char *label(Kind k) {
 switch(k){case RVA:return "RVA";case Preferred:return "Preferred VA";case Runtime:return "Runtime VA";case File:return "File Offset";default:return "Unknown";}
}
static bool parse(NSString *value,Kind &kind,uint64_t &number) {
 NSString *s=[[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
 if(!s.length)return false;
 const char *prefixes[]={"rva:","va:","preferred:","preferredva:","runtime:","runtimeva:","file:","fileoff:","fileoffset:"};
 Kind kinds[]={RVA,Preferred,Preferred,Preferred,Runtime,Runtime,File,File,File};
 kind=RVA; // Unqualified offsets are RVAs by V3 menu contract.
 for(size_t i=0;i<sizeof(kinds)/sizeof(kinds[0]);++i){
  NSString *prefix=[NSString stringWithUTF8String:prefixes[i]];
  if([s hasPrefix:prefix]){kind=kinds[i];s=[s substringFromIndex:prefix.length];break;}
 }
 if([s hasPrefix:@"0x"])s=[s substringFromIndex:2];
 if(!s.length||s.length>16)return false;
 NSCharacterSet *bad=[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
 if([s rangeOfCharacterFromSet:bad].location!=NSNotFound)return false;
 errno=0;char *end=nullptr;unsigned long long n=strtoull(s.UTF8String,&end,16);
 if(errno||end==s.UTF8String||*end)return false;
 number=(uint64_t)n;return true;
}
static bool snapshot(uint64_t base,std::vector<Segment> &segs,uint64_t &textBase,NSString * __strong &uuid) {
 struct mach_header_64 mh={};
 vm_size_t got=0;
 kern_return_t kr=vm_read_overwrite(mach_task_self(),(vm_address_t)base,sizeof(mh),(vm_address_t)&mh,&got);
 if(kr!=KERN_SUCCESS||got!=sizeof(mh)||mh.magic!=MH_MAGIC_64||
    mh.cputype!=CPU_TYPE_ARM64||mh.ncmds>4096||mh.sizeofcmds>1024*1024)return false;
 std::vector<uint8_t> commands(mh.sizeofcmds);
 if(mh.sizeofcmds==0)return false;
 uint64_t addr=0;if(!add(base,sizeof(mh),addr))return false;
 got=0;kr=vm_read_overwrite(mach_task_self(),(vm_address_t)addr,(vm_size_t)commands.size(),
                          (vm_address_t)commands.data(),&got);
 if(kr!=KERN_SUCCESS||got!=commands.size())return false;
 size_t position=0;textBase=UINT64_MAX;
 for(uint32_t i=0;i<mh.ncmds;i++){
  if(commands.size()-position<sizeof(struct load_command))return false;
  struct load_command lc={};memcpy(&lc,commands.data()+position,sizeof(lc));
  if(lc.cmdsize<sizeof(lc)||lc.cmdsize>commands.size()-position)return false;
  if(lc.cmd==LC_SEGMENT_64){
   if(lc.cmdsize<sizeof(struct segment_command_64))return false;
   struct segment_command_64 sc={};memcpy(&sc,commands.data()+position,sizeof(sc));
   uint64_t end=0;
   if(!add(sc.vmaddr,sc.vmsize,end)||!add(sc.fileoff,sc.filesize,end)||sc.filesize>sc.vmsize)return false;
   Segment seg={sc.vmaddr,sc.vmsize,sc.fileoff,sc.filesize,(uint32_t)sc.initprot,{0}};
   memcpy(seg.name,sc.segname,16);segs.push_back(seg);
   if(strncmp(sc.segname,SEG_TEXT,16)==0)textBase=sc.vmaddr;
  } else if(lc.cmd==LC_UUID){
   if(lc.cmdsize<sizeof(struct uuid_command))return false;
   struct uuid_command uc={};memcpy(&uc,commands.data()+position,sizeof(uc));
   uuid=[[NSUUID alloc] initWithUUIDBytes:uc.uuid].UUIDString;
  }
  position+=lc.cmdsize;
 }
 return textBase!=UINT64_MAX && !segs.empty();
}
}
@implementation ZNV3ResolvedAddress
- (instancetype)initWithKind:(NSString *)kind segment:(NSString *)segment path:(NSString *)path
 rva:(uint64_t)rva preferred:(uint64_t)preferred runtime:(uint64_t)runtime
 fileOffset:(uint64_t)fileOffset fileBacked:(BOOL)fileBacked
 segmentVMAddress:(uint64_t)segmentVMAddress segmentFileOffset:(uint64_t)segmentFileOffset
 segmentFileSize:(uint64_t)segmentFileSize protection:(uint32_t)protection uuid:(NSString *)uuid {
 if((self=[super init])){_kind=[kind copy];_segmentName=[segment copy];_imagePath=[path copy];
 _rva=rva;_preferredVA=preferred;_runtimeVA=runtime;_fileOffset=fileOffset;_fileBacked=fileBacked;
 _segmentVMAddress=segmentVMAddress;_segmentFileOffset=segmentFileOffset;
 _segmentFileSize=segmentFileSize;_segmentInitialProtection=protection;_imageUUID=[uuid copy];}return self;
}
@end
@implementation ZNV3AddressResolver
+ (BOOL)validAddressText:(NSString *)text {Kind kind=Auto;uint64_t n=0;return parse(text,kind,n);}
+ (BOOL)validAlignedCodeOffsetText:(NSString *)text {
 Kind kind=Auto;uint64_t n=0;return parse(text,kind,n) && ((n & 3ULL)==0);
}
+ (ZNV3ResolvedAddress *)resolve:(NSString *)text module:(NSString *)module error:(NSError **)error {
 NSString *message=nil;Kind kind=Auto;uint64_t input=0;
 if(!parse(text,kind,input))message=@"Offset 格式无效：使用 0x105A3C 或 105A3C";
 ZNV3ModuleInfo *image=message?nil:[ZNV3ModuleResolver resolveModule:module];
 if(!message&&!image)message=[NSString stringWithFormat:@"模块未加载：%@",module];
 std::vector<Segment> segs;uint64_t base=UINT64_MAX;NSString *uuid=nil;
 if(!message&&!snapshot((uint64_t)image.imageBase,segs,base,uuid))message=@"读取已加载 Mach-O 结构失败";
 std::vector<Candidate> found;
 if(!message){
  for(const Segment &seg:segs){
   if(!seg.vs||seg.vm<base)continue;
   uint64_t rvaStart=seg.vm-base,rtStart=0;
   if(!add((uint64_t)image.imageBase,rvaStart,rtStart))continue;
   // Each source interpretation is a distinct candidate; never silently prioritize an ambiguous mapping.
   Kind all[]={RVA,Preferred,Runtime,File};
   for(Kind k:all){
    if(kind!=Auto&&kind!=k)continue;
    bool valid=false;
    if(k==RVA)valid=contains(rvaStart,seg.vs,input);
    if(k==Preferred)valid=contains(seg.vm,seg.vs,input);
    if(k==Runtime)valid=contains(rtStart,seg.vs,input);
    if(k==File)valid=contains(seg.off,seg.fs,input);
    if(!valid)continue;
    uint64_t d=k==RVA?input-rvaStart:k==Preferred?input-seg.vm:k==Runtime?input-rtStart:input-seg.off;
    uint64_t pref=0,rt=0,fo=0;
    if(!add(seg.vm,d,pref)||!add(rtStart,d,rt))continue;
    bool backed=d<seg.fs;if(backed&&!add(seg.off,d,fo))continue;
    found.push_back({k,pref,rt,fo,backed,&seg});
   }
  }
 }
 if(!message&&found.empty())message=@"地址无法映射到当前 Mach-O Segment";
 if(!message){
  uint64_t addr=found.front().runtime;
  for(const Candidate &c:found)if(c.runtime!=addr){message=@"地址存在歧义：请指定 rva:/va:/runtime:/file:";break;}
 }
 if(message){
  if(error)*error=[NSError errorWithDomain:@"ZonoePatch.V3.Address" code:1
    userInfo:@{NSLocalizedDescriptionKey:message}];
  return nil;
 }
 const Candidate *choice=&found.front();
 for(const Candidate &c:found)if(c.kind==RVA){choice=&c;break;}
 uint64_t rva=choice->preferred-base;
 return [[ZNV3ResolvedAddress alloc] initWithKind:[NSString stringWithUTF8String:label(choice->kind)]
   segment:[NSString stringWithUTF8String:choice->seg->name] path:image.path
   rva:rva preferred:choice->preferred runtime:choice->runtime
   fileOffset:choice->file fileBacked:choice->backed
   segmentVMAddress:choice->seg->vm segmentFileOffset:choice->seg->off
   segmentFileSize:choice->seg->fs protection:choice->seg->initprot uuid:uuid?:@""];
}
@end
