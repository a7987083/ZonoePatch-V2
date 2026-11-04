#include "ZNMixedValueCoordinator.hpp"
#include <utility>
namespace ZNMixedValue {
namespace {
bool intersects(uintptr_t a,size_t n,uintptr_t b,size_t m) {
 return a<b+m && b<a+n;
}
}
bool Coordinator::apply(const std::string &imageID,const std::string &featureID,
 std::unique_ptr<ZNTypedValue::Backend> backend,
 const std::vector<ZNTypedValue::Target> &targets,const std::string &decimal,std::string &error){
 if(locked_){error="recovery failure latched; all numeric writes blocked";return false;}
 if(imageID.empty()||featureID.empty()||!backend||targets.empty()||targets.size()>128){
  error="missing trusted image/feature identity, backend or targets";return false;
 }
 for(Session &s:sessions_)
  if(s.image==imageID&&s.feature==featureID){
   if(targets.size()!=s.spans.size()){
    error="active feature target count changed";return false;
   }
   for(size_t i=0;i<targets.size();i++)
    if(targets[i].address!=s.spans[i].start||
       ZNValueCodec::width(targets[i].descriptor.type)!=s.spans[i].size){
     error="active feature target address or width changed";return false;
    }
   const bool updated=s.transaction->update(targets,decimal,error);
   if(s.transaction->recoveryFailed())locked_=true;
   return updated;
  }
 std::vector<Span> spans;
 for(const auto &t:targets){
  size_t width=ZNValueCodec::width(t.descriptor.type);
  if(!width||!t.address||t.address>UINTPTR_MAX-width||t.address%width){
   error="untrusted or overflowing runtime span";return false;
  }
  for(const Span &v:spans)
   if(intersects(t.address,width,v.start,v.size)){error="overlap within feature";return false;}
  for(const Session &s:sessions_)for(const Span &v:s.spans)
   if(intersects(t.address,width,v.start,v.size)){
    error="numeric address already owned by another feature";return false;
   }
  spans.push_back({t.address,width});
 }
 Session candidate;
 candidate.image=imageID;candidate.feature=featureID;
 candidate.spans=std::move(spans);candidate.backend=std::move(backend);
 candidate.transaction=std::make_unique<ZNTypedValue::Transaction>(*candidate.backend);
 bool ok=candidate.transaction->commit(targets,decimal,error);
 if(ok||candidate.transaction->recoveryFailed()){
  if(candidate.transaction->recoveryFailed())locked_=true;
  sessions_.push_back(std::move(candidate));
 }
 return ok;
}
bool Coordinator::restore(const std::string &imageID,const std::string &featureID,std::string &error){
 if(locked_){error="recovery failure latched; no automatic restore";return false;}
 for(size_t i=0;i<sessions_.size();++i)if(sessions_[i].image==imageID&&sessions_[i].feature==featureID){
  Session &s=sessions_[i];
  if(!s.transaction->restore(error)){
   if(s.transaction->recoveryFailed())locked_=true;
   return false;
  }
  sessions_.erase(sessions_.begin()+i);
  error.clear();return true;
 }
 error="feature has no active transaction";return false;
}
bool Coordinator::active(const std::string &imageID,const std::string &featureID)const{
 for(const Session &s:sessions_)if(s.image==imageID&&s.feature==featureID)
  return s.transaction->active();
 return false;
}
bool Coordinator::recoveryFailed()const {return locked_;}
size_t Coordinator::sessionCount()const{return sessions_.size();}
} // namespace ZNMixedValue
