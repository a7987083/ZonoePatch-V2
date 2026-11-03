#import "V3StaticBinaryExport.h"
#import "V3StaticBinaryBuilder.h"
#import "V3StaticBuildPlanner.h"
#import "V3PatchSession.h"
#import "ZNAdhocMachOSigner.h"
#import "ZNStaticPatchFormat.h"
#import <mach-o/loader.h>
#import <sys/stat.h>
#include <string.h>

static NSError *P6Error(NSInteger code,NSString *reason){
 return [NSError errorWithDomain:@"ZonoePatch.V3.StaticBinaryExport" code:code userInfo:@{NSLocalizedDescriptionKey:reason?:@"Unknown error"}];
}
static NSData *P9FixedUTF8(NSString *value,NSUInteger capacity) {
 NSData *source=[value dataUsingEncoding:NSUTF8StringEncoding];
 if(!source.length||capacity==0)return [NSData data];
 NSUInteger length=MIN(capacity-1,source.length);
 while(length>0 && ![[NSString alloc]initWithBytes:source.bytes length:length encoding:NSUTF8StringEncoding])
  length--;
 return [source subdataWithRange:NSMakeRange(0,length)];
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
 uint64_t tableOffset=UINT64_MAX,tableSize=0;
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
   if(!strncmp(seg.segname,"__ZNDATA",16)){
    haveData=YES;tableOffset=seg.fileoff;tableSize=seg.filesize;
   }
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
 // P9 acceptance: do not report success merely because the segments exist.
 // Verify every emitted row against the immutable selected BuildPlan.
 const uint64_t needed=sizeof(ZN44StaticHeader)+(uint64_t)plan.entries.count*sizeof(ZN44StaticEntry);
 if(tableOffset==UINT64_MAX||tableOffset>data.length||
    tableSize<needed||tableSize>data.length-tableOffset){
  if(reason)*reason=@"生成结果 Static Dispatch Table 越界";return NO;
 }
 ZN44StaticHeader header={};
 memcpy(&header,p+(NSUInteger)tableOffset,sizeof(header));
 BOOL multi=plan.featureCount>1;
 if(header.magic0!=ZN44_STATIC_MAGIC0||header.magic1!=ZN44_STATIC_MAGIC1||
    header.version!=ZN44_STATIC_VERSION_V2||
    header.entrySize!=sizeof(ZN44StaticEntry)||
    header.count!=plan.entries.count||
    ((header.flags&ZN44_STATIC_HEADER_FLAG_MULTI_FEATURE_V1)!=0)!=multi){
  if(reason)*reason=@"生成规则数量或多功能标记与选中功能不一致";return NO;
 }
 NSMutableSet<NSString *> *owners=[NSMutableSet set];
 for(NSUInteger i=0;i<plan.entries.count;i++){
  ZN44StaticEntry row={};
  memcpy(&row,p+(NSUInteger)tableOffset+sizeof(header)+i*sizeof(row),sizeof(row));
  ZNV3StaticBuildEntry *expected=plan.entries[i];
  NSString *title=multi?expected.featureName:plan.featureName;
  NSString *owner=multi?[expected.featureKey substringToIndex:MIN((NSUInteger)23,expected.featureKey.length)]:nil;
  // The entry ABI uses fixed UTF-8 fields. Reproduce the builder's truncation
  // through bounded prefix checks rather than accepting an arbitrary title.
  NSData *titleBytes=P9FixedUTF8(title,sizeof(row.title));
  NSData *ownerBytes=P9FixedUTF8(owner,sizeof(row.group));
  NSUInteger tlen=titleBytes.length;
  NSUInteger olen=ownerBytes.length;
  if(row.patchID!=i+1||row.canonicalIndex!=i||row.physicalID!=i+1||
     !(row.flags&ZN44_STATIC_ENTRY_FLAG_CANONICAL)||
     row.selectedTarget!=0||!titleBytes.length||
     memcmp(row.title,titleBytes.bytes,tlen)!=0||row.title[tlen]!=0||
     (multi&&(!ownerBytes.length||memcmp(row.group,ownerBytes.bytes,olen)!=0||
      row.group[olen]!=0))){
   if(reason)*reason=[NSString stringWithFormat:@"第 %lu 条规则的功能归属或 OFF 状态与构建计划不一致",(unsigned long)(i+1)];
   return NO;
  }
  if(multi)[owners addObject:[NSString stringWithUTF8String:row.group]?:@""];
 }
 if(multi&&owners.count!=plan.featureCount){
  if(reason)*reason=@"生成结果功能组数量与选中数量不一致";return NO;
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
   @"module":plan.module,@"featureCount":@(plan.featureCount),
   @"selectedFeatures":[[plan manifest] objectForKey:@"rules"]?:@[],
   @"ruleCount":@(plan.entries.count),
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
