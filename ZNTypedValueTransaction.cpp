#include "ZNTypedValueTransaction.hpp"
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <limits>

namespace ZNTypedValue {
namespace {
static int compareInt(const std::string &x,const std::string &y) {
 bool nx=!x.empty()&&x[0]=='-',ny=!y.empty()&&y[0]=='-';
 if(nx!=ny)return nx?-1:1;
 std::string a=nx?x.substr(1):x,b=ny?y.substr(1):y;
 while(a.size()>1&&a[0]=='0')a.erase(0,1);
 while(b.size()>1&&b[0]=='0')b.erase(0,1);
 if(a=="0")nx=false;
 if(b=="0")ny=false;
 if(nx!=ny)return nx?-1:1;
 int r=a.size()<b.size()?-1:(a.size()>b.size()?1:(a==b?0:(a<b?-1:1)));
 return nx?-r:r;
}
static bool isFloat(ZNValueCodec::Type t){
 return t==ZNValueCodec::Type::Float32||t==ZNValueCodec::Type::Float64;
}
static int compareScalar(ZNValueCodec::Type t,const std::string &a,const std::string &b){
 if(!isFloat(t))return compareInt(a,b);
 long double x=strtold(a.c_str(),nullptr),y=strtold(b.c_str(),nullptr);
 return x<y?-1:(x>y?1:0);
}
static bool equals(const std::vector<uint8_t> &a,const std::vector<uint8_t> &b){
 return a.size()==b.size()&&std::equal(a.begin(),a.end(),b.begin());
}
static bool legalTargets(const std::vector<Target> &targets,std::string &error){
 if(targets.empty()||targets.size()>128){error="target count outside 1..128";return false;}
 std::vector<ZNTypedDescriptor::Record> records;records.reserve(targets.size());
 for(const Target &target:targets){
  size_t width=ZNValueCodec::width(target.descriptor.type);
  if(!target.address||!width||target.address%width||
     target.address>UINTPTR_MAX-width||target.descriptor.rva==0){
   error="unmapped, unaligned or overflowing typed target";return false;
  }
  records.push_back(target.descriptor);
 }
 std::vector<uint8_t> encoded;
 if(!ZNTypedDescriptor::encode(records,encoded,error))return false;
 for(size_t i=0;i<targets.size();++i){
  uintptr_t a=targets[i].address;
  size_t n=ZNValueCodec::width(targets[i].descriptor.type);
  for(size_t j=i+1;j<targets.size();++j){
   uintptr_t b=targets[j].address;
   size_t m=ZNValueCodec::width(targets[j].descriptor.type);
   if(a<b+m && b<a+n){error="overlapping runtime addresses";return false;}
  }
 }
 return true;
}
} // namespace
Transaction::Transaction(Backend &backend):backend_(backend){}
bool Transaction::rollback(const std::vector<Snapshot> &rows,
                           const std::vector<size_t> &indices,
                           bool undoToOriginal,std::string &error){
 bool restored=true;
 for(auto it=indices.rbegin();it!=indices.rend();++it){
  const Snapshot &row=rows[*it];
  const std::vector<uint8_t> &expected=undoToOriginal?row.original:row.applied;
  std::string cause;bool wrote=backend_.write(row.address,expected.data(),expected.size(),cause);
  std::vector<uint8_t> actual(expected.size());
  bool checked=backend_.read(row.address,actual.data(),actual.size(),cause)&&equals(actual,expected);
  if(!wrote||!checked){
   restored=false;
   error+=" | rollback failed at address "+std::to_string(row.address)+": "+cause;
  }
 }
 if(!restored){locked_=true;lastDiagnostic_=error;}
 return restored;
}
bool Transaction::commit(const std::vector<Target> &targets,
                         const std::string &decimal,std::string &error){
 if(locked_){error="transaction locked after failed rollback";return false;}
 if(enabled_){error="already enabled; restore before recommitting";return false;}
 if(!legalTargets(targets,error))return false;
 std::vector<Snapshot> staged;staged.reserve(targets.size());
 for(const Target &t:targets){
  const auto type=t.descriptor.type;
  std::vector<uint8_t> payload;std::string canonical,valueMin,valueMax;
  if(!ZNValueCodec::encode(type,decimal,payload,error)||
     !ZNValueCodec::decode(type,payload.data(),payload.size(),canonical,error))
   return false;
  std::vector<uint8_t> lo,hi;
  if(!ZNValueCodec::encode(type,t.descriptor.minimum,lo,error)||
     !ZNValueCodec::encode(type,t.descriptor.maximum,hi,error)||
     !ZNValueCodec::decode(type,lo.data(),lo.size(),valueMin,error)||
     !ZNValueCodec::decode(type,hi.data(),hi.size(),valueMax,error))return false;
  if(compareScalar(type,canonical,valueMin)<0||compareScalar(type,canonical,valueMax)>0){
   error="value outside configured numeric range";return false;
  }
  std::vector<uint8_t> original(payload.size());
  if(!backend_.read(t.address,original.data(),original.size(),error))return false;
  staged.push_back({t.address,std::move(original),std::move(payload)});
 }
 std::vector<size_t> written;
 for(size_t i=0;i<staged.size();++i){
  Snapshot &row=staged[i];
  // Recheck each original immediately before mutation: detect concurrent writers.
  std::vector<uint8_t> check(row.original.size());
  if(!backend_.read(row.address,check.data(),check.size(),error)||
     !equals(check,row.original)){
   error="original value changed after preflight";
   if(!written.empty())rollback(staged,written,true,error);
   return false;
  }
  if(equals(row.original,row.applied))continue;
  std::string why;
  bool wrote=backend_.write(row.address,row.applied.data(),row.applied.size(),why);
  std::vector<uint8_t> readBack(row.applied.size());
  bool verified=backend_.read(row.address,readBack.data(),readBack.size(),why)&&
                equals(readBack,row.applied);
  written.push_back(i); // writes can mutate bytes even when reporting failure
  if(!wrote||!verified){
   error="commit failed/readback mismatch: "+why;
   rollback(staged,written,true,error);return false;
  }
 }
 snapshots_=std::move(staged);activeTargets_=targets;enabled_=true;
 lastDiagnostic_="typed value commit verified";error.clear();return true;
}
bool Transaction::update(const std::vector<Target> &targets,
                         const std::string &decimal,std::string &error){
 if(locked_){error="transaction locked after failed rollback";return false;}
 if(!enabled_||snapshots_.empty()||targets.size()!=snapshots_.size()||
    targets.size()!=activeTargets_.size()){
  error="active transaction target count changed or is not enabled";return false;
 }
 if(!legalTargets(targets,error))return false;
 std::vector<ZNTypedDescriptor::Record> oldRecords,newRecords;
 oldRecords.reserve(targets.size());newRecords.reserve(targets.size());
 for(size_t i=0;i<targets.size();++i){
  if(targets[i].address!=activeTargets_[i].address){
   error="active transaction address changed";return false;
  }
  oldRecords.push_back(activeTargets_[i].descriptor);
  newRecords.push_back(targets[i].descriptor);
 }
 std::vector<uint8_t> originalDescriptor,proposedDescriptor;
 if(!ZNTypedDescriptor::encode(oldRecords,originalDescriptor,error)||
    !ZNTypedDescriptor::encode(newRecords,proposedDescriptor,error)||
    originalDescriptor!=proposedDescriptor){
  if(error.empty())error="active transaction descriptor changed";return false;
 }
 std::vector<std::vector<uint8_t>> payloads;
 payloads.reserve(targets.size());
 for(const Target &target:targets){
  auto type=target.descriptor.type;
  std::vector<uint8_t> value,lo,hi;
  std::string canonical,minValue,maxValue;
  if(!ZNValueCodec::encode(type,decimal,value,error)||
     !ZNValueCodec::decode(type,value.data(),value.size(),canonical,error)||
     !ZNValueCodec::encode(type,target.descriptor.minimum,lo,error)||
     !ZNValueCodec::encode(type,target.descriptor.maximum,hi,error)||
     !ZNValueCodec::decode(type,lo.data(),lo.size(),minValue,error)||
     !ZNValueCodec::decode(type,hi.data(),hi.size(),maxValue,error))return false;
  if(compareScalar(type,canonical,minValue)<0||compareScalar(type,canonical,maxValue)>0){
   error="updated value outside configured range";return false;
  }
  payloads.push_back(std::move(value));
 }
 // Read all active values before the first mutation. Never overwrite an external writer.
 for(const Snapshot &row:snapshots_){
  std::vector<uint8_t> observed(row.applied.size());
  if(!backend_.read(row.address,observed.data(),observed.size(),error)||
     !equals(observed,row.applied)){
   error="active numeric bytes changed outside transaction";return false;
  }
 }
 std::vector<size_t> written;
 for(size_t i=0;i<snapshots_.size();++i){
  const Snapshot &row=snapshots_[i];
  if(equals(payloads[i],row.applied))continue;
  // Recheck immediately before each write, including concurrent mutations
  // occurring after the global preflight.
  std::vector<uint8_t> observed(row.applied.size());
  if(!backend_.read(row.address,observed.data(),observed.size(),error)||
     !equals(observed,row.applied)){
   error="active numeric bytes changed during update";
   if(!written.empty())rollback(snapshots_,written,false,error);
   return false;
  }
  std::string cause;
  bool ok=backend_.write(row.address,payloads[i].data(),payloads[i].size(),cause);
  written.push_back(i); // backend may modify bytes despite reporting failure
  std::vector<uint8_t> observedAfter(payloads[i].size());
  bool verified=backend_.read(row.address,observedAfter.data(),observedAfter.size(),cause)&&
                equals(observedAfter,payloads[i]);
  if(!ok||!verified){
   error="active update write/readback failure: "+cause;
   rollback(snapshots_,written,false,error);return false;
  }
 }
 for(size_t i=0;i<snapshots_.size();++i)
  snapshots_[i].applied=std::move(payloads[i]);
 lastDiagnostic_="active numeric update verified";error.clear();return true;
}
bool Transaction::restore(std::string &error){
 if(locked_){error="transaction locked after failed rollback";return false;}
 if(!enabled_||snapshots_.empty()){error="no active numeric transaction";return false;}
 std::vector<size_t> written;
 // Verify complete applied state before first restore write.
 for(const Snapshot &row:snapshots_){
  std::vector<uint8_t> check(row.applied.size());
  if(!backend_.read(row.address,check.data(),check.size(),error)||
     !equals(check,row.applied)){
   error="applied bytes changed externally; refusing restore";return false;
  }
 }
 for(size_t i=0;i<snapshots_.size();++i){
  const Snapshot &row=snapshots_[i];
  if(equals(row.original,row.applied))continue;
  std::string why;
  bool wrote=backend_.write(row.address,row.original.data(),row.original.size(),why);
  std::vector<uint8_t> check(row.original.size());
  bool verified=backend_.read(row.address,check.data(),check.size(),why)&&
                equals(check,row.original);
  written.push_back(i);
  if(!wrote||!verified){
   error="restore failed/readback mismatch: "+why;
   rollback(snapshots_,written,false,error);return false;
  }
 }
 snapshots_.clear();activeTargets_.clear();enabled_=false;lastDiagnostic_="original values restored";error.clear();return true;
}
} // namespace ZNTypedValue
