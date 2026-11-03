#import <Foundation/Foundation.h>
@class ZNV3Feature;
@interface ZNV3ConfigRepository : NSObject
/// Entries from older schemas that cannot be safely edited remain preserved verbatim.
@property(nonatomic,assign,readonly) NSUInteger quarantinedFeatureCount;
- (NSArray<ZNV3Feature *> *)loadFeatures:(NSError **)error;
- (BOOL)saveFeatures:(NSArray<ZNV3Feature *> *)features error:(NSError **)error;
@end
