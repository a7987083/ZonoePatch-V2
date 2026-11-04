#include "../ZNArm64ValueCellPlan.hpp"
#include <cstdio>
#include <string>
using namespace ZNArm64NumericInstruction;
using namespace ZNArm64ValueCellPlan;
static int failed=0;
static void check(bool ok,const char *title){
 if(!ok){++failed;std::fprintf(stderr,"FAIL: %s\n",title);}
}
static Site make(ValueType type,Family family,uint8_t reg,uint8_t count,uint64_t bits){
 Site s;s.type=type;s.family=family;s.destination=reg;s.wordCount=count;s.originalBits=bits;return s;
}
int main(){
 std::string error;Replacement result{};
 check(plan(make(ValueType::Float32,Family::FmovImmediate,0,1,0x3f800000),
            0x1000,0x1014,result,error),"Float32 literal");
 check(result.instructions[0]==0x1c0000a0u&&result.originalCellBytes[2]==0x80&&
       result.originalCellBytes[3]==0x3f,"LDR S0 and FP cell bytes match clang assembly");
 check(plan(make(ValueType::Float64,Family::FmovImmediate,0,1,UINT64_C(0x3ff0000000000000)),
            0x1004,0x1018,result,error),"Float64 literal");
 check(result.instructions[0]==0x5c0000a0u&&result.cellWidth==8,"LDR D0 fixture");
 check(plan(make(ValueType::Int32,Family::MovzWide,0,2,0xabcd000au),
            0x1008,0x101c,result,error),"MOVZ/MOVK constant literal");
 check(result.instructions[0]==0x180000a0u&&result.instructions[1]==0xd503201fu,
       "LDR W0 and NOP match clang assembly");
 check(plan(make(ValueType::Int64,Family::MovzWide,0,1,10),
            0x100c,0x1020,result,error),"Int64 literal");
 check(result.instructions[0]==0x580000a0u,"LDR X0 fixture");
 check(plan(make(ValueType::Int32,Family::MovnWide,0,1,0xffffffffu),
            0x2000,0x1000,result,error),"negative displacement");
 check(!plan(make(ValueType::Float32,Family::FmovImmediate,0,1,0),
            0x2000,0x1003,result,error),"unaligned cell refused");
 check(!plan(make(ValueType::Float32,Family::FmovImmediate,0,1,0),
            0x2000,0x2000,result,error),"code/cell overlap refused");
 check(!plan(make(ValueType::Float64,Family::FmovImmediate,0,1,0),
            0x2000,0x102001,result,error),"out of range refused");
 check(plan(make(ValueType::Float32,Family::FmovImmediate,0,1,0),
            0x200000,0x100000,result,error),"negative -1 MiB limit");
 check(result.instructions[0]==0x1c800000u,"negative boundary immediate encoding");
 check(!plan(make(ValueType::Float32,Family::FmovImmediate,0,1,0),
            0x200000,0xffffc,result,error),"negative beyond limit refused");
 check(!plan(make(ValueType::Int32,Family::FmovImmediate,0,1,0),
            0x2000,0x3000,result,error),"family/type mismatch refused");
 check(!plan(make(ValueType::Float32,Family::FmovImmediate,0,2,0),
            0x2000,0x3000,result,error),"multiword FMOV refused");
 printf("P10.7.2 LDR literal Value Cell planner: %s (%d failures)\n",
        failed?"FAIL":"PASS",failed);
 return failed?1:0;
}
