#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// P10.6.3 ZNM2 catalog and numeric execution are independent of legacy ZNT1.
@interface ZNMixedCustomerFeature : NSObject
@property(nonatomic,copy,readonly) NSString *identifier; // persisted FeatureID
@property(nonatomic,copy,readonly) NSString *title;
@property(nonatomic,copy,readonly) NSString *imageName;
@property(nonatomic,assign,readonly) NSUInteger numericType;
@property(nonatomic,assign,readonly) NSUInteger featureKind;
@property(nonatomic,copy,readonly) NSString *minimum;
@property(nonatomic,copy,readonly) NSString *maximum;
@property(nonatomic,copy,readonly) NSString *step;
@property(nonatomic,copy,readonly) NSString *defaultValue;
@property(nonatomic,assign,readonly) NSUInteger ruleCount;
@property(nonatomic,assign,readonly,getter=isEnabled) BOOL enabled;
@end
@interface ZNMixedCustomerRuntime : NSObject
@property(nonatomic,assign,readonly) BOOL recoveryFailed;
@property(nonatomic,copy,readonly) NSString *lastDiagnostic;
+ (instancetype)shared;
- (NSArray<ZNMixedCustomerFeature *> *)discover;
- (BOOL)applyValue:(NSString *)decimal feature:(ZNMixedCustomerFeature *)feature
             error:(NSError * _Nullable * _Nullable)error;
- (BOOL)restoreFeature:(ZNMixedCustomerFeature *)feature
                error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
