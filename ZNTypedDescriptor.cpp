#include "ZNTypedDescriptor.hpp"
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <set>

namespace ZNTypedDescriptor {
namespace {
static constexpr size_t kHeader=12, kEntry=48;
static bool integerType(ZNValueCodec::Type t){
 return t!=ZNValueCodec::Type::Float32 && t!=ZNValueCodec::Type::Float64;
}
static void push(std::vector<uint8_t> &v,uint64_t n,size_t width){
 for(size_t i=0;i<width;++i)v.push_back(static_cast<uint8_t>(n>>(i*8)));
}
static uint64_t read(const uint8_t *p,size_t width){
 uint64_t n=0;
 for(size_t i=0;i<width;++i)n|=static_cast<uint64_t>(p[i])<<(i*8);
 return n;
}
static int compareInteger(const std::string &a,const std::string &b){
 const bool negA=!a.empty()&&a[0]=='-',negB=!b.empty()&&b[0]=='-';
 if(negA!=negB)return negA?-1:1;
 const std::string x=negA?a.substr(1):a,y=negB?b.substr(1):b;
 int cmp=x.size()<y.size()?-1:(x.size()>y.size()?1:(x==y?0:(x<y?-1:1)));
 return negA?-cmp:cmp;
}
static int compareValue(ZNValueCodec::Type type,const std::string &a,const std::string &b){
 if(integerType(type))return compareInteger(a,b);
 const double x=std::strtod(a.c_str(),nullptr),y=std::strtod(b.c_str(),nullptr);
 return x<y?-1:(x>y?1:0);
}
static bool positive(ZNValueCodec::Type type,const std::string &value) {
 return compareValue(type,value,"0")>0;
}
static bool extract(ZNValueCodec::Type t,const std::string &text,
                    std::vector<uint8_t> &out,std::string &canonical,std::string &error){
 if(!ZNValueCodec::encode(t,text,out,error))return false;
 if(!ZNValueCodec::decode(t,out.data(),out.size(),canonical,error))return false;
 return true;
}
static bool validate(const Record &r,std::vector<uint8_t> &minimum,std::vector<uint8_t> &maximum,
                     std::vector<uint8_t> &step,std::vector<uint8_t> &def,std::string &error){
 bool slider=r.kind==FeatureKind::Slider;
 if(!slider && r.kind!=FeatureKind::Input){error="unknown feature kind";return false;}
 size_t width=ZNValueCodec::width(r.type);
 if(width==0){error="unknown numeric type";return false;}
 if(!r.rva||r.rva%width||r.rva>UINT64_MAX-width){
  error="RVA is zero, misaligned or overflowing";return false;
 }
 if(r.requiresEnableSwitch!=slider){error="slider requires enable switch; input must not";return false;}
 if(!slider && (!r.step.empty()||!r.defaultValue.empty())){
  error="input cannot contain slider-only fields";return false;
 }
 std::string low,high,increment,initial;
 if(!extract(r.type,r.minimum,minimum,low,error)||
    !extract(r.type,r.maximum,maximum,high,error))return false;
 if(compareValue(r.type,low,high)>=0){error="minimum must be below maximum";return false;}
 if(slider){
  if(!extract(r.type,r.step,step,increment,error)||
     !extract(r.type,r.defaultValue,def,initial,error))return false;
  if(!positive(r.type,increment)){error="step must be positive";return false;}
  if(compareValue(r.type,initial,low)<0||compareValue(r.type,initial,high)>0){
   error="default is outside range";return false;
  }
 }
 return true;
}
static bool disjoint(const std::vector<Record> &records,std::string &error){
 for(size_t i=0;i<records.size();++i){
  const uint64_t a=records[i].rva;
  const uint64_t aEnd=a+ZNValueCodec::width(records[i].type);
  for(size_t j=i+1;j<records.size();++j){
   const uint64_t b=records[j].rva;
   const uint64_t bEnd=b+ZNValueCodec::width(records[j].type);
   if(a<bEnd&&b<aEnd){error="overlapping typed value RVA";return false;}
  }
 }
 return true;
}
} // namespace
bool encode(const std::vector<Record> &records,std::vector<uint8_t> &out,std::string &error){
 if(records.empty()||records.size()>kMaxRecords){error="typed descriptor count outside 1..128";return false;}
 std::vector<uint8_t> candidate;
 candidate.reserve(kHeader+records.size()*kEntry);
 push(candidate,kMagic,4);push(candidate,kVersion,2);
 push(candidate,records.size(),2);push(candidate,kEntry,2);push(candidate,0,2);
 for(const Record &r:records){
  std::vector<uint8_t> low,high,step,def;std::string local;
  if(!validate(r,low,high,step,def,local)){error=local;return false;}
  const size_t width=ZNValueCodec::width(r.type);
  push(candidate,r.rva,8);
  push(candidate,static_cast<uint8_t>(r.kind),1);
  push(candidate,static_cast<uint8_t>(r.type),1);
  push(candidate,r.requiresEnableSwitch?1:0,1);
  push(candidate,width,1);
  push(candidate,0,4);
  for(const std::vector<uint8_t> *p:{&low,&high,&step,&def}){
   candidate.insert(candidate.end(),p->begin(),p->end());
   candidate.insert(candidate.end(),8-p->size(),0);
  }
 }
 if(!disjoint(records,error))return false;
 out.swap(candidate);error.clear();return true;
}
bool decode(const uint8_t *data,size_t len,std::vector<Record> &out,std::string &error){
 if(!data||len<kHeader){error="typed descriptor header truncated";return false;}
 if(read(data,4)!=kMagic||read(data+4,2)!=kVersion||
    read(data+8,2)!=kEntry||read(data+10,2)!=0){
  error="invalid typed descriptor magic/version/layout";return false;
 }
 const size_t count=read(data+6,2);
 if(!count||count>kMaxRecords||len!=kHeader+count*kEntry){
  error="typed descriptor length/count mismatch";return false;
 }
 std::vector<Record> parsed;parsed.reserve(count);
 for(size_t i=0;i<count;++i){
  const uint8_t *p=data+kHeader+i*kEntry;
  Record r{};
  r.rva=read(p,8);
  r.kind=static_cast<FeatureKind>(p[8]);
  r.type=static_cast<ZNValueCodec::Type>(p[9]);
  if(p[10]>1||p[11]!=ZNValueCodec::width(r.type)||read(p+12,4)!=0){
   error="invalid flags/type/width/reserved";return false;
  }
  r.requiresEnableSwitch=p[10]!=0;
  const size_t w=ZNValueCodec::width(r.type);
  if(!w){error="invalid numeric type";return false;}
  std::string *strings[]={&r.minimum,&r.maximum,&r.step,&r.defaultValue};
  for(size_t j=0;j<4;++j){
   const uint8_t *slot=p+16+j*8;
   for(size_t k=w;k<8;++k)if(slot[k]!=0){
    error="nonzero typed-value padding";return false;
   }
   if(r.kind==FeatureKind::Input && j>=2){
    for(size_t k=0;k<w;++k)if(slot[k]!=0){
     error="input contains slider-only field";return false;
    }
    continue;
   }
   if(!ZNValueCodec::decode(r.type,slot,w,*strings[j],error))return false;
  }
  std::vector<uint8_t> low,high,step,def;std::string local;
  if(!validate(r,low,high,step,def,local)){error=local;return false;}
  parsed.push_back(r);
 }
 if(!disjoint(parsed,error))return false;
 out.swap(parsed);error.clear();return true;
}
} // namespace ZNTypedDescriptor
