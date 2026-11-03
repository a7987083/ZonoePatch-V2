#import "V3StaticBinaryExport.h"
#import "V3StaticBinaryBuilder.h"
#import "V3StaticBuildPlanner.h"
#import "V3PatchSession.h"
#import "ZNAdhocMachOSigner.h"
#import <mach-o/loader.h>
#import <sys/stat.h>
#include <string.h>

static NSError *P6Error(NSInteger code,NSString *reason){
 return [NSError errorWithDomain:@"ZonoePatch.V3.StaticBinaryExport" code:code userInfo:@{NSLocalizedDescriptionKey:reason?:@"Unknown error"}];
}
static BOOL P6CheckStaticArtifact(NSString *path,ZNV3StaticBuildPlan *plan,NSString **reason) {
 NSData *data=[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
 if(!data||data.length<sizeof(struct mach_header_64)){
  if(reason)*reason=@"生成结果为空或不是完整 Mach-O";return NO;
 }
 const uint8_t *p=(const uint8_t *)data.bytes;
 struct mach_header_64 mh={};memcpy(&mh,p,sizeof(mh));
 if(mh.magic!=MH_MAGIC_64||mh.cputype!=CPU_TYPE_ARM64||
    mh.sizeofcmds>data.length-sizeof(mh)){
  if(reason)*reason=@"生成结果 Mach-O Header 不合法";return NO;
 }
 NSUInteger commandOffset=sizeof(mh);
 BOOL haveText=NO,haveData=NO,uuidMatches=NO;
 for(uint32_t i=0;i<mh.ncmds;i++){
  if(commandOffset>data.length||data.length-commandOffset<sizeof(struct load_command)){
   if(reason)*reason=@"生成结果 Load Command 越界";return NO;
  }
  struct load_command lc={};memcpy(&lc,p+commandOffset,sizeof(lc));
  if(lc.cmdsize<sizeof(lc)||lc.cmdsize>data.length-commandOffset){
   if(reason)*reason=@"生成结果 Load Command 长度无效";return NO;
  }
  if(lc.cmd==LC_SEGMENT_64&&lc.cmdsize>=sizeof(struct segment_command_64)){
   struct segment_command_64 seg={};memcpy(&seg,p+commandOffset,sizeof(seg));
   if(!strncmp(seg.segname,"__ZNTEXT",16))haveText=YES;
   if(!strncmp(seg.segname,"__ZNDATA",16))haveData=YES;
  }
  if(lc.cmd==LC_UUID&&lc.cmdsize>=sizeof(struct uuid_command)){
   struct uuid_command uuid={};memcpy(&uuid,p+commandOffset,sizeof(uuid));
   uuidMatches=[[[[NSUUID alloc]initWithUUIDBytes:uuid.uuid] UUIDString] isEqualToString:plan.imageUUID];
  }
  commandOffset+=lc.cmdsize;
 }
 if(!uuidMatches||!haveText||!haveData){
  if(reason)*reason=@"生成结果 UUID 或独立 Static Dispatch Segment 缺失";return NO;
 }
 return YES;
}
@implementation ZNV3StaticBinaryExport
+ (NSString *)generate:(ZNV3StaticBuildPlan *)plan error:(NSError **)error {
 NSError *e=nil;
 if(!plan||![ZNV3StaticBuildPlan validateEntries:plan.entries error:&e]){
  if(error)*error=e?:P6Error(1,@"静态构建计划无效");return nil;
 }
 if([ZNV3PatchSession shared].status!=ZNV3PatchTransactionStatusDisabled){
  if(error)*error=P6Error(2,@"必须先恢复所有 Runtime Patch");return nil;
 }
 NSFileManager *fm=NSFileManager.defaultManager;
 NSString *root=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/ZonoePatchOutput"];
 if(![fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:&e]){
  if(error)*error=e;return nil;
 }
 NSString *token=NSUUID.UUID.UUIDString;
 NSString *stage=[root stringByAppendingPathComponent:[@".p6-staging-" stringByAppendingString:token]];
 NSString *dest=[root stringByAppendingPathComponent:[@"P6-" stringByAppendingString:token]];
 if(![fm createDirectoryAtPath:stage withIntermediateDirectories:NO attributes:nil error:&e]){
  if(error)*error=e;return nil;
 }
 NSString *failure=nil,*generated=nil;
 NSDictionary *metadata=nil,*signature=nil;
 NSString *name=plan.sourcePath.lastPathComponent;
 BOOL ok=NO;
 do {
  if(![ZNV3StaticBinaryBuilder buildPlan:plan inDirectory:stage
        outputPath:&generated metadata:&metadata error:&failure])break;
  if(!ZNAdhocResignMachOAtPath(generated,&signature,&failure))break;
  if(!P6CheckStaticArtifact(generated,plan,&failure))break;
  NSString *finalStageFile=[stage stringByAppendingPathComponent:name];
  if(![fm moveItemAtPath:generated toPath:finalStageFile error:&e]){
   failure=e.localizedDescription;break;
  }
  NSMutableDictionary *safeMetadata=[metadata mutableCopy]?:[NSMutableDictionary dictionary];
  safeMetadata[@"output"]=name;
  NSDictionary *report=@{
   @"schema":@"com.zonoe.v3.static-binary-export",@"version":@1,
   @"binaryGenerated":@YES,@"sourceUUID":plan.imageUUID,
   @"module":plan.module,@"ruleCount":@(plan.entries.count),
   @"output":name,@"builder":safeMetadata,
   @"signature":signature?:@{},@"finalPackageResignRequired":@YES,
   @"runtimeExecutableWrites":@NO
  };
  NSData *reportData=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:&e];
  if(!reportData||![reportData writeToFile:[stage stringByAppendingPathComponent:@"build_report.json"]
          options:NSDataWritingAtomic error:&e]){failure=e.localizedDescription?:@"无法写入报告";break;}
  if([fm fileExistsAtPath:dest]||![fm moveItemAtPath:stage toPath:dest error:&e]){
   failure=e.localizedDescription?:@"构建输出发布失败";break;
  }
  ok=YES;
 }while(0);
 if(!ok){
  [fm removeItemAtPath:stage error:nil];
  if(error)*error=P6Error(3,failure?:@"静态二进制生成失败");
  return nil;
 }
 return [dest stringByAppendingPathComponent:name];
}
@end
