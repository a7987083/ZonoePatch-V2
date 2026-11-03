#import <Foundation/Foundation.h>
@class ZNV3StaticBuildPlan;
NS_ASSUME_NONNULL_BEGIN
/// Generates a new signed thin ARM64 Mach-O with V2 owned-segment static dispatch.
/// Does not modify the source image, current process, or existing outputs.
@interface ZNV3StaticBinaryBuilder : NSObject
+ (BOOL)buildPlan:(ZNV3StaticBuildPlan *)plan inDirectory:(NSString *)directory
       outputPath:(NSString * _Nullable * _Nullable)output
       metadata:(NSDictionary * _Nullable * _Nullable)metadata
       error:(NSString * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
