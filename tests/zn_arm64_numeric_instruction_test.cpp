#include "../ZNArm64NumericInstruction.hpp"
#include <cstdio>
#include <cstdint>
#include <string>
using namespace ZNArm64NumericInstruction;
static int failed=0;
static void check(bool b,const char *name){if(!b){++failed;std::fprintf(stderr,"FAIL: %s\n",name);}}
static bool good(const uint32_t *w,size_t n,ValueType t,uint8_t reg,uint64_t bits,uint8_t count){
 Site s{};std::string e;
 const bool ok=analyze(w,n,t,s,e);
 if(!ok)std::fprintf(stderr,"rejected: %s\n",e.c_str());
 return ok&&s.destination==reg&&s.originalBits==bits&&s.wordCount==count;
}
static bool bad(const uint32_t *w,size_t n,ValueType t){
 Site s{};std::string e;return !analyze(w,n,t,s,e)&&!e.empty();
}
int main(){
 // Fixture words assembled with clang -target aarch64-apple-darwin.
 const uint32_t fs[]={0x1e2e1000u}; // fmov s0,#1.0
 const uint32_t fd[]={0x1e6e1000u}; // fmov d0,#1.0
 const uint32_t w[]={0x52800140u,0x72b579a0u,0xd65f03c0u}; // movz w0,#10; movk w0,#0xabcd,lsl#16; ret
 const uint32_t x[]={0xd2800142u,0xf2f579a2u};
 const uint32_t mn[]={0x12800000u}; // movn w0,#0
 const uint32_t reg[]={0x2a0103e0u}; // mov w0,w1 (ORR alias)
 const uint32_t bl[]={0x94000001u}; // bl target
 const uint32_t lone[]={0x72b579a0u};
 const uint32_t wrong[]={0x52800140u,0x72b579a1u};
 const uint32_t duplicate[]={0x52800140u,0x72800140u};
 check(good(fs,1,ValueType::Float32,0,0x3f800000u,1),"FMOV S0 Float32");
 check(good(fd,1,ValueType::Float64,0,UINT64_C(0x3ff0000000000000),1),"FMOV D0 Float64");
 check(bad(fs,1,ValueType::Int32),"FMOV wrong type");
 check(good(w,3,ValueType::Int32,0,0xabcd000au,2),"MOVZ W + MOVK");
 check(good(x,2,ValueType::UInt64,2,UINT64_C(0xabcd00000000000a),2),"MOVZ X + MOVK");
 check(bad(x,2,ValueType::Int32),"MOV X mismatch");
 check(good(mn,1,ValueType::Int32,0,0xffffffffu,1),"MOVN W");
 check(bad(reg,1,ValueType::Int32),"MOV register dependency");
 check(bad(bl,1,ValueType::Int32),"BL not numeric");
 check(bad(lone,1,ValueType::Int32),"orphan MOVK");
 check(bad(wrong,2,ValueType::Int32),"MOVK changed destination");
 check(bad(duplicate,2,ValueType::Int32),"duplicate MOVK halfword");
 check(bad(fs,0,ValueType::Float32),"zero length");
 check(bad(fs,6,ValueType::Float32),"oversized window");
 const uint32_t longChain[]={0xd2800142u,0xf2f579a2u,0xf2e00142u,0xf2c00142u,0xf2a00142u};
 check(bad(longChain,5,ValueType::Int64),"oversized MOVK chain");
 std::printf("P10.7.1 ARM64 numeric decoder: %s (%d failures)\n",failed?"FAIL":"PASS",failed);
 return failed?1:0;
}
