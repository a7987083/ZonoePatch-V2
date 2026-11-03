#import "V3PatchSession.h"
#import "V3PatchValidator.h"
#import "V3AddressResolver.h"
#import "V3FeatureModels.h"
#import "V3RuntimeBytesBackend.h"
#import <fcntl.h>
#import <sys/stat.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>

static NSError *ZNSessionError(NSInteger code, NSString *message) {
 return [NSError errorWithDomain:@"ZonoePatch.V3.PatchSession" code:code userInfo:@{NSLocalizedDescriptionKey:message}];
}
/// The initial Expected must come from the current on-disk Mach-O, never only the live snapshot.
static BOOL ZNVerifyOriginalOnDisk(ZNV3PatchValidation *validation, NSError **error) {
 ZNV3ResolvedAddress *addr=validation.address;
 NSData *expected=validation.originalBytes;
 if(!addr.imagePath.length||!expected.length||
    addr.fileOffset>INT64_MAX||expected.length>(uint64_t)(INT64_MAX-addr.fileOffset)) {
  if(error)*error=ZNSessionError(1,@"Original 文件偏移或长度无效");return NO;
 }
 int fd=open(addr.imagePath.fileSystemRepresentation,O_RDONLY|O_CLOEXEC);
 if(fd<0){if(error)*error=ZNSessionError(2,[NSString stringWithFormat:@"无法打开 Mach-O 文件：%s",strerror(errno)]);return NO;}
 struct stat st={};BOOL ok=NO;NSMutableData *onDisk=[NSMutableData dataWithLength:expected.length];
 if(fstat(fd,&st)==0 && st.st_size>=0 &&
    addr.fileOffset<=(uint64_t)st.st_size &&
    expected.length<=(uint64_t)st.st_size-addr.fileOffset) {
  ssize_t n=pread(fd,onDisk.mutableBytes,expected.length,(off_t)addr.fileOffset);
  ok=n==(ssize_t)expected.length && [onDisk isEqualToData:expected];
 }
 close(fd);
 if(!ok&&error)*error=ZNSessionError(3,@"现场 Original 与已加载模块磁盘字节不一致，拒绝未知版本或已修改的代码");
 return ok;
}

@interface ZNV3PatchSession ()
@property(nonatomic,strong) ZNV3RuntimePatchExecutor *executor;
@property(nonatomic,copy,readwrite) NSString *activeFeatureID;
@property(nonatomic,copy) NSArray<ZNV3PatchOperation *> *activeOperations;
@end
@implementation ZNV3PatchSession
+ (instancetype)shared {
 static ZNV3PatchSession *instance;
 static dispatch_once_t once;dispatch_once(&once,^{instance=[self new];});
 return instance;
}
- (instancetype)init {
 if((self=[super init]))_executor=[[ZNV3RuntimePatchExecutor alloc]initWithBackend:[ZNV3RuntimeBytesBackend new]];
 return self;
}
- (ZNV3PatchTransactionStatus)status {return self.executor.status;}
- (NSString *)lastDiagnostic {return self.executor.lastDiagnostic;}
- (BOOL)isActiveFeature:(NSString *)identifier {
 @synchronized(self){return self.status==ZNV3PatchTransactionStatusEnabled &&
   identifier.length && [self.activeFeatureID isEqualToString:identifier];}
}
- (BOOL)applyFeature:(ZNV3Feature *)feature error:(NSError **)error {
 @synchronized(self) {
  if(self.status!=ZNV3PatchTransactionStatusDisabled){
   if(error)*error=ZNSessionError(4,self.status==ZNV3PatchTransactionStatusRecoveryFailed?
     @"前次回滚失败，已锁定运行时写入":@"已有其他功能的 Patch 生效，请先恢复");
   return NO;
  }
  if(!feature.identifier.length||!feature.module.length){
   if(error)*error=ZNSessionError(5,@"功能尚未保存或模块未选择");return NO;
  }
  NSMutableArray<ZNV3PatchOperation *> *ops=[NSMutableArray array];
  for(ZNV3PatchRule *rule in feature.rules){
   if(!rule.offsetText.length&&!rule.patchText.length)continue;
   NSError *e=nil;
   ZNV3PatchValidation *v=[ZNV3PatchValidator validateOffset:rule.offsetText patch:rule.patchText module:feature.module error:&e];
   if(!v){if(error)*error=e?:ZNSessionError(6,@"只读验证失败");return NO;}
   if(!ZNVerifyOriginalOnDisk(v,&e)){if(error)*error=e;return NO;}
   ZNV3ResolvedAddress *a=v.address;
   ZNV3PatchOperation *op=[[ZNV3PatchOperation alloc]initWithIdentifier:rule.identifier
      moduleUUID:a.imageUUID address:(uintptr_t)a.runtimeVA
      expected:v.originalBytes patch:v.patchBytes];
   [ops addObject:op];
  }
  if(!ops.count){if(error)*error=ZNSessionError(7,@"至少需要一组完整的 Offset / Patch");return NO;}
  if(![self.executor setEnabled:YES operations:ops error:error])return NO;
  self.activeFeatureID=feature.identifier;
  self.activeOperations=[ops copy];
  return YES;
 }
}
- (BOOL)restoreFeature:(NSString *)identifier error:(NSError **)error {
 @synchronized(self){
  if(self.status==ZNV3PatchTransactionStatusRecoveryFailed){
   if(error)*error=ZNSessionError(8,@"恢复曾失败，执行器已锁定；不能宣称已恢复 Original");return NO;
  }
  if(self.status!=ZNV3PatchTransactionStatusEnabled ||
     !identifier.length || ![self.activeFeatureID isEqualToString:identifier] ||
     !self.activeOperations.count) {
   if(error)*error=ZNSessionError(9,@"当前功能没有可恢复的活动补丁");return NO;
  }
  if(![self.executor setEnabled:NO operations:self.activeOperations error:error])return NO;
  self.activeFeatureID=nil;
  self.activeOperations=nil;
  return YES;
 }
}
@end
