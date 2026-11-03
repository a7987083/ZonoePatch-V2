#import <Foundation/Foundation.h>
@class ZNV3Feature;
NS_ASSUME_NONNULL_BEGIN

/// Immutable, read-only plan. Producing a plan never modifies Mach-O or runtime memory.
@interface ZNV3StaticBuildEntry : NSObject
@property(nonatomic,copy,readonly) NSString *ruleID;
@property(nonatomic,copy,readonly) NSString *featureKey;
@property(nonatomic,copy,readonly) NSString *featureName;
@property(nonatomic,copy,readonly) NSString *moduleUUID;
@property(nonatomic,copy,readonly) NSString *sourcePath;
@property(nonatomic,assign,readonly) uint64_t rva;
@property(nonatomic,assign,readonly) uint64_t fileOffset;
@property(nonatomic,copy,readonly) NSData *originalBytes;
@property(nonatomic,copy,readonly) NSData *patchBytes;
- (instancetype)initWithRuleID:(NSString *)ruleID uuid:(NSString *)uuid path:(NSString *)path
 rva:(uint64_t)rva fileOffset:(uint64_t)fileOffset original:(NSData *)original patch:(NSData *)patch;
@end

@interface ZNV3StaticBuildPlan : NSObject
@property(nonatomic,copy,readonly) NSString *module;
@property(nonatomic,copy,readonly) NSString *featureName;
@property(nonatomic,copy,readonly) NSString *imageUUID;
@property(nonatomic,copy,readonly) NSString *sourcePath;
@property(nonatomic,copy,readonly) NSArray<ZNV3StaticBuildEntry *> *entries;
- (instancetype)initWithModule:(NSString *)module entries:(NSArray<ZNV3StaticBuildEntry *> *)entries;
- (instancetype)initWithModule:(NSString *)module name:(NSString *)name entries:(NSArray<ZNV3StaticBuildEntry *> *)entries;
/// Enforces a single binary identity and disjoint file/instruction spans.
+ (BOOL)validateEntries:(NSArray<ZNV3StaticBuildEntry *> *)entries error:(NSError * _Nullable * _Nullable)error;
/// Only for diagnostics/forward-compatible build input; not a patched binary.
- (NSDictionary *)manifest;
@end

@interface ZNV3StaticBuildPlanner : NSObject
/// Loaded Mach-O is cross-checked against on-disk content; no write is performed.
+ (nullable ZNV3StaticBuildPlan *)planForFeature:(ZNV3Feature *)feature
 error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
