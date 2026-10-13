#pragma once
#import <Foundation/Foundation.h>
@class ZNBinaryPatchWorkspace, ZNRuntimeActionStore, ZNNativeHookStore;
// Scoped synchronous builder inputs. No authored Store is mutated by prepare/emit.
@interface ZNBuildSession : NSObject
@property(nonatomic,copy,readonly) NSString *identifier;
@property(nonatomic,copy,readonly) NSDictionary<NSString *,id> *staticDefaults;
@property(nonatomic,strong,readonly) ZNBinaryPatchWorkspace *workspace;
@property(nonatomic,strong,readonly) ZNRuntimeActionStore *runtimeStore;
@property(nonatomic,strong,readonly) ZNNativeHookStore *hookStore;
+ (nullable instancetype)currentSession;
+ (instancetype)captureWorkspace:(ZNBinaryPatchWorkspace *)workspace;
- (BOOL)perform:(BOOL (^)(void))body;
@end
#define ZNBuildRuntimeStoreThreadKey @"zonoe.build-session.runtime-store"
#define ZNBuildHookStoreThreadKey @"zonoe.build-session.hook-store"

#define ZNBuildSessionThreadKey @"zonoe.build-session.context"
