#include "ZNMachOFile.h"
#include <cassert>
#include <random>
#include <iostream>
using Bytes=std::vector<uint8_t>;
template<class T> void put(Bytes &b,size_t o,T v){memcpy(b.data()+o,&v,sizeof(v));}
Bytes fixture(){
 Bytes b(512,0);put(b,0,0xfeedfacfu);put(b,4,0x100000cu);put(b,16,3u);put(b,20,112u);
 put(b,32,0x19u);put(b,36,72u);memcpy(b.data()+40,"__LINKEDIT",10);
 put(b,56,uint64_t(0x1000));put(b,64,uint64_t(0x100));put(b,72,uint64_t(256));put(b,80,uint64_t(32));
 put(b,104,2u);put(b,108,24u);put(b,112,256u);put(b,120,288u);
 put(b,128,0x1du);put(b,132,16u);put(b,136,320u);put(b,140,32u);
 return b;
}
int main(){
 auto b=fixture(),original=b;znmacho::File f;assert(znmacho::parse(b.data(),b.size(),f));assert(f.commands.size()==3);
 assert(znmacho::shiftLinkedit(b.data(),b.size(),256,16));
 auto expected=original;put(expected,56,uint64_t(0x1010));put(expected,72,uint64_t(272));put(expected,112,272u);put(expected,120,304u);put(expected,136,336u);
 assert(b==expected); // Independent full-byte golden: all unmodified payload/commands retained.
 b=original;put(b,120,UINT32_MAX);auto before=b;assert(!znmacho::shiftLinkedit(b.data(),b.size(),256,16));assert(b==before);
 b=original;put(b,56,UINT64_MAX-4);put(b,64,uint64_t(0));before=b;assert(!znmacho::shiftLinkedit(b.data(),b.size(),256,16));assert(b==before);
 for(size_t n=0;n<144;n++){b=original;assert(!znmacho::parse(b.data(),n,f));}
 for(uint32_t count:{UINT32_MAX,100u}){b=original;put(b,16,count);assert(!znmacho::parse(b.data(),b.size(),f));}
 for(uint32_t len:{0u,7u,8u,71u,UINT32_MAX}){b=original;put(b,36,len);assert(!znmacho::parse(b.data(),b.size(),f));}
 b=original;put(b,96,UINT32_MAX);assert(!znmacho::parse(b.data(),b.size(),f));
 b=original;put(b,72,UINT64_MAX);assert(!znmacho::parse(b.data(),b.size(),f));
 b=original;put(b,4,7u);assert(!znmacho::parse(b.data(),b.size(),f));assert(znmacho::parse(b.data(),b.size(),f,nullptr,false));
 // Section byte extent, overflow, zerofill semantics.
 b=Bytes(512,0);put(b,0,0xfeedfacfu);put(b,4,0x100000cu);put(b,16,1u);put(b,20,152u);put(b,32,0x19u);put(b,36,152u);put(b,96,1u);
 put(b,144,uint64_t(16));put(b,152,500u);assert(!znmacho::parse(b.data(),b.size(),f));
 put(b,168,1u);assert(znmacho::parse(b.data(),b.size(),f));
 put(b,136,UINT64_MAX);assert(!znmacho::parse(b.data(),b.size(),f));
 // Shared owner locator: contained, missing, duplicate and out-of-owner cases.
 b=Bytes(512,0);put(b,0,0xfeedfacfu);put(b,4,0x100000cu);put(b,16,1u);put(b,20,152u);put(b,32,0x19u);put(b,36,152u);put(b,96,1u);
 memcpy(b.data()+40,"__ZNDATA",8);memcpy(b.data()+104,"__zndata",8);put(b,80,uint64_t(512));put(b,144,uint64_t(16));put(b,152,400u);
 assert(znmacho::parse(b.data(),b.size(),f));znmacho::SectionLocation loc;assert(znmacho::findSection(f,"__ZNDATA","__zndata",loc)&&loc.sectionOffset==104);
 assert(!znmacho::findSection(f,"__ZNDATA","missing",loc));put(b,80,uint64_t(128));assert(znmacho::parse(b.data(),b.size(),f));assert(!znmacho::findSection(f,"__ZNDATA","__zndata",loc));
 put(b,80,uint64_t(512));memcpy(b.data()+184,b.data()+32,152);put(b,16,2u);put(b,20,304u);assert(znmacho::parse(b.data(),b.size(),f));assert(!znmacho::findSection(f,"__ZNDATA","__zndata",loc));
 // Independent edit goldens for every shifted command field family.
 for(uint32_t kind:{0x22u,0x80000022u,2u,0xbu,0x16u,0x31u,0x1du,0x1eu,0x26u,0x29u,0x2bu,0x2eu,0x80000033u,0x80000034u}){
  b=Bytes(512,0);put(b,0,0xfeedfacfu);put(b,4,0x100000cu);put(b,16,1u);uint32_t len=znmacho::minimum(kind);put(b,20,len);put(b,32,kind);put(b,36,len);
  std::vector<unsigned> fields;
  if(kind==0x22||kind==0x80000022)fields={8,16,24,32,40};else if(kind==2)fields={8,16};else if(kind==0xb)fields={32,40,48,56,64,72};else fields={kind==0x31?24u:8u};
  for(auto x:fields)if(kind==0x31)put(b,32+x,uint64_t(256));else put(b,32+x,256u);
  expected=b;for(auto x:fields)if(kind==0x31)put(expected,32+x,uint64_t(272));else put(expected,32+x,272u);
  assert(znmacho::shiftLinkedit(b.data(),b.size(),256,16));assert(b==expected);
 }
 uint64_t a=0;assert(znmacho::align(17,16,&a)&&a==32);assert(!znmacho::align(UINT64_MAX,16,&a));assert(!znmacho::align(1,3,&a));
 std::mt19937 rng(0x5a4e);for(int i=0;i<20000;i++){b=original;for(int j=0;j<4;j++)b[rng()%b.size()]=uint8_t(rng());znmacho::parse(b.data(),b.size(),f);auto unchanged=b;if(!znmacho::shiftLinkedit(b.data(),b.size(),256,UINT64_MAX))assert(b==unchanged);}
 std::cout<<"Mach-O parse/transactional shift/golden/fuzz PASS (seed 0x5a4e, 20000)\n";
}
