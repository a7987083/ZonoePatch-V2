#include "ZNPerformance.h"
#include <cassert>
#include <thread>
#include <iostream>
int main(){
 znperf::reset();{znperf::Scope s(znperf::Search);}assert(znperf::snapshot()[znperf::Search].total==0);
 znperf::enable(true);{znperf::Scope a(znperf::PageRefresh);{znperf::Scope b(znperf::PageRefresh);}}assert(znperf::snapshot()[znperf::PageRefresh].total==1);
 {znperf::Scope s(znperf::Search);znperf::reset();}assert(znperf::snapshot()[znperf::Search].total==0);
 std::vector<std::thread> workers;for(int i=0;i<4;i++)workers.emplace_back([]{for(int j=0;j<1000;j++){znperf::Scope s(znperf::HookDispatch);}});for(auto &w:workers)w.join();
 auto s=znperf::snapshot()[znperf::HookDispatch];assert(s.total==4000&&s.used==1024);assert(znperf::percentile(s,95)>=znperf::percentile(s,50));
 znperf::enable(false);{znperf::Scope s(znperf::BinaryGeneration);}assert(!znperf::snapshot()[znperf::BinaryGeneration].total);
 std::cout<<"performance disabled/nesting/reset/concurrent bounded sampling PASS\n";
}
