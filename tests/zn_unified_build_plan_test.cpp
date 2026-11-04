#include "../ZNUnifiedBuildPlan.hpp"
#include <cstdio>
#include <string>
#include <utility>
using namespace ZNUnifiedBuildPlan;
static int failures=0;
static void check(bool b,const char *name) {
 if(!b){fprintf(stderr,"FAIL: %s\n",name);++failures;}
}
static Feature feature(std::string id,Control control,RuleKind kind,uint64_t rva,uint64_t file,uint64_t width) {
 Feature f={std::move(id),"display name","group",control,"uuid-a","/tmp/a",
         {{"rule-a",kind,rva,file,width}},{}};
 if(control!=Control::Toggle) {
  f.numeric.valueType=width==8?9:(width==2?2:(width==1?0:4));
  f.numeric.minimum="0";f.numeric.maximum="100";
  if(control==Control::Slider) {
   f.numeric.step="1";f.numeric.defaultValue="10";f.numeric.requiresEnableSwitch=true;
  }
 }
 return f;
}
static void expected(bool shouldPass,Plan p,const char *name) {
 std::string error;bool ok=validate(p,error);check(ok==shouldPass,name);
 if(ok!=shouldPass)fprintf(stderr,"  diagnostic=%s\n",error.c_str());
}
int main() {
 auto toggle=feature("toggle-id",Control::Toggle,RuleKind::PatchBytes,0x1000,0x2000,4);
 auto input=feature("input-id",Control::Input,RuleKind::TypedValue,0x1004,0x2004,4);
 auto slider=feature("slider-id",Control::Slider,RuleKind::TypedValue,0x1008,0x2008,8);
 expected(true,{kSchemaVersion,{toggle,input,slider}},"disjoint mixed features");
 auto renamed=input;renamed.name="renamed";
 expected(true,{kSchemaVersion,{toggle,renamed,slider}},"display name independent from ID");
 expected(false,{2,{toggle}},"unknown schema version");
 expected(false,{kSchemaVersion,{}},"empty plan");
 auto duplicate=input;duplicate.featureID=toggle.featureID;
 expected(false,{kSchemaVersion,{toggle,duplicate}},"duplicate feature ID");
 auto shared=slider;shared.rules[0].rva=0x1004;shared.rules[0].fileOffset=0x3000;
 expected(false,{kSchemaVersion,{input,shared}},"different-width RVA overlap");
 shared=slider;shared.rules[0].rva=0x3000;shared.rules[0].fileOffset=0x2000;
 expected(false,{kSchemaVersion,{toggle,shared}},"file range overlap");
 auto adjacent=slider;adjacent.rules[0].rva=0x1010;adjacent.rules[0].fileOffset=0x2010;
 expected(true,{kSchemaVersion,{toggle,input,adjacent}},"adjacent spans");
 auto mismatch=input;mismatch.rules[0].kind=RuleKind::PatchBytes;
 expected(false,{kSchemaVersion,{mismatch}},"control/rule mismatch");
 auto overflow=input;overflow.rules[0].rva=UINT64_MAX-1;
 expected(false,{kSchemaVersion,{overflow}},"RVA overflow");
 auto unaligned=input;unaligned.rules[0].rva=0x1002;
 expected(false,{kSchemaVersion,{unaligned}},"typed alignment");
 auto invalid=slider;invalid.rules[0].width=3;
 expected(false,{kSchemaVersion,{invalid}},"invalid typed width");
 auto otherImage=slider;otherImage.imageUUID="uuid-b";otherImage.sourcePath="/tmp/b";
 otherImage.rules[0].rva=0x1000;otherImage.rules[0].fileOffset=0x2000;
 expected(true,{kSchemaVersion,{toggle,otherImage}},"identical RVA in different image");
 auto badImage=otherImage;badImage.imageUUID="uuid-a";
 expected(false,{kSchemaVersion,{toggle,badImage}},"inconsistent image UUID/path");
 auto wrongType=input;wrongType.numeric.valueType=9;
 expected(false,{kSchemaVersion,{wrongType}},"typed width vs value type");
 auto missing=input;missing.numeric.minimum.clear();
 expected(false,{kSchemaVersion,{missing}},"numeric range mandatory");
 auto toggleNumeric=toggle;toggleNumeric.numeric.valueType=4;
 expected(false,{kSchemaVersion,{toggleNumeric}},"toggle cannot carry numeric parameters");
 auto more=input;more.featureID="other";more.rules[0].rva=0x2000;more.rules[0].fileOffset=0x3000;
 expected(true,{kSchemaVersion,{input,more}},"rule ID scoped to feature");
 auto many=toggle;many.rules.clear();
 for(int i=0;i<129;i++)many.rules.push_back({"r"+std::to_string(i),RuleKind::PatchBytes,0x1000+uint64_t(i)*4,0x2000+uint64_t(i)*4,4});
 expected(false,{kSchemaVersion,{many}},"total rule count limit");
 auto repeated=input;repeated.rules.push_back(repeated.rules[0]);
 expected(false,{kSchemaVersion,{repeated}},"duplicate rule ID");
 printf("P10.6.1 unified build-plan: %s (%d failures)\n",failures?"FAIL":"PASS",failures);
 return failures?1:0;
}
