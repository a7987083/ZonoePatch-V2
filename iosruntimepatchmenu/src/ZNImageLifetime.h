#pragma once
#include <atomic>
#include <cstdint>
#include <map>
#include <memory>
#include <mutex>
namespace znimage {
// Removal callbacks revoke without waiting under dyld's lock. An operation must
// separately retain the loader reference before taking the operation mutex.
struct Lifetime {const uint64_t incarnation;std::atomic<bool> live{true};std::recursive_mutex operations;explicit Lifetime(uint64_t n):incarnation(n){}};
class Lifetimes {
 std::mutex lock;uint64_t next=0;std::map<uintptr_t,std::shared_ptr<Lifetime>> states;
public:
 void added(uintptr_t base){std::lock_guard<std::mutex> g(lock);auto old=states.find(base);if(old!=states.end())old->second->live=false;states[base]=std::make_shared<Lifetime>(++next);}
 void removed(uintptr_t base){std::lock_guard<std::mutex> g(lock);auto it=states.find(base);if(it!=states.end()){it->second->live=false;states.erase(it);}}
 std::shared_ptr<Lifetime> get(uintptr_t base){std::lock_guard<std::mutex> g(lock);auto it=states.find(base);return it==states.end()?nullptr:it->second;}
};
}
