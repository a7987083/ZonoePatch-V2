#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// A prevalidated and already-mapped RW selectedTarget slot.
@interface ZNV3StaticSlotOperation : NSObject
@property(nonatomic,assign,readonly) uintptr_t address;
@property(nonatomic,assign,readonly) uint64_t expected;
@property(nonatomic,assign,readonly) uint64_t desired;
- (instancetype)initWithAddress:(uintptr_t)address expected:(uint64_t)expected desired:(uint64_t)desired;
@end
@protocol ZNV3StaticSlotBackend <NSObject>
- (BOOL)readAt:(uintptr_t)address value:(uint64_t *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)writeAt:(uintptr_t)address value:(uint64_t)value error:(NSError * _Nullable * _Nullable)error;
@end
/// Fail closed: any rollback failure permanently locks this transaction object.
@interface ZNV3StaticSlotTransaction : NSObject
@property(nonatomic,assign,readonly) BOOL recoveryFailed;
@property(nonatomic,copy,readonly) NSString *lastDiagnostic;
- (instancetype)initWithBackend:(id<ZNV3StaticSlotBackend>)backend;
- (BOOL)apply:(NSArray<ZNV3StaticSlotOperation *> *)operations
      error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
