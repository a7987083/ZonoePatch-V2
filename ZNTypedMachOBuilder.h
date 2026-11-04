#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface ZNTypedMachOBuilder : NSObject
/// Embed a validated P10.3 typed descriptor in a new read-only __ZNTYPE Mach-O segment.
/// This changes metadata only: no hook, value write, or Customer runtime capability.
+ (BOOL)embedDescriptor:(NSData *)descriptor
                 source:(NSString *)source
                 output:(NSString *)output
                  error:(NSError * _Nullable * _Nullable)error;
+ (nullable NSData *)extractDescriptor:(NSString *)path
                                error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
