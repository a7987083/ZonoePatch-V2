#include "../ZNCodeCellBinding.hpp"
#include <cstdio>
#include <string>
using namespace ZNCodeCellBinding;
static int failures=0;
static void test(bool ok,const char *name){if(!ok){++failures;fprintf(stderr,"FAIL %s\n",name);}}
static void roundTrip(Package input){
 std::vector<uint8_t>bytes;std::string error;Package out;
 test(encode(input,bytes,error),"ZCB1 encode");
 test(decode(bytes.data(),bytes.size(),out,error),"ZCB1 decode");
 test(out.imageUUID==input.imageUUID&&out.bindings.size()==2&&
      out.bindings[0].featureID=="slider"&&out.bindings[1].cellRVA==0x5008,
      "exact UUID/ID/cell binding roundtrip");
 const std::vector<P9CodeEntry>p9={{1,0x1000,false},{2,0x1100,true},{3,0x1120,true}};
 const std::vector<NumericCell>numeric={{"slider",8,0x5000},{"input",4,0x5008}};
 test(validateOwnership(out,p9,numeric,error),"P9/ZNM2 ownership exact");
 auto wrongP9=p9;wrongP9[1].valueCell=false;
 test(!validateOwnership(out,wrongP9,numeric,error),"reject missing value cell marker");
 auto wrongRVA=p9;wrongRVA[2].siteRVA=0x1130;
 test(!validateOwnership(out,wrongRVA,numeric,error),"reject wrong P9 site");
 auto wrongNumeric=numeric;wrongNumeric[1].cellRVA=0x6000;
 test(!validateOwnership(out,p9,wrongNumeric,error),"reject ZNM2 wrong cell");
 auto missing=numeric;missing.pop_back();
 test(!validateOwnership(out,p9,missing,error),"reject missing ZNM2 owner");
 std::vector<uint8_t>bad=bytes;bad[0]^=0x1;
 test(!decode(bad.data(),bad.size(),out,error),"reject foreign magic");
 bad=bytes;bad[44]=1;
 test(!decode(bad.data(),bad.size(),out,error),"reject reserved header");
 bad=bytes;bad.push_back(0);
 test(!decode(bad.data(),bad.size(),out,error),"reject trailing data");
 bad=bytes;bad.resize(bad.size()-1);
 test(!decode(bad.data(),bad.size(),out,error),"reject truncated data");
 auto duplicate=input;duplicate.bindings[1].patchID=2;
 test(!encode(duplicate,bytes,error),"reject duplicate P9 patchID");
 duplicate=input;duplicate.bindings[1].cellRVA=0x5000;
 test(!encode(duplicate,bytes,error),"reject shared RW cell");
 duplicate=input;duplicate.bindings[1].sourceRVA=0x1100;
 test(!encode(duplicate,bytes,error),"reject overlapping source");
 duplicate=input;duplicate.bindings[1].featureID="slider";
 test(!encode(duplicate,bytes,error),"reject duplicate featureID");
 duplicate=input;duplicate.imageUUID="uuid";
 test(!encode(duplicate,bytes,error),"reject noncanonical LC_UUID");
}
int main(){
 Package p;p.imageUUID="01234567-89AB-CDEF-0123-456789ABCDEF";
 p.bindings={{"slider",2,0x1100,0x5000,8,1},
             {"input",3,0x1120,0x5008,4,2}};
 roundTrip(p);
 std::printf("P10.7.5 ZCB1 code-cell ownership: %s (%d failures)\n",failures?"FAIL":"PASS",failures);
 return failures?1:0;
}
