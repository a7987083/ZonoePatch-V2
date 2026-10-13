#pragma once
#include <mutex>
#include <condition_variable>
#include <chrono>
#include <cstdint>
namespace znimage {
// No lock spans user code. Revocation never waits; drain is an explicit bounded
// caller operation, forbidden while holding loader/state locks or a local ticket.
class ExecutionGate {
 mutable std::mutex mutex;std::condition_variable changed;bool accepting=true;uint64_t active=0;
public:
 bool enter(){std::lock_guard<std::mutex> g(mutex);if(!accepting)return false;++active;return true;}
 void leave(){std::lock_guard<std::mutex> g(mutex);if(active)--active;if(!active)changed.notify_all();}
 void revoke(){std::lock_guard<std::mutex> g(mutex);accepting=false;if(!active)changed.notify_all();}
 uint64_t inFlight()const{std::lock_guard<std::mutex> g(mutex);return active;}
 bool drain(std::chrono::milliseconds timeout){std::unique_lock<std::mutex> g(mutex);return changed.wait_for(g,timeout,[&]{return active==0;});}
};
}
