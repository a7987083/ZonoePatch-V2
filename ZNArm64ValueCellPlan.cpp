#include "ZNArm64ValueCellPlan.hpp"
#include <limits>
namespace ZNArm64ValueCellPlan {
bool plan(const ZNArm64NumericInstruction::Site &site,uint64_t codeRVA,
          uint64_t cellRVA,Replacement &result,std::string &error){
 auto fail=[&](const char *message){error=message;return false;};
 if(!site.wordCount||site.wordCount>4||site.destination>=32||
    !codeRVA||(codeRVA&3u)||!cellRVA)
  return fail("invalid instruction count, register or code RVA");
 const bool f32=site.type==ZNArm64NumericInstruction::ValueType::Float32;
 const bool f64=site.type==ZNArm64NumericInstruction::ValueType::Float64;
 const bool i32=site.type==ZNArm64NumericInstruction::ValueType::Int32||
                site.type==ZNArm64NumericInstruction::ValueType::UInt32;
 const bool i64=site.type==ZNArm64NumericInstruction::ValueType::Int64||
                site.type==ZNArm64NumericInstruction::ValueType::UInt64;
 if(!(f32||f64||i32||i64))return fail("invalid cell value type");
 if((site.family==ZNArm64NumericInstruction::Family::FmovImmediate)!=(f32||f64))
  return fail("FP/integer instruction family mismatch");
 if((f32||f64)&&site.wordCount!=1)
  return fail("FMOV must be one instruction");
 const uint8_t width=(f64||i64)?8:4;
 if(cellRVA%width)return fail("cell not naturally aligned");
 if(codeRVA>UINT64_MAX-4*site.wordCount)
  return fail("source instruction span overflow");
 const uint64_t end=codeRVA+4*site.wordCount;
 if(cellRVA>=codeRVA&&cellRVA<end)
  return fail("cell overlaps source instructions");
 const __int128 delta=(__int128)cellRVA-(__int128)codeRVA;
 if((delta&3)!=0||delta<-1048576||delta>1048572)
  return fail("LDR literal PC-relative displacement outside signed imm19 range");
 const uint32_t base=i32?0x18000000u:i64?0x58000000u:
                     f32?0x1c000000u:0x5c000000u;
 Replacement candidate{};
 candidate.instructionCount=site.wordCount;candidate.cellWidth=width;
 const int64_t units=(int64_t)(delta/4);
 candidate.instructions[0]=base|((uint32_t(units)&0x7ffffu)<<5)|site.destination;
 for(unsigned i=1;i<site.wordCount;++i)
  candidate.instructions[i]=0xd503201fu;
 for(unsigned i=0;i<width;++i)
  candidate.originalCellBytes[i]=(uint8_t)(site.originalBits>>(8*i));
 result=candidate;error.clear();return true;
}
}
