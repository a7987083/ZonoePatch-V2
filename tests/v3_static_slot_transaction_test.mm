#import <Foundation/Foundation.h>
#import "../V3StaticSlotTransaction.h"
static int failed=0;
static void check(BOOL yes,const char *msg){if(!yes){fprintf(stderr,"FAIL: %s\n",msg);failed++;}}
@interface FakeStaticRW : NSObject <ZNV3StaticSlotBackend>
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,NSNumber *> *cells;
@property(nonatomic,assign) NSUInteger writes;
@property(nonatomic,assign) NSUInteger failNthWrite;
@property(nonatomic,assign) BOOL failRollback;
@end
@implementation FakeStaticRW
- (instancetype)init {if((self=[super init]))_cells=[@{@(0x1000):@(0),@(0x2000):@(0)} mutableCopy];return self;}
- (BOOL)readAt:(uintptr_t)addr value:(uint64_t *)out error:(NSError **)err {
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
 FakeStaticRW *dup=[FakeStaticRW new];ZNV3StaticSlotTransaction *dt=[[ZNV3StaticSlotTransaction alloc]initWithBackend:dup];
 check(![dt apply:@[a,a] error:&e]&&dup.writes==0,"duplicate slot rejected without writes");
 }printf("P6 Static Slot Transactions: %s (%d failures)\n",failed?"FAIL":"PASS",failed);return failed?1:0;
}
