#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Shared HEX codec for persisted ARM64 Code Patch rules and runtime preflight.
@interface ZNV3PatchCodec : NSObject
+ (nullable NSData *)codeBytesFromText:(NSString *)text error:(NSError * _Nullable * _Nullable)error;
+ (BOOL)isValidCodeText:(NSString *)text;
@end
NS_ASSUME_NONNULL_END
