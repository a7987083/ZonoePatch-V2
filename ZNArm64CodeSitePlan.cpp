#include "ZNArm64CodeSitePlan.hpp"
#include <limits>
#include <utility>
#include <unordered_set>
namespace ZNArm64CodeSitePlan {
namespace {
int64_t signedImmediate(uint32_t value,unsigned bits){
 const uint64_t sign=uint64_t(1)<<(bits-1u);
 return (int64_t)((uint64_t(value)^sign)-sign);
}
bool branchTarget(uint32_t word,uint64_t source,uint64_t &dest) {
 uint32_t field=0;unsigned bits=0;
 if((word&0x7c000000u)==0x14000000u){field=word&0x03ffffffu;bits=26;}
 else if((word&0xff000010u)==0x54000000u){field=(word>>5)&0x7ffffu;bits=19;}
 else if((word&0x7e000000u)==0x34000000u){field=(word>>5)&0x7ffffu;bits=19;}
 else if((word&0x7e000000u)==0x36000000u){field=(word>>5)&0x3fffu;bits=14;}
 else return false;
 const __int128 target=(__int128)source+(__int128)signedImmediate(field,bits)*4;
 if(target<0||target>UINT64_MAX)return false;
 dest=(uint64_t)target;return true;
}
bool intersects(uint64_t start,uint64_t length,uint64_t other,uint64_t otherLength) {
 if(!length||!otherLength||start>UINT64_MAX-length||other>UINT64_MAX-otherLength)return true;
 return start<other+otherLength&&other<start+length;
}
}
bool prepare(const Candidate &site,const std::vector<CodeRegion> &regions,
             Prepared &out,std::string &error) {
 auto fail=[&](const char *message){error=message;return false;};
 if(site.featureID.empty()||site.ruleID.empty()||site.imageUUID.empty()||
    site.sourcePath.empty()||!site.rva||!(site.rva%4u==0)||
    (site.fileOffset&3u)||site.fileOffset>UINT64_MAX-20u)
  return fail("invalid site ownership, image identity or alignment");
 if(!site.words||!site.availableWords||site.availableWords>5u)
  return fail("missing or oversized executable instruction window");
 ZNArm64NumericInstruction::Site instruction{};
 if(!ZNArm64NumericInstruction::analyze(site.words,site.availableWords,site.type,
                                         instruction,error))return false;
 const uint64_t size=uint64_t(instruction.wordCount)*4u;
 if(!size||site.rva>UINT64_MAX-size)
  return fail("site instruction window overflows RVA");
 if(regions.empty())return fail("all executable instruction regions required");
 bool ownsWindow=false;
 for(const auto &region:regions){
  if(!region.bytes||!region.length||(region.length&3u)||region.rva>UINT64_MAX-region.length)
   return fail("malformed executable instruction region");
  if(site.rva>=region.rva&&site.rva-region.rva<=region.length&&
     size<=region.length-(site.rva-region.rva)){
   if(ownsWindow)return fail("duplicate executable region ownership");
   const auto *actual=region.bytes+(site.rva-region.rva);
   for(size_t i=0;i<instruction.wordCount;i++){
    const uint32_t w=uint32_t(actual[i*4u])|uint32_t(actual[i*4u+1])<<8u|
       uint32_t(actual[i*4u+2])<<16u|uint32_t(actual[i*4u+3])<<24u;
    if(w!=site.words[i])return fail("source instruction differs from the checked file section");
   }
   ownsWindow=true;
  }
 }
 if(!ownsWindow)return fail("code window does not belong to a validated executable region");
 // Identical direct-branch categories to the existing P9 inbound interior scan.
 // Indirect/register-computed control flow must be assessed separately.
 for(const auto &region:regions)for(size_t i=0;i<region.length;i+=4u){
  const uint32_t instruction=uint32_t(region.bytes[i])|
    uint32_t(region.bytes[i+1])<<8u|uint32_t(region.bytes[i+2])<<16u|
    uint32_t(region.bytes[i+3])<<24u;
  uint64_t dest=0;
  if(branchTarget(instruction,region.rva+i,dest)&&dest>site.rva&&dest<site.rva+size)
   return fail("inbound direct branch targets the interior of the numeric instruction chain");
 }
 Prepared staged{};
 staged.featureID=site.featureID;staged.ruleID=site.ruleID;
 staged.imageUUID=site.imageUUID;staged.sourcePath=site.sourcePath;
 staged.rva=site.rva;staged.fileOffset=site.fileOffset;staged.instruction=instruction;
 for(size_t i=0;i<instruction.wordCount;i++){
  const uint32_t w=site.words[i];
  for(unsigned b=0;b<4;b++){
   staged.originalBytes.push_back(uint8_t(w>>(8u*b)));
   staged.stagingNopBytes.push_back(uint8_t(UINT32_C(0xd503201f)>>(8u*b)));
  }
 }
 out=std::move(staged);error.clear();return true;
}
bool validateDisjoint(const std::vector<Prepared> &sites,
                      const std::vector<ReservedSpan> &reserved,
                      std::string &error){
 auto fail=[&](const char *msg){error=msg;return false;};
 if(sites.empty()||sites.size()>128)return fail("code site count outside 1..128");
 std::unordered_set<std::string> ruleIDs;
 for(size_t i=0;i<sites.size();i++){
  const auto &s=sites[i];
  if(s.featureID.empty()||s.ruleID.empty()||!ruleIDs.insert(s.ruleID).second||
     s.imageUUID.empty()||s.sourcePath.empty()||s.originalBytes.empty()||
     s.originalBytes.size()!=s.stagingNopBytes.size()||
     s.originalBytes.size()!=size_t(s.instruction.wordCount)*4u||
     s.rva>UINT64_MAX-s.originalBytes.size()||
     s.fileOffset>UINT64_MAX-s.originalBytes.size())
   return fail("invalid code site structure or duplicate rule ID");
  for(const auto &other:reserved){
   if(!other.width||other.rva>UINT64_MAX-other.width||
      other.fileOffset>UINT64_MAX-other.width)
    return fail("invalid reserved P9 span");
   if(intersects(s.rva,s.originalBytes.size(),other.rva,other.width)||
      intersects(s.fileOffset,s.originalBytes.size(),other.fileOffset,other.width))
    return fail("numeric code window overlaps an existing P9 patch");
  }
  for(size_t j=0;j<i;j++){
   const auto &prev=sites[j];
   if(s.imageUUID!=prev.imageUUID||s.sourcePath!=prev.sourcePath)
    return fail("different image identity across numeric code sites");
   if(intersects(s.rva,s.originalBytes.size(),prev.rva,prev.originalBytes.size())||
      intersects(s.fileOffset,s.originalBytes.size(),prev.fileOffset,prev.originalBytes.size()))
    return fail("numeric code windows overlap");
  }
 }
 error.clear();return true;
}
}
