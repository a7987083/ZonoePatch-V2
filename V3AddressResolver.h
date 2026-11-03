#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface ZNV3ResolvedAddress : NSObject
@property(nonatomic,copy,readonly) NSString *kind;
@property(nonatomic,copy,readonly) NSString *segmentName;
@property(nonatomic,copy,readonly) NSString *imagePath;
@property(nonatomic,assign,readonly) uint64_t rva;
@property(nonatomic,assign,readonly) uint64_t preferredVA;
@property(nonatomic,assign,readonly) uint64_t runtimeVA;
@property(nonatomic,assign,readonly) uint64_t fileOffset;
@property(nonatomic,assign,readonly) BOOL fileBacked;
@property(nonatomic,assign,readonly) uint64_t segmentVMAddress;
@property(nonatomic,assign,readonly) uint64_t segmentFileOffset;
@property(nonatomic,assign,readonly) uint64_t segmentFileSize;
@property(nonatomic,assign,readonly) uint32_t segmentInitialProtection;
@property(nonatomic,copy,readonly) NSString *imageUUID;
- (instancetype)initWithKind:(NSString *)kind segment:(NSString *)segment path:(NSString *)path
 rva:(uint64_t)rva preferred:(uint64_t)preferred runtime:(uint64_t)runtime
 fileOffset:(uint64_t)fileOffset fileBacked:(BOOL)fileBacked
 segmentVMAddress:(uint64_t)segmentVMAddress segmentFileOffset:(uint64_t)segmentFileOffset
 segmentFileSize:(uint64_t)segmentFileSize protection:(uint32_t)protection uuid:(NSString *)uuid;
@end
@interface ZNV3AddressResolver : NSObject
+ (nullable ZNV3ResolvedAddress *)resolve:(NSString *)text module:(NSString *)module
 error:(NSError * _Nullable * _Nullable)error;
+ (BOOL)validAddressText:(NSString *)text;
+ (BOOL)validAlignedCodeOffsetText:(NSString *)text;
@end
NS_ASSUME_NONNULL_END
