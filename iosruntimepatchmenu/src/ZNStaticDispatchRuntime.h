#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZNStaticPatchRecord : NSObject
@property(nonatomic,copy,readonly) NSString *target;
@property(nonatomic,copy,readonly) NSString *title;
@property(nonatomic,copy,readonly) NSString *group;
@property(nonatomic,copy,readonly) NSString *featureDescription;
@property(nonatomic,assign,readonly) uint64_t siteRVA;
@property(nonatomic,assign,readonly) uint32_t patchID;
@property(atomic,assign,readonly,getter=isEnabled) BOOL enabled;
@end

@interface ZNStaticDispatchRuntime : NSObject
+ (instancetype)sharedRuntime;
@property(atomic,copy,readonly) NSArray<ZNStaticPatchRecord *> *records;
@property(nonatomic,assign,readonly) uint64_t snapshotGeneration;
- (void)refresh;
- (BOOL)setEnabled:(BOOL)enabled forRecord:(ZNStaticPatchRecord *)record error:(NSString * _Nullable * _Nullable)error;
- (NSArray<NSString *> *)diagnosticLines;
@end

NS_ASSUME_NONNULL_END
