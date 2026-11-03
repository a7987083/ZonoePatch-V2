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
  // P10.1: type IDs 0/1/2 retain legacy meaning; 3 is Slider.
  check(ZNV3FeatureTypeToggle==0 && ZNV3FeatureTypeAction==1 &&
        ZNV3FeatureTypeNumberInput==2 && ZNV3FeatureTypeSlider==3,
        "stable four-kind persisted type IDs");
  for(NSInteger kind=ZNV3FeatureTypeToggle;kind<=ZNV3FeatureTypeSlider;kind++){
   feature.buttonType=(ZNV3FeatureType)kind;
   check([repo saveFeatures:@[feature] error:&error],"persist supported feature type");
   NSArray<ZNV3Feature *> *roundtrip=[repo loadFeatures:&error];
   check(roundtrip.count==1 && roundtrip[0].buttonType==kind,
         "feature type survives v1 JSON reload");
  }
  // P10.2: pending Slider parameters survive JSON and draft copies.
  feature.buttonType=ZNV3FeatureTypeSlider;
  feature.valueConfig.valueType=ZNV3NumericTypeFloat32;
  feature.valueConfig.minimum=1.5;feature.valueConfig.maximum=9.5;
  feature.valueConfig.step=0.5;feature.valueConfig.defaultValue=3.5;
  feature.valueConfig.requiresEnableSwitch=YES;
  check([repo saveFeatures:@[feature] error:&error],"slider parameter persisted");
  NSArray<ZNV3Feature *> *sliderLoaded=[repo loadFeatures:&error];
  check(sliderLoaded.count==1 &&
        sliderLoaded[0].buttonType==ZNV3FeatureTypeSlider &&
        sliderLoaded[0].valueConfig.requiresEnableSwitch &&
        sliderLoaded[0].valueConfig.valueType==ZNV3NumericTypeFloat32 &&
        sliderLoaded[0].valueConfig.minimum==1.5 &&
        sliderLoaded[0].valueConfig.step==0.5 &&
        sliderLoaded[0].valueConfig.defaultValue==3.5,
        "slider pending value and enable gate roundtrip");
  ZNV3ValueConfig *copied=[sliderLoaded.firstObject.valueConfig copy];
  copied.defaultValue=6.0;
  check(sliderLoaded.firstObject.valueConfig.defaultValue==3.5,
        "value configuration deep copy");
  feature.valueConfig.requiresEnableSwitch=NO;
  check(![repo saveFeatures:@[feature] error:&error],"slider rejects missing enable gate");
  feature.valueConfig.requiresEnableSwitch=YES;
  feature.valueConfig.minimum=10;feature.valueConfig.maximum=9;
  check(![repo saveFeatures:@[feature] error:&error],"reject inverted numeric range");
  feature.valueConfig.minimum=1.5;feature.valueConfig.maximum=9.5;
  feature.valueConfig.step=0;
  check(![repo saveFeatures:@[feature] error:&error],"reject zero numeric step");
  feature.valueConfig.step=0.5;
  feature.valueConfig.valueType=ZNV3NumericTypeInt32;
  check(![repo saveFeatures:@[feature] error:&error],"reject fractional Int32 parameters");
  feature.valueConfig=[ZNV3ValueConfig defaults];
  check([repo saveFeatures:@[feature] error:&error],"restore valid slider parameter defaults");
  feature.buttonType=(ZNV3FeatureType)4;
  check(![repo saveFeatures:@[feature] error:&error],"reject unknown feature type");
  feature.buttonType=ZNV3FeatureTypeToggle;
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
  // P8: deleting a row before an open editor must not redirect save to another feature.
  ZNV3Feature *second=[ZNV3Feature feature:@"second" detail:@"index regression" module:@"UnityFramework"];
  ZNV3PatchRule *secondRule=[ZNV3PatchRule emptyRule];
  secondRule.offsetText=@"0x39059D4";secondRule.patchText=@"E9FF9F52";
  [second.rules addObject:secondRule];
  check([repo saveFeatures:@[feature,second] error:&error],"two-feature fixture persisted");
  ZNV3FeatureStore *shiftStore=[ZNV3FeatureStore new];
  [shiftStore editFeatureAtIndex:1];
  NSString *draftID=[shiftStore.draft.identifier copy];
  check([shiftStore deleteFeatureAtIndex:0],"delete row preceding edited feature");
  check(shiftStore.editingIndex==0,"editing index follows remaining feature");
  shiftStore.draft.name=@"second-edited";
  check([shiftStore saveDraft],"save edited feature after preceding delete");
  check(shiftStore.features.count==1 &&
    [shiftStore.features[0].identifier isEqualToString:draftID] &&
    [shiftStore.features[0].name isEqualToString:@"second-edited"],
    "save preserves intended feature identity after delete");
  NSURL *appSupport=[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
  NSURL *file=[[appSupport URLByAppendingPathComponent:@"ZonoePatchV3"] URLByAppendingPathComponent:@"features-v1.json"];
  // Legacy P3 oversized patch is quarantined but its JSON stays intact on subsequent writes.
  NSDictionary *legacyRule=@{@"id":@"old-rule",@"offset":@"0x39059D4",
    @"patch":[@"" stringByPaddingToLength:520 withString:@"AA" startingAtIndex:0]};
  NSDictionary *legacyFeature=@{@"id":@"legacy",@"name":@"old",@"detail":@"historical",
    @"module":@"UnityFramework",@"buttonType":@0,@"rules":@[legacyRule]};
  NSDictionary *validRule=@{@"id":@"good-rule",@"offset":@"0x39059D4",@"patch":@"E9FF9F52"};
  NSDictionary *validFeature=@{@"id":@"good",@"name":@"working",@"detail":@"valid",
    @"module":@"UnityFramework",@"buttonType":@0,@"rules":@[validRule]};
  NSData *legacyJSON=[NSJSONSerialization dataWithJSONObject:@{@"schemaVersion":@1,
      @"features":@[validFeature,legacyFeature]} options:0 error:nil];
  check([legacyJSON writeToURL:file options:NSDataWritingAtomic error:nil],"legacy fixture written");
  ZNV3ConfigRepository *legacyRepo=[ZNV3ConfigRepository new];
  NSArray *good=[legacyRepo loadFeatures:&error];
  check(good.count==1 && legacyRepo.quarantinedFeatureCount==1,"legacy quarantine keeps good features");
  check([legacyRepo saveFeatures:good error:&error],"save good features without dropping legacy entries");
  NSData *roundtrip=[NSData dataWithContentsOfURL:file];
  NSDictionary *reloaded=[NSJSONSerialization JSONObjectWithData:roundtrip options:0 error:nil];
  NSArray *entries=reloaded[@"features"];
  BOOL legacyStillThere=NO;
  for(NSDictionary *entry in entries)if([entry[@"id"] isEqual:@"legacy"] &&
    [entry[@"rules"][0][@"patch"] isEqual:legacyRule[@"patch"]])legacyStillThere=YES;
  check(entries.count==2&&legacyStillThere,"incompatible JSON preserved verbatim");
  [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
 }
 printf("V3 Address/Store regression: %s (%d failures)\n",failures?"FAIL":"PASS",failures);
 return failures?1:0;
}
