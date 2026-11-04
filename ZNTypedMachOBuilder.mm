#import "ZNTypedMachOBuilder.h"
#include "ZNTypedDescriptor.hpp"
#include "ZNMixedDescriptor.hpp"
#include "ZNMachOFile.h"
#include "ZNStaticPatchFormat.h"
#import <mach-o/loader.h>
#import <mach/machine.h>
#import <mach/vm_prot.h>
#include <cstring>
#include <vector>

static NSError *ZNTError(NSInteger code,NSString *message){
 return [NSError errorWithDomain:@"ZonoePatch.TypedMachO" code:code
  userInfo:@{NSLocalizedDescriptionKey:message?:@"Typed Mach-O failure"}];
}
static constexpr uint64_t kPage=0x4000;
static constexpr char kSegment[]="__ZNTYPE";
static constexpr char kSection[]="__zntype";
static bool ZNTValidateStaticTable(const uint8_t *bytes,size_t length,const struct segment_command_64 &seg) {
 if(seg.fileoff>length||seg.filesize>length-seg.fileoff||seg.filesize<sizeof(ZN44StaticHeader))return false;
 ZN44StaticHeader header={};std::memcpy(&header,bytes+seg.fileoff,sizeof(header));
 return header.magic0==ZN44_STATIC_MAGIC0&&header.magic1==ZN44_STATIC_MAGIC1&&
  header.version==ZN44_STATIC_VERSION_V2&&header.entrySize==sizeof(ZN44StaticEntry)&&
  header.count>=1&&header.count<=128&&
  sizeof(ZN44StaticHeader)+uint64_t(header.count)*sizeof(ZN44StaticEntry)<=seg.filesize;
}
static BOOL ZNTCheckedAdd(uint64_t a,uint64_t b,uint64_t *r){
 if(a>UINT64_MAX-b)return NO;*r=a+b;return YES;
}
@implementation ZNTypedMachOBuilder
+ (BOOL)isValidMixedDescriptor:(NSData *)descriptor {
 ZNMixedDescriptor::Package p;std::string diagnostic;
 return ZNMixedDescriptor::decode((const uint8_t *)descriptor.bytes,descriptor.length,p,diagnostic);
}

