#import <Foundation/Foundation.h>
@class ZNV3Feature;
NS_ASSUME_NONNULL_BEGIN
/// Switches only writable selectedTarget slots in an installed P6-C Mach-O.
/// No writes to executable pages, no reuse of the jailbroken Bytes Patch executor.
@interface ZNV3StaticDispatchRuntime : NSObject
@property(nonatomic,assign,readonly) BOOL recoveryFailed;
@property(nonatomic,assign,readonly) BOOL hasActiveFeature;
@property(nonatomic,copy,readonly) NSString *lastDiagnostic;
+ (instancetype)shared;
- (BOOL)isEnabledForFeature:(NSString *)identifier;
- (BOOL)setEnabled:(BOOL)enabled forFeature:(ZNV3Feature *)feature
            error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
