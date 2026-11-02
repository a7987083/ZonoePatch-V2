#import <Foundation/Foundation.h>
@interface ZNV3PatchRule : NSObject
@property(nonatomic,copy) NSString *identifier;
@property(nonatomic,copy) NSString *offsetText;
@property(nonatomic,copy) NSString *patchText;
+ (instancetype)emptyRule;
@end
@interface ZNV3Feature : NSObject
@property(nonatomic,copy) NSString *identifier;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,copy) NSString *detail;
@property(nonatomic,copy) NSString *module;
@property(nonatomic,assign) NSInteger buttonType;
@property(nonatomic,strong) NSMutableArray<ZNV3PatchRule *> *rules;
+ (instancetype)feature:(NSString *)name detail:(NSString *)detail module:(NSString *)module;
@end
@interface ZNV3FeatureStore : NSObject
@property(nonatomic,strong,readonly) NSMutableArray<ZNV3Feature *> *features;
@property(nonatomic,strong) ZNV3Feature *draft;
- (void)beginDraftForModule:(NSString *)module;
- (void)saveDraft;
- (void)deleteFeatureAtIndex:(NSUInteger)index;
- (void)deleteRuleAtIndex:(NSUInteger)index;
@end
