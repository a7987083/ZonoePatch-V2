// Fail-closed regression: do not silently move chained starts across inserted segments.
#include "../ZNMachOFile.h"
#include <cstdint>
#include <cstring>
#include <cstdio>
#include <vector>
static void put32(std::vector<uint8_t> &b,size_t o,uint32_t v){memcpy(b.data()+o,&v,4);}
static void put64(std::vector<uint8_t> &b,size_t o,uint64_t v){memcpy(b.data()+o,&v,8);}
static std::vector<uint8_t> fixture(bool chained){
    std::vector<uint8_t> b(0x8000,0);
    put32(b,0,0xfeedfacf);put32(b,4,0x0100000c);put32(b,12,6);
    uint32_t count=chained?3:2;put32(b,16,count);put32(b,20,count*72-(chained?56:0));
    // Two segment commands and an optional chained-fixups linkedit command.
    put32(b,32,0x19);put32(b,36,72);
    memcpy(b.data()+40,"__TEXT",6);put64(b,32+24,0x100000000);
    put64(b,32+32,0x4000);put64(b,32+40,0);put64(b,32+48,0x4000);
    put32(b,104,0x19);put32(b,108,72);
    memcpy(b.data()+112,"__LINKEDIT",10);
    put64(b,104+24,0x100004000);put64(b,104+32,0x4000);
    put64(b,104+40,0x4000);put64(b,104+48,0x4000);
    if(chained){put32(b,176,0x80000034);put32(b,180,16);put32(b,184,0x5000);put32(b,188,32);}
    return b;
}
int main(){
    const char *why=nullptr;
    auto regular=fixture(false);
    if(!znmacho::shiftLinkedit(regular.data(),regular.size(),0x4000,0x4000,&why)){fprintf(stderr,"ordinary: %s\n",why?why:"?");return 1;}
    if(znmacho::read<uint64_t>(regular.data(),104+40)!=0x8000)return 2;
    auto chained=fixture(true),original=chained;
    why=nullptr;
    if(znmacho::shiftLinkedit(chained.data(),chained.size(),0x4000,0x4000,&why))return 3;
    if(chained!=original)return 4;
    if(!why||!strstr(why,"CHAINED_FIXUPS"))return 5;
    std::puts("PASS chained-fixups rejection is atomic; ordinary relocation unchanged");
    return 0;
}