+ (BOOL)embedDescriptor:(NSData *)descriptor source:(NSString *)source
                 output:(NSString *)output error:(NSError **)error {
 return [self embedDescriptor:descriptor source:source output:output
       allowPreparedStatic:NO error:error];
}
+ (BOOL)embedDescriptorIntoPreparedStatic:(NSData *)descriptor source:(NSString *)source
                 output:(NSString *)output error:(NSError **)error {
 return [self embedDescriptor:descriptor source:source output:output
       allowPreparedStatic:YES error:error];
}
+ (BOOL)embedMixedDescriptorIntoPreparedStatic:(NSData *)descriptor source:(NSString *)source
                 output:(NSString *)output error:(NSError **)error {
 ZNMixedDescriptor::Package package;std::string diagnostic;
 if(!descriptor.length||
    !ZNMixedDescriptor::decode((const uint8_t *)descriptor.bytes,descriptor.length,package,diagnostic)){
  if(error)*error=ZNTError(17,@"Invalid ZNM2 mixed descriptor");return NO;
 }
 return [self embedDescriptor:descriptor source:source output:output
                allowPreparedStatic:YES mixed:YES error:error];
}
+ (BOOL)embedDescriptor:(NSData *)descriptor source:(NSString *)source
                 output:(NSString *)output allowPreparedStatic:(BOOL)allowStatic
                  error:(NSError **)error {
 return [self embedDescriptor:descriptor source:source output:output
                allowPreparedStatic:allowStatic mixed:NO error:error];
}
+ (BOOL)embedDescriptor:(NSData *)descriptor source:(NSString *)source
                 output:(NSString *)output allowPreparedStatic:(BOOL)allowStatic mixed:(BOOL)mixed
                  error:(NSError **)error {
 std::vector<ZNTypedDescriptor::Record> parsed;std::string diagnostic;
 if(!descriptor.length||(mixed
    ? ![self isValidMixedDescriptor:descriptor]
    : !ZNTypedDescriptor::decode((const uint8_t *)descriptor.bytes,descriptor.length,parsed,diagnostic))){
  if(error)*error=ZNTError(1,@"Typed Descriptor 无效或版本不受支持");return NO;
 }
 if(!source.length||!output.length||[source isEqualToString:output]){
  if(error)*error=ZNTError(2,@"源文件和输出文件必须是不同的有效路径");return NO;
 }
 NSData *src=[NSData dataWithContentsOfFile:source options:NSDataReadingMappedIfSafe error:error];
 if(!src)return NO;
 const uint8_t *bytes=(const uint8_t *)src.bytes;
 znmacho::File file;const char *reason=nullptr;
 if(!znmacho::parse(bytes,src.length,file,&reason)){
  if(error)*error=ZNTError(3,[NSString stringWithUTF8String:reason?: "invalid Mach-O"]);return NO;
 }
 struct mach_header_64 header={};std::memcpy(&header,bytes,sizeof(header));
 uint64_t firstSection=UINT64_MAX,linkCommand=UINT64_MAX,linkFile=0,linkVM=0;
 uint64_t linkVMSize=0,linkFileSize=0;BOOL haveSignature=NO;
 NSUInteger staticTextCount=0,staticDataCount=0;
 for(const znmacho::Command &c:file.commands){
  if(c.kind==LC_CODE_SIGNATURE)haveSignature=YES;
  if(c.kind!=LC_SEGMENT_64)continue;
  struct segment_command_64 seg={};std::memcpy(&seg,bytes+c.offset,sizeof(seg));
  if(!std::strncmp(seg.segname,kSegment,16)){
   if(error)*error=ZNTError(4,@"已存在 __ZNTYPE，不允许重复叠加");return NO;
  }
  if(!std::strncmp(seg.segname,"__ZNTEXT",16)){
   staticTextCount++;
   if(!allowStatic||seg.nsects!=1||seg.initprot!=(VM_PROT_READ|VM_PROT_EXECUTE))
    {if(error)*error=ZNTError(4,@"不允许嵌套 Static Code Segment");return NO;}
  }
  if(!std::strncmp(seg.segname,"__ZNDATA",16)){
   staticDataCount++;
   if(!allowStatic||seg.nsects!=1||seg.initprot!=(VM_PROT_READ|VM_PROT_WRITE)||
      !ZNTValidateStaticTable(bytes,src.length,seg))
    {if(error)*error=ZNTError(4,@"预埋 Static Table 无效");return NO;}
  }
  if(!std::strncmp(seg.segname,"__LINKEDIT",16)){
   if(linkCommand!=UINT64_MAX){if(error)*error=ZNTError(5,@"多个 LINKEDIT 段");return NO;}
   linkCommand=c.offset;linkFile=seg.fileoff;linkVM=seg.vmaddr;
   linkVMSize=seg.vmsize;linkFileSize=seg.filesize;
  }
  const uint32_t count=seg.nsects;
  for(uint32_t i=0;i<count;++i){
   struct section_64 sec={};
   std::memcpy(&sec,bytes+c.offset+sizeof(seg)+i*sizeof(sec),sizeof(sec));
   if(sec.size && sec.offset && (sec.flags & SECTION_TYPE)!=S_ZEROFILL)
    firstSection=std::min(firstSection,(uint64_t)sec.offset);
  }
 }
 if(allowStatic && (staticTextCount!=1||staticDataCount!=1)) {
  if(error)*error=ZNTError(16,@"混合输入必须包含且仅包含一组 P9 Static Dispatch Segments");return NO;
 }
 const uint64_t cmdBytes=sizeof(struct segment_command_64)+sizeof(struct section_64);
 if(!haveSignature||linkCommand==UINT64_MAX||firstSection==UINT64_MAX||
    file.commandEnd>firstSection||cmdBytes>firstSection-file.commandEnd||
    !linkFile||linkFile%kPage||linkVM%kPage||linkVMSize%kPage||
    linkFile>src.length||linkFileSize>src.length-linkFile||
    header.ncmds==UINT32_MAX||header.sizeofcmds>UINT32_MAX-cmdBytes){
  if(error)*error=ZNTError(6,@"Mach-O 不满足 Load Command 空间或 LINKEDIT 对齐/签名条件");return NO;
 }
 for(const znmacho::Command &c:file.commands){
  if(c.kind!=LC_SEGMENT_64||c.offset==linkCommand)continue;
  struct segment_command_64 seg={};std::memcpy(&seg,bytes+c.offset,sizeof(seg));
  if(seg.filesize&&seg.fileoff>=linkFile){
   if(error)*error=ZNTError(7,@"LINKEDIT 不是最后一个文件段");return NO;
  }
  if(seg.vmsize&&seg.vmaddr>=linkVM){
   if(error)*error=ZNTError(8,@"LINKEDIT 不是最后一个 VM 段");return NO;
  }
 }
 uint64_t used=descriptor.length,insert=0,newLength=0;
 if(!znmacho::align(used,kPage,&insert)||insert==0||
    !ZNTCheckedAdd(src.length,insert,&newLength)||
    newLength>NSUIntegerMax||linkFile>UINT32_MAX||
    linkFile+insert>UINT32_MAX||linkVM>UINT64_MAX-insert){
  if(error)*error=ZNTError(9,@"Typed Segment 文件大小或地址溢出");return NO;
 }
 NSMutableData *result=[NSMutableData dataWithLength:(NSUInteger)newLength];
 uint8_t *p=(uint8_t *)result.mutableBytes;
 std::memcpy(p,bytes,src.length);
 std::memmove(p+linkFile+insert,p+linkFile,src.length-linkFile);
 std::memset(p+linkFile,0,(size_t)insert);
 std::memcpy(p+linkFile,descriptor.bytes,descriptor.length);
 // Create a single read-only metadata segment before shifted LINKEDIT.
 struct {
  struct segment_command_64 seg;
  struct section_64 sec;
 } typed={};
 typed.seg.cmd=LC_SEGMENT_64;typed.seg.cmdsize=sizeof(typed);
 std::strncpy(typed.seg.segname,kSegment,sizeof(typed.seg.segname));
 typed.seg.vmaddr=linkVM;typed.seg.vmsize=insert;
 typed.seg.fileoff=linkFile;typed.seg.filesize=insert;
 typed.seg.maxprot=VM_PROT_READ;typed.seg.initprot=VM_PROT_READ;typed.seg.nsects=1;
 std::strncpy(typed.sec.sectname,kSection,sizeof(typed.sec.sectname));
 std::strncpy(typed.sec.segname,kSegment,sizeof(typed.sec.segname));
 typed.sec.addr=linkVM;typed.sec.size=used;typed.sec.offset=(uint32_t)linkFile;
 typed.sec.align=3;typed.sec.flags=S_REGULAR;
 std::memmove(p+linkCommand+sizeof(typed),p+linkCommand,(size_t)(file.commandEnd-linkCommand));
 std::memcpy(p+linkCommand,&typed,sizeof(typed));
 struct mach_header_64 *mh=(struct mach_header_64 *)p;
 mh->ncmds++;mh->sizeofcmds+=(uint32_t)sizeof(typed);
 // Shift all references to LINKEDIT (including code-signature offset). Re-sign afterward.
 if(!znmacho::shiftLinkedit(p,newLength,linkFile,insert,&reason)){
  if(error)*error=ZNTError(10,[NSString stringWithUTF8String:reason?: "LINKEDIT relocation failed"]);return NO;
 }
 znmacho::File verified;
 if(!znmacho::parse(p,newLength,verified,&reason)){
  if(error)*error=ZNTError(11,[NSString stringWithUTF8String:reason?: "Mach-O validation failed"]);return NO;
 }
 if(![result writeToFile:output options:NSDataWritingAtomic error:error])return NO;
 return YES;
}
+ (NSData *)extractDescriptor:(NSString *)path error:(NSError **)error {
 NSData *src=[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:error];
 if(!src)return nil;
 znmacho::File f;const char *reason=nullptr;
 if(!znmacho::parse((const uint8_t *)src.bytes,src.length,f,&reason)){
  if(error)*error=ZNTError(12,[NSString stringWithUTF8String:reason?: "invalid Mach-O"]);return nil;
 }
 znmacho::SectionLocation loc;
 if(!znmacho::findSection(f,kSegment,kSection,loc,&reason)){
  if(error)*error=ZNTError(13,[NSString stringWithUTF8String:reason?: "Typed Descriptor missing"]);return nil;
 }
 uint32_t offset=znmacho::read<uint32_t>(f.bytes,loc.sectionOffset+48);
 uint64_t size=znmacho::read<uint64_t>(f.bytes,loc.sectionOffset+40);
 if(!size||size>65536||!ZNCheckedRange64(f.size,offset,size)){
  if(error)*error=ZNTError(14,@"Typed Descriptor Section 越界");return nil;
 }
 std::vector<ZNTypedDescriptor::Record> records;std::string diagnostic;
 if(!ZNTypedDescriptor::decode(f.bytes+offset,size,records,diagnostic)){
  ZNMixedDescriptor::Package mixed;
  if(!ZNMixedDescriptor::decode(f.bytes+offset,size,mixed,diagnostic)){
   if(error)*error=ZNTError(15,@"Typed Descriptor 内容损坏");return nil;
  }
 }
 return [NSData dataWithBytes:f.bytes+offset length:(NSUInteger)size];
}
@end
