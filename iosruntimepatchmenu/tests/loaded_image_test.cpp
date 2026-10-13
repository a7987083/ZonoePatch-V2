#include "ZNLoadedImage.h"
#include <cassert>
#include <iostream>
struct Memory {std::vector<uint8_t> bytes=std::vector<uint8_t>(8192);uint64_t epoch=1,base=0x1000;bool live=true,change=false;unsigned reads=0;};
static uint64_t generation(void *p){return ((Memory*)p)->epoch;}
static bool copy(void *p,uint64_t address,void *out,size_t n){auto &m=*(Memory*)p;++m.reads;if(!m.live||address<m.base||!ZNCheckedRange64(m.bytes.size(),address-m.base,n))return false;memcpy(out,m.bytes.data()+address-m.base,n);if(m.change)++m.epoch;return true;}
template<class T> void put(Memory &m,size_t o,T v){memcpy(m.bytes.data()+o,&v,sizeof(v));}
static Memory fixture(){Memory m;put(m,0,0xfeedfacfu);put(m,4,0x100000cu);put(m,16,1u);put(m,20,72u);put(m,32,0x19u);put(m,36,72u);memcpy(m.bytes.data()+40,"__TEXT",6);put(m,56,uint64_t(0x8000));put(m,64,uint64_t(8192));put(m,80,uint64_t(8192));put(m,92,5u);return m;}
int main(){
 Memory m=fixture();znimage::Reader r{&m,copy,generation};auto s=znimage::Snapshot::capture(m.base,r);assert(s&&s->headerSize()==104); // filesize deliberately greater than owned header.
 uint64_t a=0;assert(s->translate(0x8001,&a)&&a==0x1001);assert(!s->translate(0,&a));assert(s->fileAddress(1024,4,&a)&&a==0x1400);
 uint32_t out=99;assert(s->read(m.base,&out,4)&&out==0xfeedfacf);assert(!s->read(UINT64_MAX,&out,4));
 auto copied=*s;m.bytes[40]='X';assert(copied.bytes()[40]=='_'); // Owned storage, copies do not retain pointers into predecessor.
 m.live=false;++m.epoch;out=99;assert(!s->valid()&&!s->read(m.base,&out,4)&&out==99); // unload/cache invalidation
 m=fixture();m.epoch=3;auto fresh=znimage::Snapshot::capture(m.base,r);assert(fresh&&fresh->valid()&&!s->valid()); // same-address reload ABA
 m.change=true;out=99;assert(!fresh->read(m.base,&out,4)&&out==99);assert(!znimage::Snapshot::capture(m.base,r));
 for(uint32_t len:{0u,8u,71u,UINT32_MAX}){m=fixture();put(m,36,len);assert(!znimage::Snapshot::capture(m.base,r));}
 m=fixture();put(m,96,UINT32_MAX);assert(!znimage::Snapshot::capture(m.base,r));
 m=fixture();put(m,64,UINT64_MAX);assert(!znimage::Snapshot::capture(m.base,r));
 m=fixture();put(m,20,UINT32_MAX);assert(!znimage::Snapshot::capture(m.base,r));
 m=fixture();znimage::Cache cache(r);auto first=cache.get(m.base);assert(first);unsigned reads=m.reads;assert(cache.get(m.base)==first&&m.reads==reads);
 ++m.epoch;auto second=cache.get(m.base);assert(second&&second!=first&&!first->valid());
 znimage::ReadWindow window(*second);uint32_t word=0;assert(window.copy(m.base,&word,4));reads=m.reads;assert(window.copy(m.base+4,&word,4)&&m.reads==reads);++m.epoch;assert(!window.copy(m.base,&word,4));
 m=fixture();m.bytes.resize(131072);put(m,64,uint64_t(m.bytes.size()));put(m,80,uint64_t(m.bytes.size()));auto large=znimage::Snapshot::capture(m.base,r);assert(large);znimage::ReadWindow largeWindow(*large);std::vector<uint8_t> destination(65537,0);assert(largeWindow.copy(m.base,destination.data(),destination.size()));assert(memcmp(destination.data(),m.bytes.data(),destination.size())==0);assert(!largeWindow.copy(m.base,nullptr,4));assert(!largeWindow.copy(m.base,destination.data(),0));++m.epoch;assert(!largeWindow.copy(m.base,destination.data(),destination.size()));
 std::cout<<"owned header/file-vs-mapping/VM read/unload/reload ABA/generation/overflow PASS\n";
}
