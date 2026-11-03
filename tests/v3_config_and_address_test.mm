#import <Foundation/Foundation.h>
#import "../V3AddressResolver.h"
#import "../V3ConfigRepository.h"
#import "../V3FeatureModels.h"

static int failures=0;
static void check(BOOL ok,const char *caseName){
 if(!ok){fprintf(stderr,"FAIL: %s\n",caseName);failures++;}
}
int main(){
 @autoreleasepool {
  check([ZNV3AddressResolver validAlignedCodeOffsetText:@"0x39059D4"],"hex RVA with 0x");
  check([ZNV3AddressResolver validAlignedCodeOffsetText:@"39059D4"],"bare RVA");
  check([ZNV3AddressResolver validAlignedCodeOffsetText:@"rva:0x39059D4"],"explicit RVA");
  check(![ZNV3AddressResolver validAlignedCodeOffsetText:@"0x39059D5"],"reject unaligned offset");
  check(![ZNV3AddressResolver validAlignedCodeOffsetText:@"0xG0"],"reject invalid HEX");
  check(![ZNV3AddressResolver validAlignedCodeOffsetText:@"0xFFFFFFFFFFFFFFFFF"],"reject overflow");
  ZNV3ConfigRepository *repo=[ZNV3ConfigRepository new];
  ZNV3Feature *feature=[ZNV3Feature feature:@"test" detail:@"P5 regression" module:@"UnityFramework"];
  ZNV3PatchRule *rule=[ZNV3PatchRule emptyRule];
  [feature.rules addObject:rule];
  NSError *error=nil;
  rule.offsetText=@"0x39059D5";rule.patchText=@"E9FF9F52";
  check(![repo saveFeatures:@[feature] error:&error],"reject unaligned code patch address");
  rule.offsetText=@"0x39059D4";rule.patchText=@"0xFF";
  check(![repo saveFeatures:@[feature] error:&error],"reject unaligned byte length at save");
  rule.patchText=@"E9FF9F52";
  check([repo saveFeatures:@[feature] error:&error],"valid pair persisted");
  NSArray<ZNV3Feature *> *loaded=[repo loadFeatures:&error];
  check(loaded.count==1,"persisted rules load");
  if(loaded.count==1){
   check([loaded[0].module isEqualToString:@"UnityFramework"],"module preserved in JSON");
   check([loaded[0].rules.firstObject.offsetText isEqualToString:@"0x39059D4"],"offset preserved");
  }
  ZNV3FeatureStore *store=[ZNV3FeatureStore new];
  [store editFeatureAtIndex:0];
  check([store.draft.module isEqualToString:@"UnityFramework"],"edit draft retains stored module");
  [store cancelDraft];
  check(!store.draft,"cancel discards draft");
  NSURL *appSupport=[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
  NSURL *file=[[appSupport URLByAppendingPathComponent:@"ZonoePatchV3"] URLByAppendingPathComponent:@"features-v1.json"];
  [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
 }
 printf("V3 Address/Store regression: %s (%d failures)\n",failures?"FAIL":"PASS",failures);
 return failures?1:0;
}
