#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
uint64_t ZNCurrentImageGeneration(void);
#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
#include "ZNImageLifetime.h"
std::shared_ptr<znimage::Lifetime> ZNImageLifetimeForHeader(uintptr_t header);
#endif
