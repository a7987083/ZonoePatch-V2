#pragma once
#include "ZNMachOFile.h"
#include <memory>
#include <mutex>
#include <map>
namespace znimage {
struct Reader {
 void *context=nullptr;
 bool (*copy)(void *,uint64_t,void *,size_t)=nullptr;
 uint64_t (*generation)(void *)=nullptr;
};
struct Segment {uint64_t vm,size,file,fileSize,start;uint32_t protection;};
class Snapshot {
 Reader reader;uint64_t epoch=0,address=0,preferred=0;
 std::vector<uint8_t> storage;std::vector<znmacho::Command> commandList;std::vector<Segment> segmentList;
public:
 static std::shared_ptr<const Snapshot> capture(uint64_t address,Reader reader,const char **error=nullptr,bool arm64=true){
  auto fail=[&](const char *why)->std::shared_ptr<const Snapshot>{if(error)*error=why;return {};};
  if(!address||!reader.copy||!reader.generation)return fail("invalid image reader");
  uint64_t epoch=reader.generation(reader.context);uint8_t header[32];
  if(!reader.copy(reader.context,address,header,32))return fail("header unreadable");
  uint64_t size=32+uint64_t(znmacho::read<uint32_t>(header,20)),end;
  if(size>16*1024*1024||znmacho::read<uint32_t>(header,16)>4096||!ZNCheckedAdd64(address,size,&end))return fail("header capacity/address overflow");
  auto s=std::shared_ptr<Snapshot>(new Snapshot);s->storage.resize((size_t)size);
  if(!reader.copy(reader.context,address,s->storage.data(),(size_t)size)||memcmp(header,s->storage.data(),32))return fail("header changed/unreadable");
  znmacho::File view;const char *why=nullptr;
  if(!znmacho::parse(s->storage.data(),size,view,&why,arm64,false))return fail(why);
  bool found=false;
  for(const auto &c:view.commands)if(c.kind==0x19&&!strncmp((const char*)view.bytes+c.offset+8,"__TEXT",16)){
   if(found)return fail("ambiguous __TEXT");
   found=true;s->preferred=znmacho::read<uint64_t>(view.bytes,c.offset+24);
  }
  if(!found)return fail("missing __TEXT");
  s->address=address;s->reader=reader;s->epoch=epoch;s->commandList=view.commands;
  for(const auto &c:view.commands)if(c.kind==0x19){
   Segment seg={znmacho::read<uint64_t>(view.bytes,c.offset+24),znmacho::read<uint64_t>(view.bytes,c.offset+32),znmacho::read<uint64_t>(view.bytes,c.offset+40),znmacho::read<uint64_t>(view.bytes,c.offset+48),0,znmacho::read<uint32_t>(view.bytes,c.offset+60)};
   // Unmapped __PAGEZERO is metadata, not a readable range.
   if(seg.protection && (!s->translate(seg.vm,&seg.start)||!ZNCheckedAdd64(seg.start,seg.size,&end)))return fail("slid segment overflow");
   s->segmentList.push_back(seg);
  }
  if(!s->valid())return fail("image generation changed during capture");
  if(error)*error=nullptr;
  return s;
 }
 bool valid()const{return reader.generation&&reader.generation(reader.context)==epoch;}
 uint64_t generation()const{return epoch;}
 uint64_t runtimeBase()const{return address;}
 uint64_t preferredBase()const{return preferred;}
 const uint8_t *bytes()const{return storage.data();}
 size_t headerSize()const{return storage.size();}
 const std::vector<znmacho::Command> &commands()const{return commandList;}
 const std::vector<Segment> &segments()const{return segmentList;}
 bool translate(uint64_t vm,uint64_t *out)const{
  if(vm>=preferred)return ZNCheckedAdd64(address,vm-preferred,out);
  if(preferred-vm>address)return false;
  *out=address-(preferred-vm);return true;
 }
 bool contains(uint64_t addr,uint64_t length,uint32_t required=1)const{
  for(const auto &s:segmentList)if((s.protection&required)==required&&addr>=s.start&&ZNCheckedRange64(s.size,addr-s.start,length))return true;
  return false;
 }
 bool read(uint64_t addr,void *out,size_t length)const{
  if(!out||!length||length>64*1024*1024||!valid()||!contains(addr,length))return false;
  std::vector<uint8_t> tmp(length);
  if(!reader.copy(reader.context,addr,tmp.data(),length)||!valid())return false;
  memcpy(out,tmp.data(),length);return true;
 }
 bool fileAddress(uint64_t offset,uint64_t length,uint64_t *out)const{
  for(const auto &s:segmentList)if(offset>=s.file&&ZNCheckedRange64(s.fileSize,offset-s.file,length)&&ZNCheckedRange64(s.size,offset-s.file,length)){
   uint64_t vm;if(!ZNCheckedAdd64(s.vm,offset-s.file,&vm))return false;
   return translate(vm,out);
  }return false;
 }
};
class Cache {
 Reader reader;std::mutex lock;uint64_t epoch=0;std::map<uint64_t,std::shared_ptr<const Snapshot>> entries;
public:
 explicit Cache(Reader r):reader(r){}
 std::shared_ptr<const Snapshot> get(uint64_t address,const char **error=nullptr,bool arm64=true){
  std::lock_guard<std::mutex> guard(lock);
  uint64_t current=reader.generation(reader.context);
  if(current!=epoch){entries.clear();epoch=current;}
  auto found=entries.find(address);if(found!=entries.end()&&found->second->valid())return found->second;
  auto snapshot=Snapshot::capture(address,reader,error,arm64);
  if(snapshot){if(entries.size()>=256)entries.clear();entries[address]=snapshot;}
  return snapshot;
 }
};
class ReadWindow {
 const Snapshot &image;uint64_t start=0;std::vector<uint8_t> bytes;
public:
 explicit ReadWindow(const Snapshot &s):image(s){}
 bool copy(uint64_t address,void *out,size_t length){
  if(!image.valid())return false;
  if(address>=start&&ZNCheckedRange64(bytes.size(),address-start,length)){memcpy(out,bytes.data()+address-start,length);return true;}
  for(const auto &seg:image.segments())if((seg.protection&1)&&address>=seg.start&&ZNCheckedRange64(seg.size,address-seg.start,length)){
   start=address;size_t size=(size_t)std::min<uint64_t>(65536,seg.size-(address-seg.start));bytes.resize(size);
   if(!image.read(start,bytes.data(),size)){bytes.clear();return false;}
   memcpy(out,bytes.data(),length);return true;
  }return false;
 }
};

}
