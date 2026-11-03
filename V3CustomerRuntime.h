#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface ZNV3CustomerFeature : NSObject
@property(nonatomic,copy,readonly) NSString *identifier;
@property(nonatomic,copy,readonly) NSString *title;
@property(nonatomic,copy,readonly) NSString *imageName;
@property(nonatomic,assign,readonly) NSUInteger ruleCount;
@property(nonatomic,assign,readonly) BOOL enabled;
@end
@interface ZNV3CustomerRuntime : NSObject
@property(nonatomic,assign,readonly) BOOL recoveryFailed;
@property(nonatomic,copy,readonly) NSString *lastDiagnostic;
+ (instancetype)shared;
- (NSArray<ZNV3CustomerFeature *> *)discover;
- (BOOL)setEnabled:(BOOL)enabled feature:(ZNV3CustomerFeature *)feature
             error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
