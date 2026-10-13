#include "ZNImageLifetime.h"
#include <cassert>
#include <thread>
#include <atomic>
int main(){znimage::Lifetimes registry;registry.added(0x1000);auto a=registry.get(0x1000);assert(a->executions.enter());assert(a->executions.enter());std::thread revoke([&]{registry.removed(0x1000);});revoke.join();assert(!a->executions.enter());assert(!a->executions.drain(std::chrono::milliseconds(1)));a->executions.leave();a->executions.leave();assert(a->executions.drain(std::chrono::milliseconds(1)));registry.added(0x1000);auto b=registry.get(0x1000);assert(b->incarnation!=a->incarnation);std::atomic<unsigned> calls{0};std::thread x([&]{for(int i=0;i<10000;i++)if(b->executions.enter()){calls++;b->executions.leave();}});std::thread y([&]{for(int i=0;i<10000;i++)if(b->executions.enter()){calls++;b->executions.leave();}});x.join();y.join();assert(calls==20000&&b->executions.inFlight()==0);}
