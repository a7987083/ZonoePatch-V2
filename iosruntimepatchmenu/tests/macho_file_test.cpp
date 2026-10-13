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
 uint64_t a=0;assert(znmacho::align(17,16,&a)&&a==32);assert(!znmacho::align(UINT64_MAX,16,&a));assert(!znmacho::align(1,3,&a));
 std::mt19937 rng(0x5a4e);for(int i=0;i<20000;i++){b=original;for(int j=0;j<4;j++)b[rng()%b.size()]=uint8_t(rng());znmacho::parse(b.data(),b.size(),f);auto unchanged=b;if(!znmacho::shiftLinkedit(b.data(),b.size(),256,UINT64_MAX))assert(b==unchanged);}
 std::cout<<"Mach-O parse/transactional shift/golden/fuzz PASS (seed 0x5a4e, 20000)\n";
}
