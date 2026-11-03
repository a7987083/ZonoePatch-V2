#import <Foundation/Foundation.h>
#import "../V3RuntimePatchExecutor.h"
#include <stdint.h>
#include <string.h>
static int bad=0;
static void expect(BOOL ok,const char *msg){if(!ok){fprintf(stderr,"FAIL %s\n",msg);bad++;}}
@interface FakeBackend : NSObject <ZNV3PatchMemoryBackend>
@property(nonatomic,strong) NSMutableData *memory;
@property(nonatomic,assign) NSInteger writeCount;
@property(nonatomic,assign) NSInteger failOnWrite;
@property(nonatomic,assign) BOOL partialFailure;
@property(nonatomic,assign) BOOL failRollback;
@property(nonatomic,assign) BOOL rejectIdentity;
@end
@implementation FakeBackend
- (instancetype)init {if((self=[super init])){_memory=[NSMutableData dataWithLength:128];}return self;}
- (BOOL)validateOperation:(ZNV3PatchOperation *)operation error:(NSError **)error{
 (void)operation;(void)error;return !self.rejectIdentity;
}
- (NSData *)readAt:(uintptr_t)address length:(NSUInteger)length error:(NSError **)error{
 if(address>128||length>128-address){if(error)*error=[NSError errorWithDomain:@"fake" code:1 userInfo:nil];return nil;}
 return [self.memory subdataWithRange:NSMakeRange(address,length)];
}
- (BOOL)writeAt:(uintptr_t)address bytes:(NSData *)bytes error:(NSError **)error{
 self.writeCount++;
 if(address>128||bytes.length>128-address)return NO;
 if(self.failRollback&&self.writeCount>=2)return NO;
 if(self.failOnWrite&&self.writeCount==self.failOnWrite){
  if(self.partialFailure)memcpy((uint8_t *)self.memory.mutableBytes+address,bytes.bytes,bytes.length);
  if(error)*error=[NSError errorWithDomain:@"fake" code:7 userInfo:nil];
  return NO;
 }
 memcpy((uint8_t *)self.memory.mutableBytes+address,bytes.bytes,bytes.length);
 return YES;
}
@end
static ZNV3PatchOperation *op(NSString *ident,uintptr_t addr){
 uint8_t orig[]={0x11,0x22,0x33,0x44},patch[]={0xAA,0xBB,0xCC,0xDD};
 return [[ZNV3PatchOperation alloc]initWithIdentifier:ident moduleUUID:@"test-uuid" address:addr
 expected:[NSData dataWithBytes:orig length:4] patch:[NSData dataWithBytes:patch length:4]];
}
static void reset(FakeBackend *b,uintptr_t a,uintptr_t c){
 const uint8_t original[]={0x11,0x22,0x33,0x44};
 memcpy((uint8_t *)b.memory.mutableBytes+a,original,4);
 memcpy((uint8_t *)b.memory.mutableBytes+c,original,4);
}
static BOOL original(FakeBackend *b,uintptr_t a){
 const uint8_t original[]={0x11,0x22,0x33,0x44};
 return memcmp((uint8_t *)b.memory.mutableBytes+a,original,4)==0;
}
int main(){
 @autoreleasepool{
  FakeBackend *b=[FakeBackend new];reset(b,8,24);
  ZNV3RuntimePatchExecutor *ex=[[ZNV3RuntimePatchExecutor alloc]initWithBackend:b];
  NSArray *actions=@[op(@"a",8),op(@"b",24)];NSError *err=nil;
  expect([ex setEnabled:YES operations:actions error:&err],"ON transaction");
  expect(ex.status==ZNV3PatchTransactionStatusEnabled,"status ON");
  expect([ex setEnabled:YES operations:actions error:&err],"idempotent ON");
  expect(![ex setEnabled:YES operations:@[op(@"other",8)] error:&err],"block unrelated active");
  expect([ex setEnabled:NO operations:actions error:&err],"OFF transaction");
  expect(original(b,8)&&original(b,24),"OFF readback");
  expect(ex.status==ZNV3PatchTransactionStatusDisabled,"status OFF");
  expect(![ex setEnabled:NO operations:actions error:&err],"OFF without session denied");
  expect(![ex setEnabled:YES operations:@[op(@"a",8),op(@"overlap",8)] error:&err],"overlap rejected");
  uint8_t original4[]={0x11,0x22,0x33,0x44};
  NSData *same=[NSData dataWithBytes:original4 length:4];
  ZNV3PatchOperation *noOp=[[ZNV3PatchOperation alloc]initWithIdentifier:@"noop" moduleUUID:@"test-uuid"
     address:8 expected:same patch:same];
  expect(![ex setEnabled:YES operations:@[noOp] error:&err],"reject no-op patch definition");

  ((uint8_t *)b.memory.mutableBytes)[8]=0x00;
  expect(![ex setEnabled:YES operations:actions error:&err],"expected mismatch blocks all");
  expect(original(b,24),"preflight did not modify second site");
  reset(b,8,24);
  b.rejectIdentity=YES;
  expect(![ex setEnabled:YES operations:actions error:&err],"identity failure blocks writes");
  expect(original(b,8)&&original(b,24),"identity failure does not mutate memory");
  b.rejectIdentity=NO;
  b.writeCount=0;b.failOnWrite=2;b.partialFailure=YES;
  expect(![ex setEnabled:YES operations:actions error:&err],"partial write failure detected");
  expect(original(b,8)&&original(b,24),"failed write and prior site restored");
  expect(ex.status==ZNV3PatchTransactionStatusDisabled,"rollback status OFF");
  b.writeCount=0;b.failOnWrite=2;b.failRollback=YES;
  reset(b,8,24);
  expect(![ex setEnabled:YES operations:actions error:&err],"rollback failure detected");
  expect(ex.status==ZNV3PatchTransactionStatusRecoveryFailed,"latch recovery failed");
  b.failRollback=NO;b.failOnWrite=0;
  expect(![ex setEnabled:YES operations:actions error:&err],"latch blocks further operations");
 }
 printf("Executor transaction tests %s (%d errors)\n",bad?"FAIL":"PASS",bad);
 return bad?1:0;
}
