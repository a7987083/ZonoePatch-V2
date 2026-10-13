#pragma once

#include <stdint.h>
#include "ZNStaticPatchFormat.h"
#include "ZNCheckedByteView.h"

// M6.8.4 Generated Data Layout V1.
//
// __ZNDATA/__zndata:
//   ZN44StaticHeader
//   ZN44StaticEntry[staticCount]
//   align(8)
//   ZN44FeatureDescriptionHeader
//   ZN44FeatureDescriptionEntry[staticCount]
//   align(8)
//   ZNRuntimeActionHeader + entries + string pool
//   later postprocess-owned extensions (for example RW value cells)
//
// There is intentionally no legacy fallback. Older generated binaries without
// ZN44_STATIC_HEADER_FLAG_GENERATED_LAYOUT_V1 are not part of this contract.

static inline uint64_t ZNGeneratedDataAlign8(uint64_t value) {
    return (value + 7ULL) & ~7ULL;
}

static inline int ZNGeneratedDataLayoutV1LocateRuntimeAction(
    const uint8_t *section,
    uint64_t sectionSize,
    uint64_t *outOffset)
{
    if (!section || sectionSize < sizeof(ZN44StaticHeader)) return 0;

    ZN44StaticHeader headerStorage;
    if(!ZNByteViewRead(section,sectionSize,0,&headerStorage,sizeof(headerStorage)))return 0;
    const ZN44StaticHeader *header=&headerStorage;
    if (header->magic0!=ZN44_STATIC_MAGIC0 ||
        header->magic1!=ZN44_STATIC_MAGIC1 ||
        header->version!=ZN44_STATIC_VERSION_V3 ||
        header->entrySize!=sizeof(ZN44StaticEntry) ||
        header->count>ZN44_STATIC_MAX_ENTRIES ||
        (header->flags & ZN44_STATIC_HEADER_FLAG_GENERATED_LAYOUT_V1)==0)
        return 0;

    uint64_t entriesBytes=(uint64_t)header->count*header->entrySize;
    if (entriesBytes > UINT64_MAX-sizeof(ZN44StaticHeader)) return 0;
    uint64_t descOffset=0;
    if(!ZNCheckedAlign8(sizeof(ZN44StaticHeader)+entriesBytes,&descOffset))return 0;
    if (descOffset>sectionSize ||
        sectionSize-descOffset<sizeof(ZN44FeatureDescriptionHeader))
        return 0;

    ZN44FeatureDescriptionHeader descStorage;
    if(!ZNByteViewRead(section,sectionSize,descOffset,&descStorage,sizeof(descStorage)))return 0;
    const ZN44FeatureDescriptionHeader *desc=&descStorage;
    if (desc->magic0!=ZN44_FEATURE_DESC_MAGIC0 ||
        desc->magic1!=ZN44_FEATURE_DESC_MAGIC1 ||
        desc->count!=header->count ||
        desc->entrySize!=sizeof(ZN44FeatureDescriptionEntry))
        return 0;

    uint64_t descEntriesBytes=(uint64_t)desc->count*desc->entrySize;
    if (descEntriesBytes > UINT64_MAX-sizeof(*desc)) return 0;
    uint64_t actionOffset=0,descEnd=0;
    if(!ZNCheckedAdd64(descOffset,sizeof(*desc),&descEnd) ||
       !ZNCheckedAdd64(descEnd,descEntriesBytes,&descEnd) ||
       !ZNCheckedAlign8(descEnd,&actionOffset))return 0;
    if (actionOffset>sectionSize) return 0;

    if (outOffset) *outOffset=actionOffset;
    return 1;
}
