#pragma once
#import "ZNMenuControllerInternal.h"
NS_ASSUME_NONNULL_BEGIN
// Narrow finder-family contract; implementations remain with their existing owners.
@interface ZNRuntimeMenuControllerV040 (ZNMethodFinderUIInternal)
- (nullable NSString *)zn61m2_activeToken;
- (void)zn61m2_cancelSearch:(nullable id)sender;
- (void)zn61m2_startSearch:(nullable id)sender;
- (void)zn60v3_startSearch:(nullable id)sender;
- (nullable NSString *)zn60v3_status;
- (void)zn60v3_setStatus:(NSString *)status;
@end
NS_ASSUME_NONNULL_END
