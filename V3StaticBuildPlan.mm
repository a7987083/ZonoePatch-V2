#import "V3StaticBuildPlanner.h"
#import <fcntl.h>
#import <sys/stat.h>
#import <unistd.h>
#import <errno.h>
#include <stdint.h>

static NSError *ZNP6Error(NSInteger code,NSString *message){
 return [NSError errorWithDomain:@"ZonoePatch.V3.StaticBuild" code:code userInfo:@{NSLocalizedDescriptionKey:message}];
}
static NSString *ZNP6Hex(NSData *bytes) {
 NSMutableString *out=[NSMutableString stringWithCapacity:bytes.length*2];
 const uint8_t *p=(const uint8_t *)bytes.bytes;
 for(NSUInteger i=0;i<bytes.length;i++)[out appendFormat:@"%02X",p[i]];
 return out;
}
@implementation ZNV3StaticBuildEntry
- (instancetype)initWithRuleID:(NSString *)ruleID uuid:(NSString *)uuid path:(NSString *)path
 rva:(uint64_t)rva fileOffset:(uint64_t)fileOffset original:(NSData *)original patch:(NSData *)patch {
 return [self initWithRuleID:ruleID featureKey:@"" featureName:@"" uuid:uuid path:path
  rva:rva fileOffset:fileOffset original:original patch:patch];
}
- (instancetype)initWithRuleID:(NSString *)ruleID featureKey:(NSString *)featureKey featureName:(NSString *)featureName
 uuid:(NSString *)uuid path:(NSString *)path rva:(uint64_t)rva fileOffset:(uint64_t)fileOffset original:(NSData *)original patch:(NSData *)patch {
 if((self=[super init])) {
  _ruleID=[ruleID copy];_featureKey=[featureKey copy];_featureName=[featureName copy];
  _moduleUUID=[uuid copy];_sourcePath=[path copy];_rva=rva;
  _fileOffset=fileOffset;_originalBytes=[original copy];_patchBytes=[patch copy];
 }
 return self;
}
@end
@implementation ZNV3StaticBuildPlan
- (instancetype)initWithModule:(NSString *)module entries:(NSArray<ZNV3StaticBuildEntry *> *)entries {
 return [self initWithModule:module name:module entries:entries];
}
- (instancetype)initWithModule:(NSString *)module name:(NSString *)name entries:(NSArray<ZNV3StaticBuildEntry *> *)entries {
 return [self initWithModule:module name:name featureCount:1 entries:entries];
}
- (instancetype)initWithModule:(NSString *)module name:(NSString *)name featureCount:(NSUInteger)count entries:(NSArray<ZNV3StaticBuildEntry *> *)entries {
 if((self=[super init])){_module=[module copy];_featureName=[name copy];_featureCount=count;_entries=[entries copy];
  _imageUUID=[entries.firstObject.moduleUUID copy];_sourcePath=[entries.firstObject.sourcePath copy];}
 return self;
}
+ (BOOL)validateEntries:(NSArray<ZNV3StaticBuildEntry *> *)entries error:(NSError **)error {
 if(!entries.count||entries.count>128){if(error)*error=ZNP6Error(1,@"Static plan must contain 1–128 rules");return NO;}
 ZNV3StaticBuildEntry *first=entries.firstObject;
 NSMutableSet<NSString *> *identifiers=[NSMutableSet set];
 for(ZNV3StaticBuildEntry *entry in entries) {
  uint64_t n=entry.patchBytes.length;
  if(!entry.ruleID.length||!entry.moduleUUID.length||!entry.sourcePath.length||
     !n||n>256||(n&3u)||entry.originalBytes.length!=n||
     (entry.rva&3u)||(entry.fileOffset&3u)||
     [entry.originalBytes isEqualToData:entry.patchBytes]||
     n>UINT64_MAX-entry.rva||n>UINT64_MAX-entry.fileOffset||
     ![entry.moduleUUID isEqualToString:first.moduleUUID]||
     ![entry.sourcePath isEqualToString:first.sourcePath]||
     [identifiers containsObject:entry.ruleID]){
   if(error)*error=ZNP6Error(2,@"Invalid or mixed Mach-O identity, patch range or duplicate rule ID");
   return NO;
  }
  [identifiers addObject:entry.ruleID];
 }
 for(NSUInteger i=0;i<entries.count;i++) {
  ZNV3StaticBuildEntry *a=entries[i];uint64_t aRVAEnd=a.rva+a.patchBytes.length,aFileEnd=a.fileOffset+a.patchBytes.length;
  for(NSUInteger j=i+1;j<entries.count;j++) {
   ZNV3StaticBuildEntry *b=entries[j];uint64_t bRVAEnd=b.rva+b.patchBytes.length,bFileEnd=b.fileOffset+b.patchBytes.length;
   if((a.rva<bRVAEnd&&b.rva<aRVAEnd)||
      (a.fileOffset<bFileEnd&&b.fileOffset<aFileEnd)){
    if(error)*error=ZNP6Error(3,@"Overlapping RVA or file ranges; do not silently merge static patches");
    return NO;
   }
  }
 }
 return YES;
}
- (NSDictionary *)manifest {
 NSMutableArray *rules=[NSMutableArray arrayWithCapacity:self.entries.count];
 for(ZNV3StaticBuildEntry *e in self.entries) {
  [rules addObject:@{@"ruleID":e.ruleID,@"featureKey":e.featureKey?:@"",
    @"featureName":e.featureName?:@"",
    @"rva":[NSString stringWithFormat:@"0x%llX",(unsigned long long)e.rva],
    @"fileOffset":[NSString stringWithFormat:@"0x%llX",(unsigned long long)e.fileOffset],
    @"original":ZNP6Hex(e.originalBytes),@"patch":ZNP6Hex(e.patchBytes)}];
 }
 return @{@"schema":@"com.zonoe.v3.static-build-plan",@"version":@1,
  @"module":self.module?:@"",@"imageUUID":self.imageUUID?:@"",
  @"sourcePath":self.sourcePath?:@"",@"featureCount":@(self.featureCount),@"rules":rules,
  @"status":@"PREFLIGHT_ONLY",@"binaryGenerated":@NO};
}
@end




