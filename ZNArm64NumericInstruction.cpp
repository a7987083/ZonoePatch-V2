#include "ZNArm64NumericInstruction.hpp"
#include <limits>
namespace ZNArm64NumericInstruction {
namespace {
constexpr uint32_t kWideMask=0x7f800000u;
constexpr uint32_t kMovz=0x52800000u,kMovn=0x12800000u,kMovk=0x72800000u;
constexpr uint32_t kFmovMask=0xff201fe0u,kFmov=0x1e201000u;
bool wide(uint32_t w,uint32_t kind){return (w&kWideMask)==kind;}
bool is32(ValueType t){return t==ValueType::Int32||t==ValueType::UInt32;}
bool is64(ValueType t){return t==ValueType::Int64||t==ValueType::UInt64;}
uint64_t fmovBits(uint8_t imm,bool dbl){
 const uint64_t sign=(imm>>7)&1,b=(imm>>6)&1,low=(imm>>4)&3,frac=imm&15;
 if(dbl){
  const uint64_t exp=((b?0ULL:1ULL)<<10)|(b?0x3fcULL:0ULL)|low;
  return (sign<<63)|(exp<<52)|(frac<<48);
 }
 const uint64_t exp=((b?0ULL:1ULL)<<7)|(b?0x7cULL:0ULL)|low;
 return (sign<<31)|(exp<<23)|(frac<<19);
}
}
bool analyze(const uint32_t *words,size_t available,ValueType requested,
             Site &result,std::string &reason){
 auto fail=[&](const char *text){reason=text;return false;};
 if(!words||!available||available>5)
  return fail("instruction window must contain 1..5 words");
 const uint32_t first=words[0];
 Site candidate{};candidate.type=requested;candidate.destination=uint8_t(first&31u);
 if((first&kFmovMask)==kFmov){
  const unsigned precision=(first>>22)&3u;
  if(precision>1)return fail("unsupported scalar FMOV precision");
  const bool dbl=precision==1;
  if((dbl&&requested!=ValueType::Float64)||(!dbl&&requested!=ValueType::Float32))
   return fail("FMOV precision does not match selected numeric type");
  candidate.family=Family::FmovImmediate;candidate.wordCount=1;
  candidate.originalBits=fmovBits(uint8_t((first>>13)&0xffu),dbl);
  result=candidate;reason.clear();return true;
 }
 const bool movz=wide(first,kMovz),movn=wide(first,kMovn);
 if(!movz&&!movn){
  if(wide(first,kMovk))return fail("MOVK alone is a partial update, not a constant producer");
  if((first&0x7fe0ffe0u)==0x2a0003e0u)
   return fail("MOV register alias depends on a source register");
  return fail("unsupported ARM64 instruction; semantic analysis required");
 }
 const bool register64=(first>>31)!=0;
 if((register64&&!is64(requested))||(!register64&&!is32(requested)))
  return fail("MOV W/X register width does not match selected type");
 const unsigned hw=(first>>21)&3u;
 if(!register64&&hw>1)return fail("invalid 32-bit MOV halfword shift");
 const uint64_t mask=register64?UINT64_MAX:UINT64_C(0xffffffff);
 const uint64_t immediate=uint64_t((first>>5)&0xffffu)<<(hw*16u);
 uint64_t value=movn?(~immediate&mask):immediate;
 uint8_t seen=uint8_t(1u<<hw);
 size_t count=1;
 for(;count<available&&count<4;++count){
  const uint32_t next=words[count];
  if(!wide(next,kMovk))break;
  if(((next>>31)!=0)!=register64||(next&31u)!=candidate.destination)
   return fail("MOVK chain changes register or width");
  const unsigned chunk=(next>>21)&3u;
  if((!register64&&chunk>1)||(seen&(1u<<chunk)))
   return fail("MOVK chain contains invalid or duplicate halfword");
  seen=uint8_t(seen|(1u<<chunk));
  const uint64_t field=UINT64_C(0xffff)<<(chunk*16u);
  value=(value&~field)|(uint64_t((next>>5)&0xffffu)<<(chunk*16u));
 }
 if(count==4&&available==5&&wide(words[4],kMovk))
  return fail("MOVK chain exceeds four instructions");
 candidate.family=movz?Family::MovzWide:Family::MovnWide;
 candidate.wordCount=uint8_t(count);candidate.originalBits=value&mask;
 result=candidate;reason.clear();return true;
}
} // namespace ZNArm64NumericInstruction
