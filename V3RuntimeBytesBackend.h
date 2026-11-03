#import "V3RuntimePatchExecutor.h"
/// iOS arm64-only RX code writer. No entitlement bypass, no JIT and no W+X.
@interface ZNV3RuntimeBytesBackend : NSObject <ZNV3PatchMemoryBackend>
@end
