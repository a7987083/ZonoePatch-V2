#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// P10.4.2: discovered typed metadata, independent of legacy P9 switch catalog.
@interface ZNTypedCustomerFeature : NSObject
@property(nonatomic,copy,readonly) NSString *identifier;
@property(nonatomic,copy,readonly) NSString *imageName;
@property(nonatomic,copy,readonly) NSString *title;
@property(nonatomic,copy,readonly) NSString *minimum;
@property(nonatomic,copy,readonly) NSString *maximum;
@property(nonatomic,copy,readonly) NSString *step;
@property(nonatomic,copy,readonly) NSString *defaultValue;
@property(nonatomic,assign,readonly) NSUInteger numericType;
@property(nonatomic,assign,readonly) NSUInteger featureKind;
@property(nonatomic,assign,readonly) NSUInteger ruleCount;
@property(nonatomic,assign,readonly,getter=isEnabled) BOOL enabled;
@end

/// No UI is exposed in P10.4.2. Calls fail closed on stale image identity,
/// invalid targets or external writes. Restore never blindly overwrites memory.
@interface ZNTypedCustomerRuntime : NSObject
@property(nonatomic,assign,readonly) BOOL recoveryFailed;
@property(nonatomic,copy,readonly) NSString *lastDiagnostic;
+ (instancetype)shared;
- (NSArray<ZNTypedCustomerFeature *> *)discover;
- (BOOL)applyValue:(NSString *)decimal feature:(ZNTypedCustomerFeature *)feature
             error:(NSError * _Nullable * _Nullable)error;
- (BOOL)restoreFeature:(ZNTypedCustomerFeature *)feature
                error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
