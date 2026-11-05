#import "V3StaticFeatureCoordinator.h"

static NSError *ZNFCError(NSInteger code,NSString *reason){
 return [NSError errorWithDomain:@"ZonoePatch.V3.StaticFeatureCoordinator" code:code
  userInfo:@{NSLocalizedDescriptionKey:reason?:@"Static feature failure"}];
}
@implementation ZNV3StaticFeatureSlot
- (instancetype)initWithAddress:(uintptr_t)address offTarget:(uint64_t)offTarget
                      onTarget:(uint64_t)onTarget {
 if((self=[super init])){_address=address;_offTarget=offTarget;_onTarget=onTarget;}
 return self;
}
@end
@interface ZNV3ActiveStaticFeature : NSObject
@property(nonatomic,copy) NSArray<ZNV3StaticFeatureSlot *> *slots;
@property(nonatomic,copy) NSArray<NSNumber *> *previous;
@end
@implementation ZNV3ActiveStaticFeature @end

@interface ZNV3StaticFeatureCoordinator ()
@property(nonatomic,strong) id<ZNV3StaticSlotBackend> backend;
@property(nonatomic,strong) ZNV3StaticSlotTransaction *transaction;
@property(nonatomic,strong) NSMutableDictionary<NSString *,ZNV3ActiveStaticFeature *> *active;
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,NSString *> *owners;
@end
@implementation ZNV3StaticFeatureCoordinator
- (instancetype)initWithBackend:(id<ZNV3StaticSlotBackend>)backend{
 if((self=[super init])){
  _backend=backend;
  _transaction=[[ZNV3StaticSlotTransaction alloc]initWithBackend:backend];
  _active=[NSMutableDictionary dictionary];_owners=[NSMutableDictionary dictionary];
 }
 return self;
}
- (BOOL)recoveryFailed{return self.transaction.recoveryFailed;}
- (NSString *)lastDiagnostic{return self.transaction.lastDiagnostic;}
- (BOOL)hasActiveFeature{@synchronized(self){return self.active.count>0;}}
- (BOOL)isEnabledForFeature:(NSString *)identifier{
 @synchronized(self){return identifier.length&&self.active[identifier]!=nil&&!self.recoveryFailed;}
}
- (BOOL)setEnabled:(BOOL)enabled featureID:(NSString *)identifier
             slots:(NSArray<ZNV3StaticFeatureSlot *> *)slots error:(NSError **)error {
 @synchronized(self){
  if(self.recoveryFailed){
   if(error)*error=ZNFCError(1,@"静态 Slot 回滚失败，全局执行已锁定");return NO;
  }
  if(!identifier.length||!slots.count||slots.count>128){
   if(error)*error=ZNFCError(2,@"静态功能 ID 或 Slot 数量无效");return NO;
  }
  ZNV3ActiveStaticFeature *old=self.active[identifier];
  if((enabled&&old)||(!enabled&&!old)){
   if(error)*error=ZNFCError(3,enabled?@"功能已启用":@"功能没有可恢复的活动事务");
   return NO;
  }
  if(!enabled&&old.slots.count!=slots.count){
   if(error)*error=ZNFCError(4,@"活动功能 Slot 数量已变化");return NO;
  }
  NSMutableSet<NSNumber *> *seen=[NSMutableSet set];
  NSMutableArray<ZNV3StaticSlotOperation *> *operations=[NSMutableArray array];
  NSMutableArray<NSNumber *> *previous=[NSMutableArray array];
  for(NSUInteger i=0;i<slots.count;i++){
   ZNV3StaticFeatureSlot *slot=slots[i];
   NSNumber *address=@(slot.address);
   if(!slot.address||(slot.address&7)||[seen containsObject:address]||
      !slot.offTarget||!slot.onTarget||slot.offTarget==slot.onTarget){
    if(error)*error=ZNFCError(5,@"重复、无效或未对齐的 Static Slot");return NO;
   }
   [seen addObject:address];
   NSString *owner=self.owners[address];
   if(enabled){
    if(owner){
     if(error)*error=ZNFCError(6,@"此 Slot 已被活动功能持有，拒绝重复所有权");return NO;
    }
   }else{
    ZNV3StaticFeatureSlot *snapshot=old.slots[i];
    if(![owner isEqualToString:identifier]||
       snapshot.address!=slot.address||
       snapshot.onTarget!=slot.onTarget||
       snapshot.offTarget!=slot.offTarget){
     if(error)*error=ZNFCError(7,@"静态功能 Slot 归属或恢复身份已变化");return NO;
    }
   }
  }
  // No transactions can begin before all ownership checks succeed.
  for(NSUInteger i=0;i<slots.count;i++){
   ZNV3StaticFeatureSlot *slot=slots[i];uint64_t before=0;
   if(![self.backend readAt:slot.address value:&before error:error])return NO;
   if(enabled){
    if(before!=0&&before!=slot.offTarget){
     if(error)*error=ZNFCError(8,@"静态 Slot 已被其他写入者修改");return NO;
    }
    [previous addObject:@(before)];
    [operations addObject:[[ZNV3StaticSlotOperation alloc]
      initWithAddress:slot.address expected:before desired:slot.onTarget]];
   }else{
    if(before!=slot.onTarget){
     if(error)*error=ZNFCError(9,@"静态 Slot 不在预期 ON 状态");return NO;
    }
    uint64_t prior=old.previous[i].unsignedLongLongValue;
    if(prior!=0&&prior!=slot.offTarget){
     if(error)*error=ZNFCError(10,@"活动事务的 Original Slot 快照无效");return NO;
    }
    [operations addObject:[[ZNV3StaticSlotOperation alloc]
      initWithAddress:slot.address expected:before desired:prior]];
   }
  }
  if(![self.transaction apply:operations error:error])return NO;
  if(enabled){
   ZNV3ActiveStaticFeature *session=[ZNV3ActiveStaticFeature new];
   session.slots=[slots copy];session.previous=[previous copy];
   self.active[identifier]=session;
   for(ZNV3StaticFeatureSlot *slot in slots)self.owners[@(slot.address)]=identifier;
  }else{
   [self.active removeObjectForKey:identifier];
   for(ZNV3StaticFeatureSlot *slot in slots)[self.owners removeObjectForKey:@(slot.address)];
  }
  return YES;
 }
}
@end
