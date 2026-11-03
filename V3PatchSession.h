#import <Foundation/Foundation.h>
#import "V3RuntimePatchExecutor.h"
@class ZNV3Feature;
NS_ASSUME_NONNULL_BEGIN
/// Process-local owner: a single active feature; no persisted ON state.
@interface ZNV3PatchSession : NSObject
@property(nonatomic,copy,readonly,nullable) NSString *activeFeatureID;
@property(nonatomic,assign,readonly) ZNV3PatchTransactionStatus status;
@property(nonatomic,copy,readonly) NSString *lastDiagnostic;
+ (instancetype)shared;
- (BOOL)isActiveFeature:(NSString *)identifier;
- (BOOL)applyFeature:(ZNV3Feature *)feature error:(NSError * _Nullable * _Nullable)error;
- (BOOL)restoreFeature:(NSString *)identifier error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
