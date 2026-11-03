#import "V3ConfigRepository.h"
#import "V3FeatureModels.h"
#import "V3AddressResolver.h"
#import "V3PatchCodec.h"

static NSString * const ZNErrorDomain=@"ZonoePatch.V3.Config";
static NSError *ZNError(NSInteger code,NSString *description) {
 return [NSError errorWithDomain:ZNErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:description}];
}
// Keep storage and runtime input semantics identical. Blank rules are allowed only as empty pairs.
static BOOL ZNValidRule(NSString *offset, NSString *patch) {
 if(![offset isKindOfClass:NSString.class]||![patch isKindOfClass:NSString.class])return NO;
 if(!offset.length&&!patch.length)return YES;
 return [ZNV3AddressResolver validAlignedCodeOffsetText:offset] &&
        [ZNV3PatchCodec isValidCodeText:patch];
}
@implementation ZNV3ConfigRepository
- (NSURL *)fileURL:(NSError **)error {
 NSURL *dir=[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
 if(!dir) {if(error)*error=ZNError(1,@"App Support 路径不可用");return nil;}
 dir=[dir URLByAppendingPathComponent:@"ZonoePatchV3" isDirectory:YES];
 if(![[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:error])return nil;
 return [dir URLByAppendingPathComponent:@"features-v1.json"];
}
- (NSArray<ZNV3Feature *> *)loadFeatures:(NSError **)error {
 NSURL *url=[self fileURL:error];if(!url)return nil;
 if(![[NSFileManager defaultManager] fileExistsAtPath:url.path])return @[];
 NSData *data=[NSData dataWithContentsOfURL:url options:0 error:error];if(!data)return nil;
 id root=[NSJSONSerialization JSONObjectWithData:data options:0 error:error];
 if(![root isKindOfClass:NSDictionary.class]){if(error)*error=ZNError(2,@"配置根结构错误");return nil;}
 NSDictionary *doc=root;
 if(![doc[@"schemaVersion"] isKindOfClass:NSNumber.class] || [doc[@"schemaVersion"] integerValue]!=1){
  if(error)*error=ZNError(3,@"配置 Schema 版本不支持");return nil;
 }
 NSArray *entries=doc[@"features"];
 if(![entries isKindOfClass:NSArray.class]||entries.count>1000){if(error)*error=ZNError(4,@"功能列表格式错误");return nil;}
 NSMutableArray *result=[NSMutableArray arrayWithCapacity:entries.count];
 for(id entry in entries){
  if(![entry isKindOfClass:NSDictionary.class]){if(error)*error=ZNError(5,@"功能格式错误");return nil;}
  NSDictionary *d=entry;
  NSString *name=d[@"name"],*detail=d[@"detail"],*module=d[@"module"],*uid=d[@"id"];
  NSNumber *button=d[@"buttonType"];NSArray *rules=d[@"rules"];
  if(![name isKindOfClass:NSString.class]||name.length>128||!name.length||
     ![detail isKindOfClass:NSString.class]||detail.length>1024||
     ![module isKindOfClass:NSString.class]||![@[@"主程序",@"UnityFramework"] containsObject:module]||
     ![uid isKindOfClass:NSString.class]||uid.length>128||!uid.length||
     ![button isKindOfClass:NSNumber.class]||button.integerValue<0||button.integerValue>2||
     ![rules isKindOfClass:NSArray.class]||rules.count>128) {
    if(error)*error=ZNError(6,@"功能字段校验失败");return nil;
  }
  ZNV3Feature *f=[ZNV3Feature feature:name detail:detail module:module];
  f.identifier=uid;f.buttonType=button.integerValue;
  for(id item in rules){
   if(![item isKindOfClass:NSDictionary.class]){if(error)*error=ZNError(7,@"规则格式错误");return nil;}
   NSDictionary *r=item;NSString *off=r[@"offset"],*patch=r[@"patch"],*rid=r[@"id"];
   if(![rid isKindOfClass:NSString.class]||rid.length>128||!rid.length||
      ![off isKindOfClass:NSString.class]||![patch isKindOfClass:NSString.class]||
      !ZNValidRule(off,patch)) {
    if(error)*error=ZNError(8,@"Offset / Patch 校验失败");return nil;
   }
   ZNV3PatchRule *rule=[ZNV3PatchRule emptyRule];rule.identifier=rid;rule.offsetText=off;rule.patchText=patch;
   [f.rules addObject:rule];
  }
  [result addObject:f];
 }
 return result;
}
- (BOOL)saveFeatures:(NSArray<ZNV3Feature *> *)features error:(NSError **)error {
 if(features.count>1000){if(error)*error=ZNError(9,@"功能数量超限");return NO;}
 NSMutableArray *items=[NSMutableArray arrayWithCapacity:features.count];
 for(ZNV3Feature *f in features){
  if(!f.name.length||f.name.length>128||f.detail.length>1024||
     ![@[@"主程序",@"UnityFramework"] containsObject:f.module]||
     f.buttonType<0||f.buttonType>2||f.rules.count>128) {
   if(error)*error=ZNError(10,@"功能字段校验失败");return NO;
  }
  NSMutableArray *rules=[NSMutableArray arrayWithCapacity:f.rules.count];
  for(ZNV3PatchRule *rule in f.rules){
   NSString *off=rule.offsetText?:@"",*patch=rule.patchText?:@"";
   if(!ZNValidRule(off,patch)) {
    if(error)*error=ZNError(11,@"Offset / Patch 格式错误：ARM64 Code Patch 需要 4–256 字节、4 字节对齐");return NO;
   }
   [rules addObject:@{@"id":rule.identifier?:@"",@"offset":off,@"patch":patch}];
  }
  [items addObject:@{@"id":f.identifier?:@"",@"name":f.name,@"detail":f.detail?:@"",
    @"module":f.module,@"buttonType":@(f.buttonType),@"rules":rules}];
 }
 NSDictionary *doc=@{@"schemaVersion":@1,@"features":items};
 NSData *data=[NSJSONSerialization dataWithJSONObject:doc options:NSJSONWritingPrettyPrinted error:error];if(!data)return NO;
 NSURL *url=[self fileURL:error];if(!url)return NO;
 return [data writeToURL:url options:NSDataWritingAtomic error:error];
}
@end
