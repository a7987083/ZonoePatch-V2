#import <Foundation/Foundation.h>
@class ZNV3Feature;
NS_ASSUME_NONNULL_BEGIN
// Explicit opt-in P10.6.1 preflight; never writes Mach-O or runtime memory.
// P9 toggle Builder and Customer paths are intentionally unchanged.
@interface ZNV3UnifiedBuildPlanner : NSObject
+ (nullable NSDictionary<NSString *,id> *)preflightManifestForFeatures:(NSArray<ZNV3Feature *> *)features
 error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
