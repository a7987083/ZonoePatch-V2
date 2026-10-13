#pragma once
#include <mutex>
// Static discovery/state and M56 writes share this lock order: operation gate,
// runtime object state, then per-image lease. Never take the runtime state lock
// while another thread can hold the image gate and wait for that state lock.
inline std::recursive_mutex &ZNStaticOperationGate(){static std::recursive_mutex gate;return gate;}
