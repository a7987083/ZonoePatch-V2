#pragma once
#include "ZNStaticPatchFormat.h"
// A P9 dispatch entry carrying a code-type numeric Value Cell is an internal
// execution slot, never a public two-state Toggle. Only bound numeric Customer
// controls may drive it after ZCB1 ownership is verified.
static inline bool ZNCustomerP9EntryVisibleAsToggle(const ZN44StaticEntry &entry){
 return (entry.flags&ZN44_STATIC_ENTRY_FLAG_VALUE_CELL_V1)==0u &&
        (entry.flags&ZN44_STATIC_ENTRY_FLAG_OFFSET_HOOK_V1)==0u;
}
