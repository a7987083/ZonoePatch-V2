#import <Foundation/Foundation.h>
#import "../V3StaticFeatureCoordinator.h"
static int failures=0;
static void check(BOOL ok,const char *name){
 if(!ok){fprintf(stderr,"FAIL: %s\n",name);failures++;}
}
@interface FakeSlots : NSObject <ZNV3StaticSlotBackend>
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,NSNumber *> *values;
@property(nonatomic,assign) NSUInteger writes;
@property(nonatomic,assign) NSUInteger failAtWrite;
@property(nonatomic,assign) BOOL failRollback;
@end
@implementation FakeSlots
- (instancetype)init{
 if((self=[super init]))_values=[@{@(0x1000):@0,@(0x2000):@0,@(0x3000):@0} mutableCopy];
 return self;
}
- (BOOL)readAt:(uintptr_t)a value:(uint64_t *)v error:(NSError **)error{
 NSNumber *x=self.values[@(a)];
 if(!x){if(error)*error=[NSError errorWithDomain:@"Fake" code:1 userInfo:nil];return NO;}
 *v=x.unsignedLongLongValue;return YES;
}
- (BOOL)writeAt:(uintptr_t)a value:(uint64_t)v error:(NSError **)error{
 self.writes++;
 if(self.writes==self.failAtWrite||(self.failRollback&&v==0&&self.writes>2)){
  if(error)*error=[NSError errorWithDomain:@"Fake" code:2 userInfo:nil];return NO;
 }
 self.values[@(a)]=@(v);return YES;
}
@end
static ZNV3StaticFeatureSlot *slot(uintptr_t address,uint64_t off,uint64_t on){
 return [[ZNV3StaticFeatureSlot alloc]initWithAddress:address offTarget:off onTarget:on];
}
int main(){@autoreleasepool{
 FakeSlots *b=[FakeSlots new];
 ZNV3StaticFeatureCoordinator *c=[[ZNV3StaticFeatureCoordinator alloc]initWithBackend:b];
 NSArray *a=@[slot(0x1000,0xA000,0xA100),slot(0x2000,0xB000,0xB100)];
 NSArray *other=@[slot(0x3000,0xC000,0xC100)];
 NSError *err=nil;
 check([c setEnabled:YES featureID:@"A" slots:a error:&err],"enable feature A");
 check(c.hasActiveFeature&&[c isEnabledForFeature:@"A"],"A status active");
 check([c setEnabled:YES featureID:@"B" slots:other error:&err],"enable independent feature B");
 check([c isEnabledForFeature:@"A"]&&[c isEnabledForFeature:@"B"],
       "two independent features active");
 NSUInteger before=b.writes;
 check(![c setEnabled:YES featureID:@"C" slots:@[slot(0x2000,0xB000,0xB100)]
                 error:&err]&&b.writes==before,"reject another owner for active slot");
 check(![c setEnabled:YES featureID:@"A" slots:a error:&err]&&b.writes==before,
       "reject duplicate enable with no writes");
 check([c setEnabled:NO featureID:@"A" slots:a error:&err],"disable A only");
 check(![c isEnabledForFeature:@"A"]&&[c isEnabledForFeature:@"B"]&&
       [b.values[@(0x3000)] unsignedLongLongValue]==0xC100,"B remains enabled");
 check([c setEnabled:NO featureID:@"B" slots:other error:&err],"disable B only");
 check(!c.hasActiveFeature,"last feature restored");
 check([b.values[@(0x1000)] unsignedLongLongValue]==0&&
       [b.values[@(0x3000)] unsignedLongLongValue]==0,"original zero restored");
 // Preserve a nonzero OFF pointer (not just zero) over unrelated toggles.
 b.values[@(0x1000)]=@(0xA000);
 check([c setEnabled:YES featureID:@"A" slots:a error:&err],"enable with canonical OFF");
 check(![c setEnabled:NO featureID:@"A" slots:@[slot(0x1000,0xA000,0xA200),a[1]]
                 error:&err],"reject changed active code identity");
 check([c isEnabledForFeature:@"A"],"identity mismatch leaves A active");
 check([c setEnabled:NO featureID:@"A" slots:a error:&err],"restore saved identity");
 check([b.values[@(0x1000)] unsignedLongLongValue]==0xA000,"canonical OFF restored exactly");
 // A partial write error rolls back A and must not mutate active B.
 FakeSlots *f=[FakeSlots new];
 ZNV3StaticFeatureCoordinator *fc=[[ZNV3StaticFeatureCoordinator alloc]initWithBackend:f];
 check([fc setEnabled:YES featureID:@"B" slots:other error:&err],"setup B for isolation");
 f.writes=0;f.failAtWrite=2;
 check(![fc setEnabled:YES featureID:@"A" slots:a error:&err],"A partial failure rejected");
 check([fc isEnabledForFeature:@"B"]&&![fc isEnabledForFeature:@"A"]&&
       [f.values[@(0x1000)] unsignedLongLongValue]==0&&
       [f.values[@(0x3000)] unsignedLongLongValue]==0xC100,
       "A rollback leaves B owner and bytes intact");
 f.failAtWrite=0;
 check([fc setEnabled:YES featureID:@"A" slots:a error:&err],"A retry succeeds");
 check([fc setEnabled:NO featureID:@"B" slots:other error:&err],"B independent restore");
 check([fc setEnabled:NO featureID:@"A" slots:a error:&err],"A independent restore");
 // Any failed rollback forces a global lock while preserving session metadata.
 FakeSlots *g=[FakeSlots new];
 ZNV3StaticFeatureCoordinator *gc=[[ZNV3StaticFeatureCoordinator alloc]initWithBackend:g];
 g.failAtWrite=2;g.failRollback=YES;
 check(![gc setEnabled:YES featureID:@"A" slots:a error:&err],"injected rollback failure");
 check(gc.recoveryFailed,"recovery latch propagated");
 before=g.writes;
 check(![gc setEnabled:YES featureID:@"B" slots:other error:&err]&&g.writes==before,
       "recovery latch forbids other feature writes");
}printf("P10.5.1 Developer Static Feature Ownership: %s (%d failures)\n",
 failures?"FAIL":"PASS",failures);return failures?1:0;}
