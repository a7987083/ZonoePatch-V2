#import <Foundation/Foundation.h>
@class ZNV3StaticBuildPlan;
@class ZNV3Feature;
NS_ASSUME_NONNULL_BEGIN
@interface ZNV3StaticBinaryExport : NSObject
/// Always exports into a unique Documents/ZonoePatchOutput/P6-*/ directory.
+ (nullable NSString *)generate:(ZNV3StaticBuildPlan *)plan error:(NSError * _Nullable * _Nullable)error;
/// P10.3.2 metadata-only Mach-O export. Not a playable Customer numeric feature.
+ (nullable NSString *)generateTypedMetadataForFeature:(ZNV3Feature *)feature
 error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
