#import <Foundation/Foundation.h>
@class ZNV3StaticBuildPlan;
NS_ASSUME_NONNULL_BEGIN
@interface ZNV3StaticBinaryExport : NSObject
/// Always exports into a unique Documents/ZonoePatchOutput/P6-*/ directory.
+ (nullable NSString *)generate:(ZNV3StaticBuildPlan *)plan error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
