#import "V3RuntimePatchExecutor.h"
#include <stdint.h>
static NSError *E(NSInteger code,NSString *msg){return [NSError errorWithDomain:@"ZonoePatch.V3.Executor" code:code userInfo:@{NSLocalizedDescriptionKey:msg}];}
@implementation ZNV3PatchOperation
- (instancetype)initWithIdentifier:(NSString *)ident moduleUUID:(NSString *)uuid address:(uintptr_t)address expected:(NSData *)expected patch:(NSData *)patch {
 if((self=[super init])){_identifier=[ident copy];_moduleUUID=[uuid copy];_address=address;_expectedBytes=[expected copy];_patchBytes=[patch copy];}return self;
}
@end
@interface ZNV3RuntimePatchExecutor ()
@property(nonatomic,strong) id<ZNV3PatchMemoryBackend> backend;
@property(nonatomic,assign,readwrite) ZNV3PatchTransactionStatus status;
@property(nonatomic,copy,readwrite) NSString *lastDiagnostic;
@property(nonatomic,copy) NSArray<ZNV3PatchOperation *> *active;
@end
@implementation ZNV3RuntimePatchExecutor
- (instancetype)initWithBackend:(id<ZNV3PatchMemoryBackend>)backend {
 if(!backend)return nil;
 if((self=[super init])){_backend=backend;_status=ZNV3PatchTransactionStatusDisabled;_lastDiagnostic=@"Not started";}return self;
}
- (BOOL)fail:(NSInteger)code message:(NSString *)message error:(NSError **)error {
 self.lastDiagnostic=message;
 if(error)*error=E(code,message);
 return NO;
}
- (BOOL)validate:(NSArray<ZNV3PatchOperation *> *)ops error:(NSError **)error {
 if(!ops.count||ops.count>128)return [self fail:1 message:@"Action count must be 1..128" error:error];
 NSMutableSet *ids=[NSMutableSet set];
 for(ZNV3PatchOperation *op in ops){
  NSUInteger n=op.patchBytes.length;
  if(!op.identifier.length||!op.moduleUUID.length||!op.address||!n||n>256||(n&3)||(op.address&3)||
     op.expectedBytes.length!=n||[ids containsObject:op.identifier]||n-1>UINTPTR_MAX-op.address)
   return [self fail:2 message:@"Invalid identifier, UUID, alignment or byte count" error:error];
  [ids addObject:op.identifier];
 }
 for(NSUInteger i=0;i<ops.count;i++){
  ZNV3PatchOperation *a=ops[i];uintptr_t ae=a.address+a.patchBytes.length;
  for(NSUInteger j=i+1;j<ops.count;j++){
   ZNV3PatchOperation *b=ops[j];uintptr_t be=b.address+b.patchBytes.length;
   if(a.address<be&&b.address<ae)return [self fail:3 message:@"Overlapping patch ranges" error:error];
  }
 }
 return YES;
}
- (BOOL)activeMatches:(NSArray<ZNV3PatchOperation *> *)ops {
 if(ops.count!=self.active.count)return NO;
 for(NSUInteger i=0;i<ops.count;i++){
  ZNV3PatchOperation *a=ops[i],*b=self.active[i];
  if(a.address!=b.address||![a.identifier isEqual:b.identifier]||![a.moduleUUID isEqual:b.moduleUUID]||
     ![a.expectedBytes isEqual:b.expectedBytes]||![a.patchBytes isEqual:b.patchBytes])return NO;
 }
 return YES;
}
- (BOOL)rollback:(NSArray<NSDictionary *> *)steps detail:(NSString **)detail {
 NSMutableArray *bad=[NSMutableArray array];
 for(NSDictionary *s in [steps reverseObjectEnumerator]){
  ZNV3PatchOperation *op=s[@"op"];NSData *before=s[@"before"];
  NSData *current=[self.backend readAt:op.address length:before.length error:nil];
  if([current isEqual:before])continue;
  NSError *e=nil;BOOL ok=[self.backend writeAt:op.address bytes:before error:&e];
  NSData *after=[self.backend readAt:op.address length:before.length error:nil];
  if(!ok||![after isEqual:before])[bad addObject:[NSString stringWithFormat:@"%@: %@",op.identifier,e.localizedDescription?:@"readback mismatch"]];
 }
 if(bad.count){if(detail)*detail=[bad componentsJoinedByString:@"; "];return NO;}
 return YES;
}
- (BOOL)setEnabled:(BOOL)enabled operations:(NSArray<ZNV3PatchOperation *> *)ops error:(NSError **)error {
 @synchronized(self){
  if(self.status==ZNV3PatchTransactionStatusRecoveryFailed)
   return [self fail:9 message:@"RECOVERY FAILED is latched; further writes blocked" error:error];
  if(![self validate:ops error:error])return NO;
  if(self.status==ZNV3PatchTransactionStatusEnabled){
   if(![self activeMatches:ops])return [self fail:4 message:@"Different transaction already active" error:error];
  }else if(!enabled)return [self fail:5 message:@"No active transaction to restore" error:error];
  NSMutableArray *plan=[NSMutableArray array];
  for(ZNV3PatchOperation *op in ops){
   NSError *e=nil;NSData *now=[self.backend readAt:op.address length:op.patchBytes.length error:&e];
   if(!now)return [self fail:6 message:[NSString stringWithFormat:@"%@ read: %@",op.identifier,e.localizedDescription?:@"failed"] error:error];
   NSData *wanted=enabled?(self.status==ZNV3PatchTransactionStatusEnabled?op.patchBytes:op.expectedBytes):op.patchBytes;
   if(![now isEqual:wanted])return [self fail:7 message:[NSString stringWithFormat:@"%@ current bytes conflict",op.identifier] error:error];
   [plan addObject:@{@"op":op,@"before":now,@"target":enabled?op.patchBytes:op.expectedBytes}];
  }
  NSMutableArray *touched=[NSMutableArray array];
  for(NSDictionary *step in plan){
   ZNV3PatchOperation *op=step[@"op"];NSData *before=step[@"before"],*target=step[@"target"];
   if([before isEqual:target])continue;
   [touched addObject:step]; // a failed write can already have changed bytes
   NSError *e=nil;BOOL wrote=[self.backend writeAt:op.address bytes:target error:&e];
   NSData *after=[self.backend readAt:op.address length:target.length error:nil];
   if(!wrote||![after isEqual:target]){
    NSString *detail=nil;BOOL restored=[self rollback:touched detail:&detail];
    if(!restored)self.status=ZNV3PatchTransactionStatusRecoveryFailed;
    return [self fail:restored?8:9 message:[NSString stringWithFormat:@"%@ failed: %@; %@",
       op.identifier,e.localizedDescription?:@"readback mismatch",
       restored?@"rollback verified": [NSString stringWithFormat:@"RECOVERY FAILED %@",detail?:@"unknown"]] error:error];
   }
  }
  self.status=enabled?ZNV3PatchTransactionStatusEnabled:ZNV3PatchTransactionStatusDisabled;
  self.active=enabled?[ops copy]:nil;
  self.lastDiagnostic=enabled?@"Verified ON":@"Verified OFF";
  return YES;
 }
}
@end
