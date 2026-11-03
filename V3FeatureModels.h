#import <Foundation/Foundation.h>

// P10.1: Stable persisted IDs. Never renumber 0/1/2 in features-v1.json.
typedef NS_ENUM(NSInteger, ZNV3FeatureType) {
 ZNV3FeatureTypeToggle = 0,
 ZNV3FeatureTypeAction = 1,
 ZNV3FeatureTypeNumberInput = 2,
 ZNV3FeatureTypeSlider = 3,
};
static inline BOOL ZNV3FeatureTypeIsValid(NSInteger type) {
 return type>=ZNV3FeatureTypeToggle && type<=ZNV3FeatureTypeSlider;
}
static inline NSString *ZNV3FeatureTypeTitle(NSInteger type) {
 switch(type) {
  case ZNV3FeatureTypeToggle: return @"开关";
  case ZNV3FeatureTypeAction: return @"点击按钮";
  case ZNV3FeatureTypeNumberInput: return @"输入框";
  case ZNV3FeatureTypeSlider: return @"滑条";
  default: return @"未知类型";
 }
}

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
@property(nonatomic,assign) ZNV3FeatureType buttonType;
@property(nonatomic,strong) NSMutableArray<ZNV3PatchRule *> *rules;
+ (instancetype)feature:(NSString *)name detail:(NSString *)detail module:(NSString *)module;
@end
@interface ZNV3FeatureStore : NSObject
@property(nonatomic,strong,readonly) NSMutableArray<ZNV3Feature *> *features;
@property(nonatomic,strong) ZNV3Feature *draft;
@property(nonatomic,strong,readonly) NSError *lastError;
@property(nonatomic,assign,readonly) BOOL persistenceAvailable;
@property(nonatomic,assign,readonly) NSUInteger quarantinedFeatureCount;
@property(nonatomic,assign,readonly) NSUInteger editingIndex;
- (void)editFeatureAtIndex:(NSUInteger)index;
- (void)cancelDraft;
- (void)beginDraftForModule:(NSString *)module;
- (BOOL)saveDraft;
- (BOOL)deleteFeatureAtIndex:(NSUInteger)index;
- (void)deleteRuleAtIndex:(NSUInteger)index;
@end
