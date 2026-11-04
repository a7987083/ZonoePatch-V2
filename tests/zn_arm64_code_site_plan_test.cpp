#include "../ZNArm64CodeSitePlan.hpp"
#include <cstdio>
#include <cstdint>
#include <vector>
#include <string>
using namespace ZNArm64CodeSitePlan;
using namespace ZNArm64NumericInstruction;
static int failures=0;
static void check(bool ok,const char*name){if(!ok){++failures;fprintf(stderr,"FAIL %s\n",name);}}
static void pack(const std::vector<uint32_t>&words,std::vector<uint8_t>&bytes){
 bytes.clear();for(uint32_t x:words)for(int j=0;j<4;j++)bytes.push_back(uint8_t(x>>(j*8)));
}
static Candidate make(const uint32_t *p,size_t n,uint64_t rva=0x1000){
 Candidate c;c.featureID="feature";c.ruleID="rule";c.imageUUID="uuid";
 c.sourcePath="/Game/UnityFramework";c.rva=rva;c.fileOffset=rva+0x1000;
 c.words=p;c.availableWords=n;c.type=ValueType::Int32;return c;
}
int main(){
 const std::vector<uint32_t> words={0x52800140u,0x72b579a0u,0xd503201fu,0xd65f03c0u};
 std::vector<uint8_t> section;pack(words,section);
 std::vector<CodeRegion> code={{0x1000,section.data(),section.size()}};
 auto c=make(words.data(),3);Prepared prepared{};std::string error;
 check(prepare(c,code,prepared,error),"valid 2-word MOVZ+MOVK is prepared");
 check(prepared.originalBytes.size()==8&&prepared.stagingNopBytes.size()==8&&
       prepared.instruction.wordCount==2&&prepared.originalBytes[0]==0x40&&
       prepared.stagingNopBytes[0]==0x1f,"correct original/staging bytes");
 check(validateDisjoint({prepared},{},error),"disjoint code site");
 check(!validateDisjoint({prepared},{{0x1004,0x2004,4}},error),"P9 overlap rejected");
 check(validateDisjoint({prepared},{{0x1008,0x2008,4}},error),"adjacent P9 allowed");
 check(!validateDisjoint({prepared},{{0x3000,0x2004,4}},error),
       "file-only overlap rejected");
 check(!validateDisjoint({prepared},{{UINT64_MAX,0x2000,4}},error),
       "reserved span overflow rejected");
 auto duplicate=prepared;duplicate.ruleID="other";duplicate.rva=0x1004;duplicate.fileOffset+=4;
 check(!validateDisjoint({prepared,duplicate},{},error),"interior code overlap rejected");
 duplicate=prepared;duplicate.ruleID="other";duplicate.rva=0x2000;duplicate.fileOffset=0x3000;
 duplicate.imageUUID="other";
 check(!validateDisjoint({prepared,duplicate},{},error),"different images rejected");
 std::vector<uint8_t> branches;pack({0x14000002u,0x52800140u,0x72b579a0u,0xd65f03c0u},branches);
 std::vector<CodeRegion> inbound={{0x0ffc,branches.data(),branches.size()}};
 check(!prepare(c,inbound,prepared,error),"direct B to second instruction rejected");
 // BL also uses the same branch immediate classifier.
 pack({0x94000002u,0x52800140u,0x72b579a0u,0xd65f03c0u},branches);
 check(!prepare(c,inbound,prepared,error),"BL to interior rejected");
 pack({0x54000040u,0x52800140u,0x72b579a0u,0xd65f03c0u},branches);
 check(!prepare(c,inbound,prepared,error),"B.cond to interior rejected");
 pack({0x34000040u,0x52800140u,0x72b579a0u,0xd65f03c0u},branches);
 check(!prepare(c,inbound,prepared,error),"CBZ to interior rejected");
 pack({0x36000040u,0x52800140u,0x72b579a0u,0xd65f03c0u},branches);
 check(!prepare(c,inbound,prepared,error),"TBZ to interior rejected");
 auto changed=words;changed[1]=0xd503201fu;std::vector<uint8_t> wrong;pack(changed,wrong);
 std::vector<CodeRegion> wrongCode={{0x1000,wrong.data(),wrong.size()}};
 check(!prepare(c,wrongCode,prepared,error),"disk/live original mismatch rejected");
 c=make(words.data(),3);c.type=ValueType::Float32;
 check(!prepare(c,code,prepared,error),"wrong integer/float type refused");
 c=make(words.data(),3);c.fileOffset=0x1001;
 check(!prepare(c,code,prepared,error),"misaligned file offset refused");
 c=make(words.data(),3);
 check(!prepare(c,{},prepared,error),"missing executable section refused");
 printf("P10.7.3 ARM64 code-window staging: %s (%d failures)\n",
  failures?"FAIL":"PASS",failures);
 return failures?1:0;
}
