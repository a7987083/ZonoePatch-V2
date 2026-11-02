#import <Foundation/Foundation.h>
@class ZNV3Feature;
@interface ZNV3ConfigRepository : NSObject
- (NSArray<ZNV3Feature *> *)loadFeatures:(NSError **)error;
- (BOOL)saveFeatures:(NSArray<ZNV3Feature *> *)features error:(NSError **)error;
@end
