#include "ZNCodeCellBinding.hpp"
#include <algorithm>
#include <unordered_set>
#include <cstdio>
namespace ZNCodeCellBinding {
namespace {
void put(std::vector<uint8_t>&v,uint64_t n,unsigned count){
 for(unsigned i=0;i<count;i++)v.push_back(uint8_t(n>>(i*8)));
}
uint64_t get(const uint8_t*p,unsigned count){
 uint64_t x=0;for(unsigned i=0;i<count;i++)x|=uint64_t(p[i])<<(8*i);
 return x;
}
uint8_t width(uint8_t t){
 switch(t){case 4:case 5:case 8:return 4;case 6:case 7:case 9:return 8;default:return 0;}
}
bool validUUID(const std::string&s){
 if(s.size()!=36)return false;
 for(size_t i=0;i<s.size();i++){
  if(i==8||i==13||i==18||i==23){if(s[i]!='-')return false;}
  else if(!((s[i]>='0'&&s[i]<='9')||(s[i]>='A'&&s[i]<='F')))return false;
 }
 return true;
}
bool valid(const Package&p,std::string&e){
 if(!validUUID(p.imageUUID)){e="LC_UUID string must be uppercase canonical";return false;}
 if(p.bindings.empty()||p.bindings.size()>kMaxBindings){e="code-cell binding count outside 1..128";return false;}
 std::unordered_set<uint32_t>patches;
 std::unordered_set<uint64_t>cells;
 for(const auto&b:p.bindings){
  if(b.featureID.empty()||b.featureID.size()>128||
     b.featureID.find('\0')!=std::string::npos||
     !b.patchID||!patches.insert(b.patchID).second||
     !b.sourceRVA||(b.sourceRVA&3u)||!b.cellRVA||
     !width(b.numericType)||(b.cellRVA%width(b.numericType))||
     !cells.insert(b.cellRVA).second||
     b.originalWords<1||b.originalWords>4||
     b.sourceRVA>UINT64_MAX-uint64_t(b.originalWords)*4){
   e="invalid or duplicate Feature ID/P9 patch ID/cell/width";return false;
  }
 }
 for(size_t i=0;i<p.bindings.size();i++){
  auto&a=p.bindings[i];
  for(size_t j=0;j<i;j++){
   auto&b=p.bindings[j];
   const uint64_t n=uint64_t(a.originalWords)*4,m=uint64_t(b.originalWords)*4;
   if(a.sourceRVA<b.sourceRVA+m&&b.sourceRVA<a.sourceRVA+n){
    e="overlapping original instruction windows";return false;
   }
   const uint64_t aw=width(a.numericType),bw=width(b.numericType);
   if(a.cellRVA<b.cellRVA+bw&&b.cellRVA<a.cellRVA+aw){
    e="overlapping numeric cell spans";return false;
   }
  }
 }
 return true;
}
}
bool encode(const Package&p,std::vector<uint8_t>&out,std::string&e){
 if(!valid(p,e))return false;
 std::vector<uint8_t>v;
 v.reserve(48+p.bindings.size()*32);
 put(v,kMagic,4);put(v,kVersion,2);put(v,p.bindings.size(),2);
 v.insert(v.end(),p.imageUUID.begin(),p.imageUUID.end());put(v,0,4);
 for(const auto&b:p.bindings){
  put(v,b.patchID,4);put(v,b.sourceRVA,8);put(v,b.cellRVA,8);
  put(v,b.numericType,1);put(v,b.originalWords,1);
  put(v,b.featureID.size(),2);v.insert(v.end(),b.featureID.begin(),b.featureID.end());
 }
 if(v.size()>65536){e="ZCB1 size exceeds 64KiB";return false;}
 out.swap(v);e.clear();return true;
}
bool decode(const uint8_t*bytes,size_t length,Package&out,std::string&e){
 if(!bytes||length<48||length>65536||get(bytes,4)!=kMagic||
    get(bytes+4,2)!=kVersion||get(bytes+44,4)!=0){
  e="invalid ZCB1 magic/version/header";return false;
 }
 const size_t count=get(bytes+6,2);
 if(!count||count>kMaxBindings){e="invalid ZCB1 binding count";return false;}
 Package p;p.imageUUID.assign((const char*)bytes+8,36);
 size_t offset=48;
 for(size_t i=0;i<count;i++){
  if(offset>length||length-offset<24){e="truncated ZCB1 binding";return false;}
  const uint8_t *b=bytes+offset;
  const size_t idLength=get(b+22,2);
  if(!idLength||idLength>128||idLength>length-offset-24){
   e="invalid ZCB1 feature ID length";return false;
  }
  Binding value;
  value.patchID=(uint32_t)get(b,4);value.sourceRVA=get(b+4,8);
  value.cellRVA=get(b+12,8);value.numericType=b[20];value.originalWords=b[21];
  value.featureID.assign((const char*)b+24,idLength);
  p.bindings.push_back(std::move(value));offset+=24+idLength;
 }
 if(offset!=length){e="trailing ZCB1 bytes";return false;}
 if(!valid(p,e))return false;
 out=std::move(p);e.clear();return true;
}
bool validateOwnership(const Package&p,
 const std::vector<P9CodeEntry>&p9,
 const std::vector<NumericCell>&numerics,std::string&e){
 if(!valid(p,e))return false;
 if(p9.empty()||numerics.empty()){e="missing P9/ZNM2 catalog";return false;}
 std::unordered_set<uint32_t>usedP9;
 for(const auto&b:p.bindings){
  size_t p9Found=0,numericFound=0;
  for(const auto&s:p9){
   if(s.patchID==b.patchID){
    ++p9Found;
    if(s.siteRVA!=b.sourceRVA||!s.valueCell){
     e="P9 source or Value Cell marker mismatches ZCB1";return false;
    }
   }
  }
  for(const auto&n:numerics)if(n.featureID==b.featureID&&n.cellRVA==b.cellRVA){
   ++numericFound;
   if(n.numericType!=b.numericType){
    e="ZNM2 numeric type/cell mismatches ZCB1";return false;
   }
  }
  if(p9Found!=1||numericFound!=1||!usedP9.insert(b.patchID).second){
   e="ZCB1 binding lacks a unique P9/ZNM2 owner";return false;
  }
 }
 e.clear();return true;
}
}
