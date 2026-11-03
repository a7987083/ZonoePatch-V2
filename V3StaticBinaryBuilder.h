#import <Foundation/Foundation.h>
@class ZNV3StaticBuildPlan;
NS_ASSUME_NONNULL_BEGIN
/// Generates a new signed thin ARM64 Mach-O with V2 owned-segment static dispatch.
/// Does not modify the source image, current process, or existing outputs.
@interface ZNV3StaticBinaryBuilder : NSObject
+ (nullable NSString *)generateFromPlan:(ZNV3StaticBuildPlan *)plan error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
