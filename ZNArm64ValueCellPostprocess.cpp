#include "ZNArm64ValueCellPostprocess.hpp"
#include "ZNArm64ValueCellPlan.hpp"
#include "ZNStaticPatchFormat.h"
#include <mach-o/loader.h>
#include <mach/machine.h>
#include <mach/vm_prot.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstring>
#include <cstdio>
#include <cctype>
#include <set>
#include <vector>
#include <limits>
namespace ZNArm64ValueCellPostprocess {
namespace {
struct Segment {segment_command_64 cmd{};section_64 section{};bool hasSection=false;};
bool inRange(uint64_t off,uint64_t size,uint64_t length){
 return off<=length&&size<=length-off;
}
uint32_t read32(const uint8_t *p){uint32_t x=0;std::memcpy(&x,p,4);return x;}
void write32(uint8_t *p,uint32_t x){std::memcpy(p,&x,4);}
int64_t sext26(uint32_t bits){
 const uint32_t n=bits&0x03ffffffu;
 return int64_t((uint64_t(n)^0x02000000u)-0x02000000u);
}
bool codeFileOffset(const Segment &code,uint64_t imageBase,uint64_t rva,
                    uint64_t bytes,uint64_t fileLength,uint64_t &out){
 if(code.cmd.vmaddr<imageBase)return false;
 const uint64_t start=code.cmd.vmaddr-imageBase;
 if(rva<start||rva-start>code.cmd.filesize||
    bytes>code.cmd.filesize-(rva-start))return false;
 const uint64_t offset=code.cmd.fileoff+(rva-start);
 if(!inRange(offset,bytes,fileLength))return false;
 out=offset;return true;
}
bool scanVariant(const uint8_t *bytes,uint64_t fileLength,const Segment &code,
                 uint64_t imageBase,uint64_t entryRVA,
                 const std::vector<uint8_t> &wanted,std::string &error){
 const size_t count=wanted.size()/4u;
 std::set<uint64_t> seen;
 uint64_t fragment=entryRVA;
 for(size_t i=0;i<count;i++){
  if(!seen.insert(fragment).second){error="fragment chain repeats a slot";return false;}
  uint64_t off=0;
  if(!codeFileOffset(code,imageBase,fragment,(i==0?12u:8u),fileLength,off)){
   error="fragment slot outside __ZNTEXT";return false;
  }
  if(i==0&&read32(bytes+off)!=0xa8c147f0u){
   error="first variant slot does not restore X16/X17";return false;
  }
  const uint32_t current=read32(bytes+off+(i==0?4u:0u));
  const uint32_t expected=read32(wanted.data()+i*4u);
  if(current!=expected){error="ON/OFF fragment does not match verified site bytes";return false;}
  if(i+1==count)break;
  const uint32_t branch=read32(bytes+off+(i==0?8u:4u));
  if((branch&0xfc000000u)!=0x14000000u){
   error="fragment chain does not have an unconditional B";return false;
  }
  const uint64_t branchRVA=fragment+(i==0?8u:4u);
  const __int128 target=(__int128)branchRVA+(__int128)sext26(branch)*4;
  if(target<0||target>UINT64_MAX){error="fragment B target overflow";return false;}
  fragment=(uint64_t)target;
 }
 return true;
}
bool sameUUID(const uint8_t *uuid,const std::string &wanted) {
 char s[37]={};
 std::snprintf(s,sizeof(s),
  "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
  uuid[0],uuid[1],uuid[2],uuid[3],uuid[4],uuid[5],uuid[6],uuid[7],
  uuid[8],uuid[9],uuid[10],uuid[11],uuid[12],uuid[13],uuid[14],uuid[15]);
 if(wanted.size()!=36)return false;
 for(size_t i=0;i<36;i++)
  if(std::toupper((unsigned char)wanted[i])!=s[i])return false;
 return true;
}
}
bool install(const std::string &path,const ZNArm64CodeSitePlan::Prepared &site,
             size_t index,size_t ordinal,size_t total,
             Installed &out,std::string &error) {
 auto fail=[&](const char *reason){error=reason;return false;};
 if(path.empty()||site.originalBytes.empty()||
    site.originalBytes.size()!=size_t(site.instruction.wordCount)*4u||
    site.originalBytes.size()!=site.stagingNopBytes.size()||
    !total||total>128||ordinal>=total)
  return fail("invalid source site or cell reservation");
 int fd=open(path.c_str(),O_RDWR|O_CLOEXEC);
 if(fd<0)return fail("cannot open staged Mach-O for Value Cell install");
 struct stat st{};
 if(fstat(fd,&st)!=0||!S_ISREG(st.st_mode)||st.st_size<sizeof(mach_header_64)){
  close(fd);return fail("bad staged Mach-O length or file type");
 }
 const size_t length=(size_t)st.st_size;
 uint8_t *base=(uint8_t*)mmap(nullptr,length,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
 if(base==MAP_FAILED){close(fd);return fail("mmap of staged Mach-O failed");}
 bool ok=false;std::string failure;
 do {
  mach_header_64 mh{};std::memcpy(&mh,base,sizeof(mh));
  if(mh.magic!=MH_MAGIC_64||mh.cputype!=CPU_TYPE_ARM64||
     !mh.ncmds||mh.ncmds>4096||!inRange(sizeof(mh),mh.sizeofcmds,length)){
   failure="invalid arm64 Mach-O header";break;
  }
  Segment code{},data{};bool haveCode=false,haveData=false,haveUUID=false;
  uint64_t imageBase=UINT64_MAX;
  size_t pos=sizeof(mh),end=pos+mh.sizeofcmds;
  for(unsigned i=0;i<mh.ncmds;i++){
   if(pos>end||end-pos<sizeof(load_command)){failure="truncated load commands";break;}
   load_command lc{};std::memcpy(&lc,base+pos,sizeof(lc));
   if(lc.cmdsize<sizeof(lc)||lc.cmdsize>end-pos){failure="invalid load command size";break;}
   if(lc.cmd==LC_UUID&&lc.cmdsize>=sizeof(uuid_command)){
    uuid_command uuid{};std::memcpy(&uuid,base+pos,sizeof(uuid));
    if(haveUUID||!sameUUID(uuid.uuid,site.imageUUID)){failure="staged LC_UUID differs from code site";break;}
    haveUUID=true;
   }
   if(lc.cmd==LC_SEGMENT_64&&lc.cmdsize>=sizeof(segment_command_64)){
    segment_command_64 seg{};std::memcpy(&seg,base+pos,sizeof(seg));
    if(!inRange(seg.fileoff,seg.filesize,length)){failure="segment file range invalid";break;}
    if(!std::strncmp(seg.segname,"__TEXT",16))imageBase=seg.vmaddr;
    Segment *found=nullptr;
    if(!std::strncmp(seg.segname,"__ZNTEXT",16)){
     if(haveCode){failure="duplicate __ZNTEXT";break;}
     haveCode=true;found=&code;
    }else if(!std::strncmp(seg.segname,"__ZNDATA",16)){
     if(haveData){failure="duplicate __ZNDATA";break;}
     haveData=true;found=&data;
    }
    if(found){
     found->cmd=seg;
     if(seg.nsects!=1||uint64_t(seg.nsects)*sizeof(section_64)>lc.cmdsize-sizeof(seg)){
      failure="owned segment has unexpected section table";break;
     }
     std::memcpy(&found->section,base+pos+sizeof(seg),sizeof(section_64));
     found->hasSection=true;
    }
   }
   pos+=lc.cmdsize;
  }
  if(!failure.empty())break;
  if(!haveCode||!haveData||!haveUUID||imageBase==UINT64_MAX||
     !code.hasSection||!data.hasSection){
   failure="required P9 segments or image identity absent";break;
  }
  if(!(code.cmd.initprot&VM_PROT_EXECUTE)||
     !(data.cmd.initprot&VM_PROT_WRITE)||
     data.cmd.vmaddr<imageBase||
     std::strncmp(data.section.sectname,"__zndata",16)!=0||
     std::strncmp(code.section.sectname,"__zncode",16)!=0){
   failure="owned code/data mapping is not executable/writable as required";break;
  }
  if(index>=128||data.cmd.filesize<sizeof(ZN44StaticHeader)||
     !inRange(data.cmd.fileoff, sizeof(ZN44StaticHeader),length)){
   failure="invalid Static Entry index";break;
  }
  ZN44StaticHeader header{};std::memcpy(&header,base+data.cmd.fileoff,sizeof(header));
  if(header.magic0!=ZN44_STATIC_MAGIC0||header.magic1!=ZN44_STATIC_MAGIC1||
     header.version!=ZN44_STATIC_VERSION_V2||header.entrySize!=sizeof(ZN44StaticEntry)||
     !header.count||header.count>128||index>=header.count||
     uint64_t(sizeof(header))+uint64_t(header.count)*sizeof(ZN44StaticEntry)>data.cmd.filesize){
   failure="P9 static table invalid";break;
  }
  const uint64_t rowOff=data.cmd.fileoff+sizeof(header)+index*sizeof(ZN44StaticEntry);
  ZN44StaticEntry row{};std::memcpy(&row,base+rowOff,sizeof(row));
  if(row.siteRVA!=site.rva||row.enabledLength!=site.originalBytes.size()||
     !row.onRVA||!row.offRVA||row.selectedTarget!=0||
     (row.flags&ZN44_STATIC_ENTRY_FLAG_VALUE_CELL_V1)){
   failure="static entry does not match untouched numeric staging site";break;
  }
  if(!scanVariant(base,length,code,imageBase,row.onRVA,
                  site.stagingNopBytes,failure)||
     !scanVariant(base,length,code,imageBase,row.offRVA,
                  site.originalBytes,failure))break;
  if(total>UINT64_MAX/8u||data.cmd.filesize<uint64_t(total)*8u){
   failure="insufficient reserved data tail";break;
  }
  const uint64_t cellsStart=data.cmd.filesize-uint64_t(total)*8u;
  const uint64_t cellRelative=cellsStart+uint64_t(ordinal)*8u;
  const uint64_t cellFile=data.cmd.fileoff+cellRelative;
  const uint64_t cellRVA=data.cmd.vmaddr-imageBase+cellRelative;
  const uint64_t usedSectionEnd=uint64_t(data.section.offset)+data.section.size;
  if(cellFile<usedSectionEnd||!inRange(cellFile,8u,length)||
     !inRange(cellRelative,8u,data.cmd.filesize)){
   failure="Value Cell collides with __zndata section or file bounds";break;
  }
  for(unsigned i=0;i<8;i++)
   if(base[cellFile+i]!=0){failure="Value Cell slot was already used";break;}
  if(!failure.empty())break;
  if(row.onRVA>UINT64_MAX-4u){failure="ON variant RVA overflow";break;}
  ZNArm64ValueCellPlan::Replacement repl{};
  if(!ZNArm64ValueCellPlan::plan(site.instruction,row.onRVA+4u,
                                cellRVA,repl,failure))break;
  uint64_t onFile=0;
  if(!codeFileOffset(code,imageBase,row.onRVA,8u,length,onFile)){
   failure="ON variant slot could not be mapped";break;
  }
  if(read32(base+onFile+4u)!=0xd503201fu){
   failure="ON slot no longer has the expected NOP placeholder";break;
  }
  // All validation is complete; atomically stage the data and ON opcode.
  std::memcpy(base+cellFile,repl.originalCellBytes.data(),repl.cellWidth);
  write32(base+onFile+4u,repl.instructions[0]);
  row.flags|=ZN44_STATIC_ENTRY_FLAG_VALUE_CELL_V1;
  std::memcpy(base+rowOff,&row,sizeof(row));
  header.flags|=ZN44_STATIC_HEADER_FLAG_VALUE_CELLS_V1;
  std::memcpy(base+data.cmd.fileoff,&header,sizeof(header));
  if(msync(base,length,MS_SYNC)!=0){failure="Value Cell msync failed";break;}
  out={cellRVA,row.onRVA+4u,repl.instructions[0]};
  ok=true;
 }while(false);
 munmap(base,length);close(fd);
 if(!ok){error=failure.empty()?"Value Cell postprocess failed":failure;return false;}
 error.clear();return true;
}
}
