#include "ZNMachOFile.h"
#include <chrono>
#include <iostream>
#include <algorithm>
int main(){
 std::vector<uint8_t> base(65536,0);uint32_t h[]={0xfeedfacf,0x100000c,0,6,1,72,0,0};memcpy(base.data(),h,sizeof(h));
 uint32_t cmd[]={0x19,72};memcpy(base.data()+32,cmd,8);memcpy(base.data()+40,"__LINKEDIT",10);
 uint64_t seg[]={0x100000000,65536,0,65536};memcpy(base.data()+56,seg,32);
 for(int test=0;test<2;test++){
  std::vector<uint64_t> times;
  for(int sample=-5;sample<31;sample++){
   auto b=base;auto start=std::chrono::steady_clock::now();
   for(int i=0;i<1000;i++){if(test){if(!znmacho::shiftLinkedit(b.data(),b.size(),0,0))return 1;}else{znmacho::File f;if(!znmacho::parse(b.data(),b.size(),f))return 1;}}
   auto ns=std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now()-start).count();if(sample>=0)times.push_back(uint64_t(ns)/1000);
  }
  std::sort(times.begin(),times.end());std::cout<<(test?"linkedit.edit.fixture":"macho.parse.fixture")<<","<<times[15]<<","<<times[28]<<"\n";
 }
}
