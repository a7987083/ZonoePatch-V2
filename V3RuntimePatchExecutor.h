#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@class ZNV3PatchOperation;
@protocol ZNV3PatchMemoryBackend <NSObject>
/// Mandatory identity gate. The iOS backend rechecks loaded Mach-O UUID and mapped segment.
- (BOOL)validateOperation:(ZNV3PatchOperation *)operation error:(NSError **)error;
- (nullable NSData *)readAt:(uintptr_t)address length:(NSUInteger)length error:(NSError **)error;
- (BOOL)writeAt:(uintptr_t)address bytes:(NSData *)bytes error:(NSError **)error;
@end
@interface ZNV3PatchOperation : NSObject
@property(nonatomic,copy,readonly) NSString *identifier;
@property(nonatomic,copy,readonly) NSString *moduleUUID;
@property(nonatomic,assign,readonly) uintptr_t address;
@property(nonatomic,copy,readonly) NSData *expectedBytes;
@property(nonatomic,copy,readonly) NSData *patchBytes;
- (instancetype)initWithIdentifier:(NSString *)identifier moduleUUID:(NSString *)moduleUUID
 address:(uintptr_t)address expected:(NSData *)expected patch:(NSData *)patch;
@end
typedef NS_ENUM(NSInteger,ZNV3PatchTransactionStatus) {
 ZNV3PatchTransactionStatusDisabled=0,
 ZNV3PatchTransactionStatusEnabled=1,
 ZNV3PatchTransactionStatusRecoveryFailed=2
};
@interface ZNV3RuntimePatchExecutor : NSObject
@property(nonatomic,assign,readonly) ZNV3PatchTransactionStatus status;
@property(nonatomic,copy,readonly) NSString *lastDiagnostic;
- (instancetype)initWithBackend:(id<ZNV3PatchMemoryBackend>)backend;
- (BOOL)setEnabled:(BOOL)enabled operations:(NSArray<ZNV3PatchOperation *> *)operations
 error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
