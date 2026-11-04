#include "ZNUnifiedBuildPlan.hpp"
#include <unordered_set>

namespace ZNUnifiedBuildPlan {
namespace {
struct Site {std::string uuid,path,owner;uint64_t rva,file,width;};
bool overlap(uint64_t a,uint64_t n,uint64_t b,uint64_t m) {
 return a<b+m && b<a+n;
}
}
bool validate(const Plan &plan,std::string &error) {
 auto fail=[&](const std::string &s){error=s;return false;};
 if(plan.version!=kSchemaVersion)return fail("unknown unified plan version");
 if(plan.features.empty()||plan.features.size()>kMaxFeatures)
  return fail("feature count outside 1..128");
 std::unordered_set<std::string> ids;
 std::vector<Site> sites;
 for(const Feature &f:plan.features) {
  if(f.featureID.empty()||f.name.empty()||f.imageUUID.empty()||f.sourcePath.empty())
   return fail("missing feature or image identity");
  if(!ids.insert(f.featureID).second)return fail("duplicate feature ID");
  if(f.control!=Control::Toggle&&f.control!=Control::Input&&f.control!=Control::Slider)
   return fail("unsupported feature control");
  if(f.rules.empty()||f.rules.size()>kMaxRules)return fail("rules outside 1..128 per feature");
  std::unordered_set<std::string> ruleIDs;
  for(const Rule &r:f.rules) {
   if(r.ruleID.empty()||!ruleIDs.insert(r.ruleID).second)
    return fail("missing or duplicate rule ID");
   if(r.kind!=RuleKind::PatchBytes&&r.kind!=RuleKind::TypedValue)
    return fail("unknown rule kind");
   if((f.control==Control::Toggle)!=(r.kind==RuleKind::PatchBytes))
    return fail("control and rule kind mismatch");
   if(!r.width||r.width>256||r.rva>UINT64_MAX-r.width||
      r.fileOffset>UINT64_MAX-r.width)
    return fail("invalid or overflowing address range");
   if(r.kind==RuleKind::PatchBytes &&
      (r.width<4||(r.width&3u)||(r.rva&3u)||(r.fileOffset&3u)))
    return fail("invalid ARM64 patch alignment or width");
   if(r.kind==RuleKind::TypedValue &&
      ((r.width!=1&&r.width!=2&&r.width!=4&&r.width!=8)||
       r.rva%r.width||r.fileOffset%r.width))
    return fail("invalid typed-value width or alignment");
   for(const Site &old:sites) {
    if(old.uuid==f.imageUUID&&old.path!=f.sourcePath)
     return fail("same image UUID with inconsistent source path");
    if(old.path==f.sourcePath&&old.uuid!=f.imageUUID)
     return fail("same source path with inconsistent image UUID");
    if(old.uuid==f.imageUUID&&old.path==f.sourcePath&&
       (overlap(old.rva,old.width,r.rva,r.width)||
        overlap(old.file,old.width,r.fileOffset,r.width)))
     return fail("physical RVA or file span conflict: "+old.owner+" vs "+f.featureID);
   }
   sites.push_back({f.imageUUID,f.sourcePath,f.featureID,r.rva,r.fileOffset,r.width});
  }
 }
 error.clear();return true;
}
} // namespace ZNUnifiedBuildPlan
