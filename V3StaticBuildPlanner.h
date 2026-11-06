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
- (instancetype)initWithRuleID:(NSString *)ruleID featureKey:(NSString *)featureKey featureName:(NSString *)featureName
 uuid:(NSString *)uuid path:(NSString *)path rva:(uint64_t)rva fileOffset:(uint64_t)fileOffset original:(NSData *)original patch:(NSData *)patch;
@end

@interface ZNV3StaticBuildPlan : NSObject
@property(nonatomic,copy,readonly) NSString *module;
@property(nonatomic,copy,readonly) NSString *featureName;
@property(nonatomic,assign,readonly) NSUInteger featureCount;
@property(nonatomic,copy,readonly) NSString *imageUUID;
@property(nonatomic,copy,readonly) NSString *sourcePath;
@property(nonatomic,copy,readonly) NSArray<ZNV3StaticBuildEntry *> *entries;
- (instancetype)initWithModule:(NSString *)module entries:(NSArray<ZNV3StaticBuildEntry *> *)entries;
- (instancetype)initWithModule:(NSString *)module name:(NSString *)name entries:(NSArray<ZNV3StaticBuildEntry *> *)entries;
- (instancetype)initWithModule:(NSString *)module name:(NSString *)name featureCount:(NSUInteger)count entries:(NSArray<ZNV3StaticBuildEntry *> *)entries;
/// Enforces a single binary identity and disjoint file/instruction spans.
+ (BOOL)validateEntries:(NSArray<ZNV3StaticBuildEntry *> *)entries error:(NSError * _Nullable * _Nullable)error;
/// Only for diagnostics/forward-compatible build input; not a patched binary.
- (NSDictionary *)manifest;
@end


/**
 * P10.6 phase 1: read-only cross-kind ownership. A numeric span must have
 * already passed the typed RW/UUID preflight; this plan never authorizes writes.
 * It does not alter P9 static entries, typed descriptors or Customer ABI.
 */
@interface ZNV3UnifiedNumericSpan : NSObject
@property(nonatomic,copy,readonly) NSString *featureID;
@property(nonatomic,copy,readonly) NSString *ruleID;
@property(nonatomic,copy,readonly) NSString *imageUUID;
@property(nonatomic,copy,readonly) NSString *sourcePath;
@property(nonatomic,assign,readonly) uint64_t rva;
@property(nonatomic,assign,readonly) uint64_t fileOffset;
@property(nonatomic,assign,readonly) uint64_t width;
- (instancetype)initWithFeatureID:(NSString *)featureID ruleID:(NSString *)ruleID
 uuid:(NSString *)uuid path:(NSString *)path rva:(uint64_t)rva
 fileOffset:(uint64_t)fileOffset width:(uint64_t)width;
@end

@interface ZNV3UnifiedBuildPlan : NSObject
@property(nonatomic,copy,readonly) NSString *imageUUID;
@property(nonatomic,copy,readonly) NSString *sourcePath;
@property(nonatomic,copy,readonly) NSArray<ZNV3StaticBuildEntry *> *staticEntries;
@property(nonatomic,copy,readonly) NSArray<ZNV3UnifiedNumericSpan *> *numericSpans;
/// Cross-kind collision/identity preflight, including both RVA and file offsets.
+ (nullable instancetype)planWithStaticEntries:(NSArray<ZNV3StaticBuildEntry *> *)entries
 numericSpans:(NSArray<ZNV3UnifiedNumericSpan *> *)spans
 error:(NSError * _Nullable * _Nullable)error;
@end

@interface ZNV3StaticBuildPlanner : NSObject
/// Loaded Mach-O is cross-checked against on-disk content; no write is performed.
/// P10.3 preflight: validates a numeric data target and emits a versioned typed
/// descriptor. Never modifies the target binary. Not yet supported by exporter.
+ (nullable NSData *)typedDescriptorForFeature:(ZNV3Feature *)feature
 error:(NSError * _Nullable * _Nullable)error;
+ (nullable ZNV3StaticBuildPlan *)planForFeature:(ZNV3Feature *)feature
 error:(NSError * _Nullable * _Nullable)error;
+ (nullable ZNV3StaticBuildPlan *)planForFeatures:(NSArray<ZNV3Feature *> *)features
 error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
