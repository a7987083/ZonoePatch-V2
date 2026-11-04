#include "../ZNTypedValueTransaction.hpp"
#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <vector>
using namespace ZNTypedValue;
using namespace ZNTypedDescriptor;
using ZNValueCodec::Type;
static int fails=0;
static void check(bool pass,const char *name){if(!pass){++fails;std::fprintf(stderr,"FAIL: %s\n",name);}}
class Fake final:public Backend {
public:
 std::map<uintptr_t,std::vector<uint8_t>> memory;
 int writes=0, failWrite=0, corruptWrite=0, failRollback=0;
 bool read(uintptr_t p,uint8_t *out,size_t n,std::string &error)override{
  auto it=memory.find(p);
  if(it==memory.end()||it->second.size()!=n){error="not mapped";return false;}
  std::memcpy(out,it->second.data(),n);return true;
 }
 bool write(uintptr_t p,const uint8_t *b,size_t n,std::string &error)override{
  ++writes;
  auto it=memory.find(p);
  if(it==memory.end()||it->second.size()!=n){error="not mapped";return false;}
  bool reverting=b[0]==1||b[0]==2;
  if(failRollback&&reverting){error="rollback denied";return false;}
  it->second.assign(b,b+n);
  if(failWrite&&writes==failWrite){error="write reported failure after mutation";return false;}
  if(corruptWrite&&writes==corruptWrite)it->second[0]^=0xff;
  return true;
 }
};
static Target target(uintptr_t address,uint64_t rva,Type type,
                     const char *minimum,const char *maximum){
 return {address,{FeatureKind::Input,type,rva,false,minimum,maximum,"",""}};
}
static Target slider(uintptr_t address,uint64_t rva,Type type){
 return {address,{FeatureKind::Slider,type,rva,true,"0","10","1","3"}};
}
static void basic(){
 Fake f;f.memory[0x1000]={1,0,0,0};Transaction t(f);std::string e;
 check(t.commit({target(0x1000,0x1000,Type::UInt32,"0","100")},"42",e),"commit UInt32");
 check(t.active()&&f.memory[0x1000][0]==42,"commit changes real bytes");
 check(!t.commit({target(0x1000,0x1000,Type::UInt32,"0","100")},"51",e),"reject double commit");
 check(t.update({target(0x1000,0x1000,Type::UInt32,"0","100")},"51",e),"update enabled scalar");
 check(f.memory[0x1000][0]==51,"update writes new value");
 check(!t.update({target(0x1000,0x1000,Type::UInt32,"0","100")},"101",e),
       "out-of-range update rejected");
 check(f.memory[0x1000][0]==51,"failed range update leaves prior value");
 check(!t.update({target(0x1000,0x1000,Type::UInt32,"0","90")},"60",e),
       "changed descriptor rejected");
 check(!t.update({target(0x2000,0x2000,Type::UInt32,"0","100")},"60",e),
       "changed target address rejected");
 check(t.restore(e),"restore UInt32");check(!t.active()&&f.memory[0x1000][0]==1,"restore original");
 check(!t.restore(e),"reject double restore");
 check(!t.commit({target(0x1000,0x1000,Type::UInt32,"0","100")},"101",e),"out of range");
 check(!t.active()&&f.memory[0x1000][0]==1,"reject before write");
}
static void exact64(){
 Fake f;f.memory[0x2000]=std::vector<uint8_t>(8,0);
 Transaction t(f);std::string e;
 check(t.commit({target(0x2000,0x2000,Type::UInt64,"0","18446744073709551615")},
       "18446744073709551615",e),"full precision UInt64");
 check(f.memory[0x2000]==std::vector<uint8_t>(8,0xff),"eight-byte exact unsigned payload");
 check(t.restore(e),"restore exact UInt64");
 check(f.memory[0x2000]==std::vector<uint8_t>(8,0),"full precision restored");
}
static void sliderSemantics(){
 Fake f;f.memory[0x3000]={2,0,0,0};Transaction t(f);std::string e;
 // Simulated dragging only changes local pending UI string; transaction stays OFF.
 std::string pending="7";check(!t.active()&&f.memory[0x3000][0]==2,"drag does not write");
 check(t.commit({slider(0x3000,0x3000,Type::Int32)},pending,e),"switch-on applies pending value");
 check(f.memory[0x3000][0]==7,"switch-on committed selected value");
 pending="9";check(f.memory[0x3000][0]==7,"drag pending has not committed");
 check(t.update({slider(0x3000,0x3000,Type::Int32)},pending,e),"slider active update");
 check(f.memory[0x3000][0]==9,"slider updated on release");
 check(t.restore(e)&&f.memory[0x3000][0]==2,"switch-off restores first Original");
}
static void atomicRollback(){
 Fake f;f.memory[0x4000]={1};f.memory[0x5000]={2};std::string e;
 auto pair=std::vector<Target>{target(0x4000,0x4000,Type::UInt8,"0","100"),
                               target(0x5000,0x5000,Type::UInt8,"0","100")};
 f.failWrite=2;Transaction t(f);
 check(!t.commit(pair,"55",e),"partial write rejected");
 check(!t.active()&&!t.recoveryFailed(),"successful rollback does not lock");
 check(f.memory[0x4000][0]==1&&f.memory[0x5000][0]==2,"both values restored");
 Fake g;g.memory[0x4000]={1};g.memory[0x5000]={2};g.failWrite=2;g.failRollback=1;
 Transaction lock(g);
 check(!lock.commit(pair,"55",e),"rollback failure observed");
 check(lock.recoveryFailed(),"rollback failure locks transaction");
 check(!lock.commit(pair,"42",e),"locked transaction refuses future writes");
}
static void restoreFailure(){
 Fake f;f.memory[0x6000]={2};f.memory[0x7000]={1};std::string e;
 auto pair=std::vector<Target>{target(0x6000,0x6000,Type::UInt8,"0","100"),
                               target(0x7000,0x7000,Type::UInt8,"0","100")};
 Transaction t(f);check(t.commit(pair,"55",e),"restore test setup");
 f.writes=0;f.failWrite=2;
 check(!t.restore(e),"restore failure detected");
 check(t.active()&&!t.recoveryFailed(),"failed restore rollback leaves transaction enabled");
 check(f.memory[0x6000][0]==55&&f.memory[0x7000][0]==55,"restore rolled back to applied");
 f.failWrite=0;check(t.restore(e),"subsequent restore succeeds");
}
static void guard(){
 Fake f;f.memory[0x8000]={1,0,0,0};f.memory[0x9000]={2,0,0,0};std::string e;
 Transaction t(f);
 check(!t.commit({target(0x8001,0x8001,Type::Int32,"0","100")},"10",e),
       "reject unaligned target");
 check(!t.commit({target(0x8000,0x8000,Type::Int32,"0","100"),
                  target(0x8002,0x8004,Type::UInt8,"0","10")},"3",e),
       "reject overlapping addresses");
 check(!t.commit({target(0x8000,0x8000,Type::Int32,"0","100"),
                  target(0x9000,0x9000,Type::Int32,"0","100")},"-1",e),
       "reject negative values before writes");
 check(f.writes==0,"all preflight errors are read-only");
 check(t.commit({target(0x8000,0x8000,Type::Int32,"0","100")},"10",e),
       "setup external writer test");
 f.memory[0x8000][0]=9;
 check(!t.restore(e),"refuse restore if live bytes have changed");
 check(f.memory[0x8000][0]==9&&t.active(),"preserve third-party bytes");
}
static void activeUpdateRollback(){
 Fake f;f.memory[0xA000]={1};f.memory[0xB000]={2};std::string e;
 std::vector<Target> pair={target(0xA000,0xA000,Type::UInt8,"0","100"),
                           target(0xB000,0xB000,Type::UInt8,"0","100")};
 Transaction tx(f);
 check(tx.commit(pair,"40",e),"commit multi-cell original");
 f.writes=0;f.failWrite=2;
 check(!tx.update(pair,"50",e),"update partial write failure");
 check(!tx.recoveryFailed()&&tx.active(),"successful update rollback keeps active");
 check(f.memory[0xA000][0]==40&&f.memory[0xB000][0]==40,
       "failed update restores previous applied values");
 f.failWrite=0;
 check(tx.update(pair,"60",e),"retry after successful rollback");
 check(tx.restore(e),"restore after retry");
 check(f.memory[0xA000][0]==1&&f.memory[0xB000][0]==2,
       "first originals restored, not intermediate values");
 Fake broken;broken.memory[0xA000]={1};broken.memory[0xB000]={2};
 Transaction locked(broken);
 check(locked.commit(pair,"40",e),"setup rollback failure during update");
 broken.writes=0;broken.failWrite=2;
 // Simulate refused rollback of prior applied scalar.
 broken.failRollback=0;
 // A new writer interfering between updates must be rejected without write.
 broken.memory[0xA000][0]=41;
 check(!locked.update(pair,"50",e),"external writer detected");
 check(broken.writes==0,"external mismatch prevents all update writes");
}
int main(){
 activeUpdateRollback();basic();exact64();sliderSemantics();atomicRollback();restoreFailure();guard();
 std::printf("P10.4 typed value transactions: %s (%d failures)\n",fails?"FAIL":"PASS",fails);
 return fails?1:0;
}
