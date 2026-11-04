#include "ZNUnifiedBuildPlan.hpp"
#include <unordered_set>

namespace ZNUnifiedBuildPlan {
namespace {
struct Site {std::string uuid,path,owner;uint64_t rva,file,width;};
bool overlap(uint64_t a,uint64_t n,uint64_t b,uint64_t m) {
 return a<b+m && b<a+n;
}
uint64_t numericWidth(uint8_t type) {
 switch(type) {
  case 0:case 1:return 1;
  case 2:case 3:return 2;
  case 4:case 5:case 8:return 4;
  case 6:case 7:case 9:return 8;
  default:return 0;
 }
}
}
bool validate(const Plan &plan,std::string &error) {
 auto fail=[&](const std::string &s){error=s;return false;};
 if(plan.version!=kSchemaVersion)return fail("unknown unified plan version");
 if(plan.features.empty()||plan.features.size()>kMaxFeatures)
  return fail("feature count outside 1..128");
 std::unordered_set<std::string> ids;
 std::vector<Site> sites;
 size_t totalRules=0;
 for(const Feature &f:plan.features) {
  if(f.featureID.empty()||f.name.empty()||f.imageUUID.empty()||f.sourcePath.empty())
   return fail("missing feature or image identity");
  if(!ids.insert(f.featureID).second)return fail("duplicate feature ID");
  if(f.control!=Control::Toggle&&f.control!=Control::Input&&f.control!=Control::Slider)
   return fail("unsupported feature control");
  if(f.rules.empty()||f.rules.size()>kMaxRules)return fail("rules outside 1..128 per feature");
  if(f.rules.size()>kMaxRules-totalRules)return fail("total rules exceed 128");
  totalRules+=f.rules.size();
  const bool isNumeric=f.control!=Control::Toggle;
  const uint64_t typedWidth=numericWidth(f.numeric.valueType);
  if(isNumeric) {
   if(!typedWidth||f.numeric.minimum.empty()||f.numeric.maximum.empty()||
      (f.control==Control::Slider &&
       (!f.numeric.requiresEnableSwitch||f.numeric.step.empty()||f.numeric.defaultValue.empty()))||
      (f.control==Control::Input &&
       (f.numeric.requiresEnableSwitch||!f.numeric.step.empty()||!f.numeric.defaultValue.empty())))
     return fail("missing or invalid typed numeric parameters");
  } else if(f.numeric.valueType!=255||!f.numeric.minimum.empty()||
            !f.numeric.maximum.empty()||!f.numeric.step.empty()||
            !f.numeric.defaultValue.empty()||f.numeric.requiresEnableSwitch)
    return fail("toggle carries unexpected numeric parameters");
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
      (r.width!=typedWidth||r.rva%typedWidth||r.fileOffset%typedWidth))
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
