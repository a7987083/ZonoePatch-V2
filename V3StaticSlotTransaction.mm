#import "V3StaticSlotTransaction.h"
#include <stdint.h>
static NSError *ZNSTError(NSInteger code,NSString *msg) {
 return [NSError errorWithDomain:@"ZonoePatch.V3.StaticSlot" code:code
  userInfo:@{NSLocalizedDescriptionKey:msg?:@"Unknown Static Slot failure"}];
}
@implementation ZNV3StaticSlotOperation
- (instancetype)initWithAddress:(uintptr_t)address expected:(uint64_t)expected desired:(uint64_t)desired {
 if((self=[super init])){_address=address;_expected=expected;_desired=desired;}return self;
}
@end
@interface ZNV3StaticSlotTransaction ()
@property(nonatomic,strong) id<ZNV3StaticSlotBackend> backend;
@property(nonatomic,assign,readwrite) BOOL recoveryFailed;
@property(nonatomic,copy,readwrite) NSString *lastDiagnostic;
@end
@implementation ZNV3StaticSlotTransaction
- (instancetype)initWithBackend:(id<ZNV3StaticSlotBackend>)backend {
 if((self=[super init])){_backend=backend;_lastDiagnostic=@"";}return self;
}
- (BOOL)apply:(NSArray<ZNV3StaticSlotOperation *> *)operations error:(NSError **)error {
 @synchronized(self) {
  if(self.recoveryFailed){if(error)*error=ZNSTError(1,@"前次 Static Slot 回滚失败，已锁定");return NO;}
  if(!operations.count||operations.count>128){if(error)*error=ZNSTError(2,@"Static Slot 规则数量不合法");return NO;}
  NSMutableSet<NSNumber *> *seen=[NSMutableSet setWithCapacity:operations.count];
  // Validate every expected value before the first write.
  for(ZNV3StaticSlotOperation *op in operations) {
   NSNumber *key=@(op.address);
   if(!op.address||(op.address&7)||[seen containsObject:key]){
    if(error)*error=ZNSTError(3,@"Static Slot 未对齐、为空或重复");return NO;
   }
   [seen addObject:key];
   uint64_t before=0;NSError *readError=nil;
   if(![self.backend readAt:op.address value:&before error:&readError]||before!=op.expected){
    self.lastDiagnostic=[NSString stringWithFormat:@"Static Slot preflight mismatch 0x%llX",
      (unsigned long long)op.address];
    if(error)*error=readError?:ZNSTError(4,self.lastDiagnostic);return NO;
   }
  }
  NSMutableArray<ZNV3StaticSlotOperation *> *written=[NSMutableArray array];
  for(ZNV3StaticSlotOperation *op in operations) {
   if(op.expected==op.desired)continue;
   NSError *writeError=nil;
   BOOL didWrite=[self.backend writeAt:op.address value:op.desired error:&writeError];
   uint64_t actual=UINT64_MAX;
   NSError *readError=nil;
   BOOL readOK=[self.backend readAt:op.address value:&actual error:&readError];
   // Even if write reports failure, it may have modified memory: include it in rollback.
   if(didWrite&&readOK&&actual==op.desired){[written addObject:op];continue;}
   [written addObject:op];
   BOOL restored=YES;
   NSMutableString *detail=[NSMutableString stringWithFormat:@"Static slot 0x%llX write/readback failed: %@",
        (unsigned long long)op.address,
        writeError.localizedDescription?:readError.localizedDescription?:@"unexpected value"];
   for(ZNV3StaticSlotOperation *undo in [written reverseObjectEnumerator]){
    NSError *undoError=nil;
    BOOL ok=[self.backend writeAt:undo.address value:undo.expected error:&undoError];
    uint64_t got=UINT64_MAX;
    BOOL verified=[self.backend readAt:undo.address value:&got error:nil]&&got==undo.expected;
    if(!ok||!verified){
     restored=NO;
     [detail appendFormat:@" | rollback 0x%llX failed: %@",(unsigned long long)undo.address,
        undoError.localizedDescription?:@"readback mismatch"];
    }
   }
   self.recoveryFailed=!restored;
   self.lastDiagnostic=[detail copy];
   if(error)*error=ZNSTError(restored?5:6,self.lastDiagnostic);
   return NO;
  }
  self.lastDiagnostic=@"Static Slot readback verified";
  return YES;
 }
}
@end
