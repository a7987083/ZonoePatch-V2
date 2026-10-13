#pragma once
#import "ZNStaticDispatchRuntime.h"
#import "ZNStaticPatchFormat.h"
@interface ZNStaticPatchRecord (ZNOwnedMetadata)
// Compatibility accessor now points at Record-owned value storage, not dyld memory.
@property(nonatomic,assign) ZN44StaticEntry *entry;
@property(nonatomic,assign) uintptr_t imageBase;
@property(nonatomic,assign) uint64_t imageIncarnation;
@property(nonatomic,assign) uintptr_t headerAddress;
@property(nonatomic,assign) uintptr_t entryAddress;
@property(nonatomic,assign) uintptr_t dispatchAddress;
@property(nonatomic,assign) uint32_t entryIndex;
@end