@implementation ZNV3UnifiedNumericSpan
- (instancetype)initWithFeatureID:(NSString *)featureID ruleID:(NSString *)ruleID
 uuid:(NSString *)uuid path:(NSString *)path rva:(uint64_t)rva
 fileOffset:(uint64_t)fileOffset width:(uint64_t)width {
 if((self=[super init])) {
  _featureID=[featureID copy];_ruleID=[ruleID copy];
  _imageUUID=[uuid copy];_sourcePath=[path copy];
  _rva=rva;_fileOffset=fileOffset;_width=width;
 }
 return self;
}
@end

@interface ZNV3UnifiedBuildPlan ()
@property(nonatomic,copy,readwrite) NSString *imageUUID;
@property(nonatomic,copy,readwrite) NSString *sourcePath;
@property(nonatomic,copy,readwrite) NSArray<ZNV3StaticBuildEntry *> *staticEntries;
@property(nonatomic,copy,readwrite) NSArray<ZNV3UnifiedNumericSpan *> *numericSpans;
@end
@implementation ZNV3UnifiedBuildPlan
+ (instancetype)planWithStaticEntries:(NSArray<ZNV3StaticBuildEntry *> *)entries
 numericSpans:(NSArray<ZNV3UnifiedNumericSpan *> *)spans error:(NSError **)error {
 if((!entries.count&&!spans.count)||entries.count+spans.count>128) {
  if(error)*error=ZNP6Error(30,@"Unified plan requires 1–128 total ranges");
  return nil;
 }
 if(entries.count&&![ZNV3StaticBuildPlan validateEntries:entries error:error])return nil;
 NSString *uuid=entries.count?entries.firstObject.moduleUUID:spans.firstObject.imageUUID;
 NSString *path=entries.count?entries.firstObject.sourcePath:spans.firstObject.sourcePath;
 if(!uuid.length||!path.length) {
  if(error)*error=ZNP6Error(31,@"Unified plan requires explicit image identity");return nil;
 }
 // Compare every span in both virtual and file address domains. Disjoint
 // virtual addresses alone are insufficient for a malformed Mach-O mapping.
 NSMutableArray<NSDictionary *> *ranges=[NSMutableArray array];
 for(ZNV3StaticBuildEntry *entry in entries) {
  [ranges addObject:@{@"rva":@(entry.rva),@"file":@(entry.fileOffset),
     @"width":@(entry.patchBytes.length)}];
 }
 NSMutableSet<NSString *> *numericIDs=[NSMutableSet set];
 for(ZNV3UnifiedNumericSpan *span in spans) {
  uint64_t n=span.width;
  NSString *identity=[NSString stringWithFormat:@"%@/%@",span.featureID?:@"",span.ruleID?:@""];
  if(!span.featureID.length||!span.ruleID.length||
     [numericIDs containsObject:identity]||
     ![span.imageUUID isEqualToString:uuid]||
     ![span.sourcePath isEqualToString:path]||
     (n!=1&&n!=2&&n!=4&&n!=8)||
     (span.rva%n)||(span.fileOffset%n)||
     !span.rva||n>UINT64_MAX-span.rva||n>UINT64_MAX-span.fileOffset) {
   if(error)*error=ZNP6Error(32,@"Invalid numeric range, ownership or image identity");
   return nil;
  }
  [numericIDs addObject:identity];
  [ranges addObject:@{@"rva":@(span.rva),@"file":@(span.fileOffset),@"width":@(n)}];
 }
 for(NSUInteger i=0;i<ranges.count;i++) {
  NSDictionary *a=ranges[i];
  uint64_t ar=[a[@"rva"] unsignedLongLongValue],af=[a[@"file"] unsignedLongLongValue];
  uint64_t an=[a[@"width"] unsignedLongLongValue];
  for(NSUInteger j=i+1;j<ranges.count;j++) {
   NSDictionary *b=ranges[j];
   uint64_t br=[b[@"rva"] unsignedLongLongValue],bf=[b[@"file"] unsignedLongLongValue];
   uint64_t bn=[b[@"width"] unsignedLongLongValue];
   if((ar<br+bn&&br<ar+an)||(af<bf+bn&&bf<af+an)) {
    if(error)*error=ZNP6Error(33,@"Unified plan has overlapping RVA or file ranges");
    return nil;
   }
  }
 }
 ZNV3UnifiedBuildPlan *plan=[ZNV3UnifiedBuildPlan new];
 plan.imageUUID=uuid;plan.sourcePath=path;
 plan.staticEntries=[entries copy];plan.numericSpans=[spans copy];
 return plan;
}
@end
