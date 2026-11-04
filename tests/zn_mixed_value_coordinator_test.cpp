#include "../ZNMixedValueCoordinator.hpp"
#include <cstdio>
#include <cstring>
#include <map>
#include <vector>
using namespace ZNMixedValue;
using namespace ZNTypedValue;
using ZNValueCodec::Type;
static int failures=0;
static void check(bool b,const char *n){if(!b){++failures;fprintf(stderr,"FAIL: %s\n",n);}}
struct State {
 std::map<uintptr_t,std::vector<uint8_t>> memory;
 int writes=0,failAt=0;
 bool failRollback=false;
};
class Fake:public Backend {
public:
 explicit Fake(State &s):state(s){}
 bool read(uintptr_t addr,uint8_t*out,size_t n,std::string &e)override{
  auto i=state.memory.find(addr);
  if(i==state.memory.end()||i->second.size()!=n){e="unknown span";return false;}
  std::memcpy(out,i->second.data(),n);e.clear();return true;
 }
 bool write(uintptr_t addr,const uint8_t*src,size_t n,std::string &e)override{
  ++state.writes;
  if(state.failRollback && src[0]==1){e="rollback denied";return false;}
  auto i=state.memory.find(addr);
  if(i==state.memory.end()||i->second.size()!=n){e="unknown write";return false;}
  i->second.assign(src,src+n);
  if(state.failAt==state.writes){e="write failed after mutation";return false;}
  e.clear();return true;
 }
 State &state;
};
static Target cell(uintptr_t address,uint64_t rva,Type type){
 return {address,{ZNTypedDescriptor::FeatureKind::Input,type,rva,false,"0","100","",""}};
}
static std::unique_ptr<Backend> backend(State&s){return std::make_unique<Fake>(s);}
int main(){
 std::string e;
 State state;state.memory[0x1000]={1,0,0,0};state.memory[0x2000]={2,0,0,0};
 Coordinator c;
 check(c.apply("uuid-a","feature-a",backend(state),{cell(0x1000,0x1000,Type::Int32)},"41",e),"first apply");
 check(c.apply("uuid-a","feature-b",backend(state),{cell(0x2000,0x2000,Type::Int32)},"42",e),"second independent feature same image");
 check(c.sessionCount()==2 && c.active("uuid-a","feature-a")&&c.active("uuid-a","feature-b"),"two independent owners");
 check(!c.apply("uuid-a","feature-c",backend(state),{cell(0x1000,0x1000,Type::Int32)},"43",e),"overlapping feature denied");
 check(!c.apply("uuid-a","feature-a",backend(state),{cell(0x3000,0x3000,Type::Int32)},"43",e),"duplicate identity denied");
 check(c.restore("uuid-a","feature-a",e),"restore A independently");
 check(state.memory[0x1000][0]==1&&state.memory[0x2000][0]==42&&c.active("uuid-a","feature-b"),"B preserved during A restore");
 check(c.restore("uuid-a","feature-b",e)&&c.sessionCount()==0,"restore B");
 State partial;partial.memory[0x4000]={1};partial.memory[0x5000]={1};
 partial.failAt=2;Coordinator f;
 check(!f.apply("uuid-b","partial",backend(partial),
    {cell(0x4000,0x4000,Type::Int8),cell(0x5000,0x5000,Type::Int8)},"50",e),"partial commit refused");
 check(!f.recoveryFailed()&&f.sessionCount()==0&&partial.memory[0x4000][0]==1&&partial.memory[0x5000][0]==1,"rollback verified and reservations released");
 State broken;broken.memory[0x6000]={1};broken.memory[0x7000]={1};
 broken.failAt=2;broken.failRollback=true;Coordinator locked;
 check(!locked.apply("uuid-c","broken",backend(broken),
    {cell(0x6000,0x6000,Type::Int8),cell(0x7000,0x7000,Type::Int8)},"50",e),"failed rollback detected");
 check(locked.recoveryFailed()&&locked.sessionCount()==1,"recovery latch retains address ownership");
 check(!locked.apply("uuid-c","next",backend(broken),{cell(0x6000,0x6000,Type::Int8)},"22",e),"global fail-closed lock");
 check(!locked.restore("uuid-c","broken",e),"automatic restore prohibited after recovery failure");
 check(!c.restore("uuid-a","missing",e),"missing owner cannot restore");
 printf("P10.6.3 mixed ownership: %s (%d failures)\n",failures?"FAIL":"PASS",failures);
 return failures?1:0;
}
