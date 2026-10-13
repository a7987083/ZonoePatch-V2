#include "ZNPerformance.h"
#include <iostream>
int main(){
 volatile uint64_t work=0;
 for(int mode=0;mode<4;mode++){
  znperf::enable(mode>=2);std::vector<uint64_t> times;
  for(int sample=-5;sample<31;sample++){
   auto start=std::chrono::steady_clock::now();
   for(int i=0;i<1000;i++){
    if(mode==0){work=work+1;}
    else if(mode<3){znperf::Scope scope(znperf::PageRefresh);work=work+1;}
    else{auto ticket=znperf::ticket(znperf::SearchQueueWait);work=work+1;ticket->finish();}
   }
   auto ns=std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now()-start).count();if(sample>=0)times.push_back(uint64_t(ns)/1000);
  }
  std::sort(times.begin(),times.end());const char *names[]={"sampling.empty-loop","sampling.disabled-scope","sampling.enabled-scope","sampling.enabled-ticket"};std::cout<<names[mode]<<","<<times[15]<<","<<times[28]<<"\n";
 }
 return work?0:1;
}
