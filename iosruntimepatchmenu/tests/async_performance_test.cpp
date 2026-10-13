#include "ZNPerformance.h"
#include <cassert>
#include <thread>
#include <iostream>
int main(){
 znperf::enable(false);assert(!znperf::ticket(znperf::SearchQueueWait));
 znperf::enable(true);znperf::reset();znperf::Ticket queue(znperf::HookQueueWait,100);assert(queue.finish(znperf::Completed,125));assert(!queue.finish(znperf::Completed,150));assert(znperf::snapshot()[znperf::HookQueueWait].ns[0]==25);
 znperf::Ticket stale(znperf::SearchCancelLatency,100);znperf::reset();assert(!stale.finish(znperf::Cancelled,200));
 znperf::Ticket cancel(znperf::SearchCancelLatency,100);std::vector<std::thread> threads;for(int i=0;i<8;i++)threads.emplace_back([&]{cancel.finish(znperf::Cancelled,180);});for(auto &t:threads)t.join();auto s=znperf::snapshot()[znperf::SearchCancelLatency];assert(s.total==1&&s.cancelled==1&&s.ns[0]==80);
 znperf::Ticket timedOut(znperf::FirstDisplayTick,100);assert(timedOut.finish(znperf::Failed,1000));assert(znperf::snapshot()[znperf::FirstDisplayTick].failed==1);
 std::cout<<"async ticket queue/cancel/timeout/epoch/exactly-once concurrent PASS\n";
}
