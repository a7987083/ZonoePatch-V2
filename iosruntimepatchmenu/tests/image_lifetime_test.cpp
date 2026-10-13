#include "ZNImageLifetime.h"
#include <cassert>
#include <thread>
#include <vector>
int main(){znimage::Lifetimes r;r.added(0x1000);auto first=r.get(0x1000);assert(first&&first->live);r.added(0x2000);assert(r.get(0x1000)==first);r.removed(0x1000);assert(!first->live&&!r.get(0x1000));r.added(0x1000);auto next=r.get(0x1000);assert(next!=first&&next->incarnation!=first->incarnation);unsigned count=0;std::vector<std::thread> threads;for(int i=0;i<8;i++)threads.emplace_back([&]{for(int j=0;j<1000;j++){std::lock_guard<std::recursive_mutex> g(next->operations);++count;}});for(auto &t:threads)t.join();assert(count==8000);std::unique_lock<std::recursive_mutex> active(next->operations);std::thread remove([&]{r.removed(0x1000);});remove.join();assert(!next->live); // Revocation cannot wait on operation mutex under dyld lock.
}
