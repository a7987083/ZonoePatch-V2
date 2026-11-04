#include "ZNMixedDescriptor.hpp"
#include <unordered_set>
#include <utility>
namespace ZNMixedDescriptor {
namespace {
void put(std::vector<uint8_t>&v,uint64_t n,int count){for(int i=0;i<count;i++)v.push_back((uint8_t)(n>>(i*8)));}
uint64_t read(const uint8_t*p,int count){uint64_t n=0;for(int i=0;i<count;i++)n|=uint64_t(p[i])<<(i*8);return n;}
bool valid(const Package &p,std::string &e){
 if(p.features.empty()||p.features.size()>128||p.records.empty()||p.records.size()>128){e="invalid feature/record count";return false;}
 std::unordered_set<std::string> ids;size_t next=0;
 for(const Feature &f:p.features){
  if(f.id.empty()||f.id.size()>128||f.name.empty()||f.name.size()>256||
     f.id.find('\0')!=std::string::npos||f.name.find('\0')!=std::string::npos||
     !ids.insert(f.id).second){e="invalid feature id/name";return false;}
  if(!f.count||f.start!=next||f.count>p.records.size()-next){e="invalid record ownership";return false;}
  for(size_t i=next;i<next+f.count;i++)
   if(p.records[i].kind!=f.kind||p.records[i].type!=f.type){e="record kind/type mismatch";return false;}
  next+=f.count;
 }
 if(next!=p.records.size()){e="orphan records";return false;}
 return true;
}
}
bool encode(const Package &p,std::vector<uint8_t>&out,std::string &e){
 if(!valid(p,e))return false;
 std::vector<uint8_t> typed;
 if(!ZNTypedDescriptor::encode(p.records,typed,e))return false;
 std::vector<uint8_t> candidate;
 put(candidate,kMagic,4);put(candidate,kVersion,2);put(candidate,p.features.size(),2);put(candidate,typed.size(),4);
 for(const Feature &f:p.features){
  put(candidate,f.id.size(),2);put(candidate,f.name.size(),2);
  put(candidate,f.start,2);put(candidate,f.count,2);
  put(candidate,(uint8_t)f.kind,1);put(candidate,(uint8_t)f.type,1);put(candidate,0,2);
  candidate.insert(candidate.end(),f.id.begin(),f.id.end());
  candidate.insert(candidate.end(),f.name.begin(),f.name.end());
 }
 if(candidate.size()>65536||typed.size()>65536-candidate.size()){e="envelope too large";return false;}
 candidate.insert(candidate.end(),typed.begin(),typed.end());out.swap(candidate);e.clear();return true;
}
bool decode(const uint8_t *data,size_t length,Package &out,std::string &e){
 if(!data||length<12||length>65536||read(data,4)!=kMagic||read(data+4,2)!=kVersion){
  e="bad mixed magic/version/size";return false;
 }
 size_t count=read(data+6,2),typedLength=read(data+8,4),pos=12;
 if(!count||count>128||typedLength<12||typedLength>length-pos){e="bad counts";return false;}
 Package parsed;
 for(size_t i=0;i<count;i++){
  if(pos>length||length-pos<12){e="truncated entry";return false;}
  const uint8_t*p=data+pos;size_t idlen=read(p,2),namelen=read(p+2,2);
  if(!idlen||idlen>128||!namelen||namelen>256||read(p+10,2)!=0||
     idlen>length-pos-12||namelen>length-pos-12-idlen){e="invalid entry sizes";return false;}
  Feature f;f.start=read(p+4,2);f.count=read(p+6,2);
  f.kind=(ZNTypedDescriptor::FeatureKind)p[8];f.type=(ZNValueCodec::Type)p[9];
  pos+=12;f.id.assign((const char*)data+pos,idlen);pos+=idlen;
  f.name.assign((const char*)data+pos,namelen);pos+=namelen;
  parsed.features.push_back(std::move(f));
 }
 if(typedLength!=length-pos){e="trailing or truncated typed payload";return false;}
 if(!ZNTypedDescriptor::decode(data+pos,typedLength,parsed.records,e)||!valid(parsed,e))return false;
 out=std::move(parsed);e.clear();return true;
}
}
