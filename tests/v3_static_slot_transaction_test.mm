#import <Foundation/Foundation.h>
#import "../V3StaticSlotTransaction.h"
static int failed=0;
static void check(BOOL yes,const char *msg){if(!yes){fprintf(stderr,"FAIL: %s\n",msg);failed++;}}
@interface FakeStaticRW : NSObject <ZNV3StaticSlotBackend>
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,NSNumber *> *cells;
@property(nonatomic,assign) NSUInteger writes;
@property(nonatomic,assign) NSUInteger failNthWrite;
@property(nonatomic,assign) BOOL failRollback;
@property(nonatomic,assign) uintptr_t interfereAt;
@property(nonatomic,assign) NSUInteger readCountAtInterference;
@property(nonatomic,assign) uint64_t interferenceValue;
@end
@implementation FakeStaticRW
- (instancetype)init {if((self=[super init]))_cells=[@{@(0x1000):@(0),@(0x2000):@(0),@(0x3000):@(0)} mutableCopy];return self;}
- (BOOL)readAt:(uintptr_t)addr value:(uint64_t *)out error:(NSError **)err {
 if(addr==self.interfereAt && ++self.readCountAtInterference==2)
  self.cells[@(addr)]=@(self.interferenceValue);
 NSNumber *v=self.cells[@(addr)];if(!v)return NO;*out=v.unsignedLongLongValue;return YES;
}
- (BOOL)writeAt:(uintptr_t)addr value:(uint64_t)value error:(NSError **)err {
 self.writes++;
 if(self.failNthWrite==self.writes || (self.failRollback&&value==0&&self.writes>=3)){
  if(err)*err=[NSError errorWithDomain:@"Fake" code:3 userInfo:@{NSLocalizedDescriptionKey:@"injected write failure"}];return NO;
 }
 self.cells[@(addr)]=@(value);return YES;
}
@end
int main() {@autoreleasepool{
 ZNV3StaticSlotOperation *a=[[ZNV3StaticSlotOperation alloc]initWithAddress:0x1000 expected:0 desired:0xA100];
 ZNV3StaticSlotOperation *b=[[ZNV3StaticSlotOperation alloc]initWithAddress:0x2000 expected:0 desired:0xA200];
 NSError *e=nil;
 FakeStaticRW *normal=[FakeStaticRW new];ZNV3StaticSlotTransaction *tx=[[ZNV3StaticSlotTransaction alloc]initWithBackend:normal];
 check([tx apply:@[a,b] error:&e],"two slots enable atomically");
 check([normal.cells[@(0x1000)] unsignedLongLongValue]==0xA100 && [normal.cells[@(0x2000)] unsignedLongLongValue]==0xA200,"both committed");
 check(![tx apply:@[a,b] error:&e],"stale Expected refuses write");
 check(normal.writes==2,"preflight mismatch has zero writes");
 ZNV3StaticSlotOperation *undoA=[[ZNV3StaticSlotOperation alloc]initWithAddress:0x1000 expected:0xA100 desired:0];
 ZNV3StaticSlotOperation *undoB=[[ZNV3StaticSlotOperation alloc]initWithAddress:0x2000 expected:0xA200 desired:0];
 check([tx apply:@[undoA,undoB] error:&e],"restore Original slots");
 check([normal.cells[@(0x1000)] unsignedLongLongValue]==0,"restored");
 FakeStaticRW *rollback=[FakeStaticRW new];rollback.failNthWrite=2;
 ZNV3StaticSlotTransaction *rt=[[ZNV3StaticSlotTransaction alloc]initWithBackend:rollback];
 check(![rt apply:@[a,b] error:&e],"injected second write fails");
 check([rollback.cells[@(0x1000)] unsignedLongLongValue]==0 && [rollback.cells[@(0x2000)] unsignedLongLongValue]==0,"reverse rollback restores all");
 check(!rt.recoveryFailed,"verified rollback is recoverable");
 FakeStaticRW *latch=[FakeStaticRW new];latch.failNthWrite=2;latch.failRollback=YES;
 ZNV3StaticSlotTransaction *lt=[[ZNV3StaticSlotTransaction alloc]initWithBackend:latch];
 check(![lt apply:@[a,b] error:&e],"injected rollback failure caught");
 check(lt.recoveryFailed,"rollback failure latches");
 NSUInteger before=latch.writes;
 check(![lt apply:@[a,b] error:&e]&&before==latch.writes,"recovery lock blocks writes");
 // D06: writer B races after global preflight, before B's own write.
 // Transaction must not overwrite B's external value, and must undo A.
 FakeStaticRW *race=[FakeStaticRW new];race.interfereAt=0x2000;
 race.interferenceValue=0xDEAD;
 ZNV3StaticSlotTransaction *raceTx=[[ZNV3StaticSlotTransaction alloc]initWithBackend:race];
 check(![raceTx apply:@[a,b] error:&e],"intervening slot writer rejected");
 check([race.cells[@(0x1000)] unsignedLongLongValue]==0 &&
       [race.cells[@(0x2000)] unsignedLongLongValue]==0xDEAD,
       "owned A rollback, external B value left untouched");
 check(!raceTx.recoveryFailed,"race with recoverable rollback does not lock");
 // Failure while rolling back a race must fail closed.
 FakeStaticRW *raceLatch=[FakeStaticRW new];raceLatch.interfereAt=0x2000;
 raceLatch.interferenceValue=0xDEAD;raceLatch.failNthWrite=2;
 ZNV3StaticSlotTransaction *raceLatchTx=[[ZNV3StaticSlotTransaction alloc]
   initWithBackend:raceLatch];
 check(![raceLatchTx apply:@[a,b] error:&e],"intervening race with failed rollback rejected");
 check(raceLatchTx.recoveryFailed,"race rollback failure locks execution");
 // P9.2: two feature groups: A owns two slots, B owns one.
 // Switching B must not touch A; a failed A transaction must roll back A only.
 FakeStaticRW *groups=[FakeStaticRW new];
 ZNV3StaticSlotTransaction *gt=[[ZNV3StaticSlotTransaction alloc]initWithBackend:groups];
 ZNV3StaticSlotOperation *bOnly=[[ZNV3StaticSlotOperation alloc]
   initWithAddress:0x3000 expected:0 desired:0xB300];
 check([gt apply:@[bOnly] error:&e],"P9 B can be enabled independently");
 check([groups.cells[@(0x1000)] unsignedLongLongValue]==0 &&
       [groups.cells[@(0x2000)] unsignedLongLongValue]==0 &&
       [groups.cells[@(0x3000)] unsignedLongLongValue]==0xB300,
       "P9 enabling B leaves A unchanged");
 groups.writes=0;groups.failNthWrite=2;
 check(![gt apply:@[a,b] error:&e],"P9 fault in A second slot rejects A");
 check([groups.cells[@(0x1000)] unsignedLongLongValue]==0 &&
       [groups.cells[@(0x2000)] unsignedLongLongValue]==0 &&
       [groups.cells[@(0x3000)] unsignedLongLongValue]==0xB300,
       "P9 A rollback preserves active B");
 check(!gt.recoveryFailed,"P9 recovered A failure does not latch B");
 groups.failNthWrite=0;
 check([gt apply:@[a,b] error:&e],"P9 enable A alongside active B");
 check([groups.cells[@(0x1000)] unsignedLongLongValue]==0xA100 &&
       [groups.cells[@(0x2000)] unsignedLongLongValue]==0xA200 &&
       [groups.cells[@(0x3000)] unsignedLongLongValue]==0xB300,
       "P9 A and B both independently ON");
 check([gt apply:@[undoA,undoB] error:&e],"P9 disable A without changing B");
 check([groups.cells[@(0x1000)] unsignedLongLongValue]==0 &&
       [groups.cells[@(0x2000)] unsignedLongLongValue]==0 &&
       [groups.cells[@(0x3000)] unsignedLongLongValue]==0xB300,
       "P9 B still ON after A OFF");
 ZNV3StaticSlotOperation *bOff=[[ZNV3StaticSlotOperation alloc]
   initWithAddress:0x3000 expected:0xB300 desired:0];
 check([gt apply:@[bOff] error:&e],"P9 disable B independently");
 check([groups.cells[@(0x3000)] unsignedLongLongValue]==0,
       "P9 independent group restore returns to OFF");
  FakeStaticRW *dup=[FakeStaticRW new];ZNV3StaticSlotTransaction *dt=[[ZNV3StaticSlotTransaction alloc]initWithBackend:dup];
 check(![dt apply:@[a,a] error:&e]&&dup.writes==0,"duplicate slot rejected without writes");
 }printf("P6 Static Slot Transactions: %s (%d failures)\n",failed?"FAIL":"PASS",failed);return failed?1:0;
}
