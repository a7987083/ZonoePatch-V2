#import <Foundation/Foundation.h>
@class ZNV3ResolvedAddress;

NS_ASSUME_NONNULL_BEGIN
@interface ZNV3PatchValidation : NSObject
@property(nonatomic,strong,readonly) ZNV3ResolvedAddress *address;
@property(nonatomic,copy,readonly) NSData *patchBytes;
@property(nonatomic,copy,readonly) NSData *originalBytes;
@property(nonatomic,copy,readonly) NSString *originalHex;
@property(nonatomic,copy,readonly) NSString *patchHex;
- (instancetype)initWithAddress:(ZNV3ResolvedAddress *)address
 patch:(NSData *)patch original:(NSData *)original;
@end

/// Read-only runtime preflight. Does not change memory protections or write executable pages.
@interface ZNV3PatchValidator : NSObject
+ (nullable ZNV3PatchValidation *)validateOffset:(NSString *)offset
 patch:(NSString *)patch module:(NSString *)module
 error:(NSError * _Nullable * _Nullable)error;
+ (nullable NSData *)parsePatchBytes:(NSString *)text error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
