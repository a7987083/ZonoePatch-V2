#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface ZNTypedMachOBuilder : NSObject
/// Embed a validated P10.3 typed descriptor in a new read-only __ZNTYPE Mach-O segment.
/// This changes metadata only: no hook, value write, or Customer runtime capability.
+ (BOOL)embedDescriptor:(NSData *)descriptor
                 source:(NSString *)source
                 output:(NSString *)output
                  error:(NSError * _Nullable * _Nullable)error;
/// P10.6.2: explicitly allow exactly one already-prepared P9 static image.
/// Fails closed on invalid __ZNDATA table, duplicated owned sections, or
/// preexisting __ZNTYPE. Metadata only; Customer mixed numeric execution deferred.
+ (BOOL)embedDescriptorIntoPreparedStatic:(NSData *)descriptor
                                   source:(NSString *)source
                                   output:(NSString *)output
                                    error:(NSError * _Nullable * _Nullable)error;
+ (nullable NSData *)extractDescriptor:(NSString *)path
                                error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
