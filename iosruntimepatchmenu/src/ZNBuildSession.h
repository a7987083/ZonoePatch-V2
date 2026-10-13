#pragma once
#import <Foundation/Foundation.h>
@class ZNBinaryPatchWorkspace, ZNRuntimeActionStore, ZNNativeHookStore;
// Scoped synchronous builder inputs. No authored Store is mutated by prepare/emit.
@interface ZNBuildSession : NSObject
@property(nonatomic,strong,readonly) ZNBinaryPatchWorkspace *workspace;
@property(nonatomic,strong,readonly) ZNRuntimeActionStore *runtimeStore;
@property(nonatomic,strong,readonly) ZNNativeHookStore *hookStore;
+ (instancetype)captureWorkspace:(ZNBinaryPatchWorkspace *)workspace;
- (BOOL)perform:(BOOL (^)(void))body;
@end
#define ZNBuildRuntimeStoreThreadKey @"zonoe.build-session.runtime-store"
#define ZNBuildHookStoreThreadKey @"zonoe.build-session.hook-store"
