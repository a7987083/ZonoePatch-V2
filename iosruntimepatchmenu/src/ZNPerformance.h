#pragma once
#include <atomic>
#include <chrono>
#include <mutex>
#include <array>
#include <algorithm>
#include <vector>
namespace znperf {
enum Metric { MenuStartup, PageRefresh, Search, HookDispatch, BinaryGeneration, Count };
inline const char *name(Metric m){static const char *names[]={"menu.activation","page.refresh","search.sync","hook.reconcile.execution","binary.generation"};return names[m];}
struct Series { uint64_t total=0;size_t used=0,next=0;std::array<uint64_t,1024> ns{}; };
struct State { std::atomic<bool> enabled{false};std::mutex lock;std::array<Series,Count> series{};uint64_t epoch=0; };
inline State &state(){static State s;return s;}
inline void enable(bool v){state().enabled.store(v,std::memory_order_relaxed);}
inline void reset(){auto &s=state();std::lock_guard<std::mutex> g(s.lock);s.series={};++s.epoch;}
inline std::array<Series,Count> snapshot(){auto &s=state();std::lock_guard<std::mutex> g(s.lock);return s.series;}
inline std::array<unsigned,Count> &depth(){static thread_local std::array<unsigned,Count> d{};return d;}
class Scope {
 Metric metric;bool entered=false,outer=false;uint64_t epoch=0;std::chrono::steady_clock::time_point start;
public:
 explicit Scope(Metric m):metric(m){
  if(!state().enabled.load(std::memory_order_relaxed))return;
  entered=true;outer=depth()[m]++==0;
  if(outer){auto &s=state();std::lock_guard<std::mutex> g(s.lock);epoch=s.epoch;start=std::chrono::steady_clock::now();}
 }
 ~Scope(){
  if(!entered)return;
  --depth()[metric];if(!outer)return;
  uint64_t elapsed=uint64_t(std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now()-start).count());
  auto &s=state();std::lock_guard<std::mutex> g(s.lock);if(epoch!=s.epoch)return;
  auto &v=s.series[metric];++v.total;v.ns[v.next]=elapsed;v.next=(v.next+1)%v.ns.size();v.used=std::min(v.used+1,v.ns.size());
 }
 Scope(const Scope&)=delete;Scope& operator=(const Scope&)=delete;
};
inline uint64_t percentile(const Series &s,unsigned percent){
 if(!s.used)return 0;
 std::vector<uint64_t> values(s.ns.begin(),s.ns.begin()+s.used);std::sort(values.begin(),values.end());
 return values[(values.size()-1)*std::min(percent,100u)/100];
}
}
