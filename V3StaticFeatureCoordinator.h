#import <Foundation/Foundation.h>
#import "V3StaticSlotTransaction.h"
NS_ASSUME_NONNULL_BEGIN

// One saved feature owns its own set of distinct RW P9 selectedTarget slots.
// This coordinator never changes the P9 on-disk ABI or writes executable pages.
@interface ZNV3StaticFeatureSlot : NSObject
@property(nonatomic,assign,readonly) uintptr_t address;
@property(nonatomic,assign,readonly) uint64_t offTarget;
@property(nonatomic,assign,readonly) uint64_t onTarget;
- (instancetype)initWithAddress:(uintptr_t)address offTarget:(uint64_t)offTarget
                      onTarget:(uint64_t)onTarget;
@end
@interface ZNV3StaticFeatureCoordinator : NSObject
@property(nonatomic,assign,readonly) BOOL recoveryFailed;
@property(nonatomic,assign,readonly) BOOL hasActiveFeature;
@property(nonatomic,copy,readonly) NSString *lastDiagnostic;
- (instancetype)initWithBackend:(id<ZNV3StaticSlotBackend>)backend;
- (BOOL)isEnabledForFeature:(NSString *)identifier;
- (BOOL)setEnabled:(BOOL)enabled featureID:(NSString *)identifier
             slots:(NSArray<ZNV3StaticFeatureSlot *> *)slots
             error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
