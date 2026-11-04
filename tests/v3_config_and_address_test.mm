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
  // NumberInput has only typed min/max; no step/default/enable-gate in persisted JSON.
  feature.buttonType=ZNV3FeatureTypeNumberInput;
  feature.valueConfig=[ZNV3ValueConfig defaults];
  feature.valueConfig.minimum=10;feature.valueConfig.maximum=20;
  feature.valueConfig.defaultValue=0;feature.valueConfig.step=0;
  check([repo saveFeatures:@[feature] error:&error],
        "input accepts range independent of hidden default/step");
  NSDictionary *inputDoc=[NSJSONSerialization JSONObjectWithData:
      [NSData dataWithContentsOfURL:[[[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"ZonoePatchV3"] URLByAppendingPathComponent:@"features-v1.json"]] options:0 error:&error];
  NSDictionary *inputParameters=inputDoc[@"features"][0][@"parameters"];
  check(inputParameters.count==4&&inputParameters[@"numericSchemaVersion"]&&inputParameters[@"valueType"]&&
        inputParameters[@"minimum"]&&inputParameters[@"maximum"]&&
        !inputParameters[@"step"]&&!inputParameters[@"defaultValue"]&&
        !inputParameters[@"requiresEnableSwitch"],
        "input serializes exactly type/min/max");
  NSArray<ZNV3Feature *> *inputLoaded=[repo loadFeatures:&error];
  check(inputLoaded.count==1&&inputLoaded[0].valueConfig.minimum==10&&
        inputLoaded[0].valueConfig.maximum==20,
        "minimal input parameters roundtrip");
  feature.valueConfig.minimum=21;
  check(![repo saveFeatures:@[feature] error:&error],"input rejects inverted range");
  // Numeric rules persist Offset only, without an executable code Patch.
  feature.valueConfig=[ZNV3ValueConfig defaults];
  feature.buttonType=ZNV3FeatureTypeNumberInput;
  rule.offsetText=@"0x39059D5";rule.patchText=@"E9FF9F52";
  check([repo saveFeatures:@[feature] error:&error],
        "number input accepts byte-unaligned typed Offset and ignores stale Patch");
  NSDictionary *numericDoc=[NSJSONSerialization JSONObjectWithData:
      [NSData dataWithContentsOfURL:[[[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"ZonoePatchV3"] URLByAppendingPathComponent:@"features-v1.json"]] options:0 error:&error];
  check(numericDoc[@"features"][0][@"rules"][0][@"patch"]==nil,
        "numeric Offset-only JSON omits Patch field");
  NSArray<ZNV3Feature *> *numericLoaded=[repo loadFeatures:&error];
  check(numericLoaded.count==1&&
        [numericLoaded[0].rules.firstObject.patchText isEqualToString:@""],
        "numeric rules reload without any Patch bytes");
  rule.offsetText=@"not-an-offset";
  check(![repo saveFeatures:@[feature] error:&error],"reject invalid numeric Offset");
  rule.offsetText=@"0x39059D4";
  for(NSInteger type=ZNV3NumericTypeInt8;type<=ZNV3NumericTypeFloat64;type++){
   feature.valueConfig=[ZNV3ValueConfig defaults];
   feature.valueConfig.valueType=(ZNV3NumericType)type;
   check([repo saveFeatures:@[feature] error:&error],"ten numeric types persist");
  }
  feature.valueConfig=[ZNV3ValueConfig defaults];
  feature.valueConfig.valueType=ZNV3NumericTypeUInt8;feature.valueConfig.minimum=-1;
  check(![repo saveFeatures:@[feature] error:&error],"reject unsigned negative range");
  feature.valueConfig.valueType=ZNV3NumericTypeInt64;
  feature.valueConfig.minimum=0;feature.valueConfig.maximum=9007199254740992.0;
  check(![repo saveFeatures:@[feature] error:&error],"reject integer beyond precise double range");
  // P10.3 schema v3: preserve complete UInt64 / Int64 decimal precision.
  feature.buttonType=ZNV3FeatureTypeNumberInput;
  feature.valueConfig=[ZNV3ValueConfig defaults];
  feature.valueConfig.valueType=ZNV3NumericTypeUInt64;
  feature.valueConfig.minimumText=@"0";
  feature.valueConfig.maximumText=@"18446744073709551615";
  check([repo saveFeatures:@[feature] error:&error],
        "persist full precision UInt64 input range");
  NSArray<ZNV3Feature *> *preciseLoaded=[repo loadFeatures:&error];
  check(preciseLoaded.count==1 &&
        [preciseLoaded[0].valueConfig.maximumText isEqualToString:@"18446744073709551615"],
        "load full precision UInt64 without double conversion");
  NSDictionary *preciseDoc=[NSJSONSerialization JSONObjectWithData:
      [NSData dataWithContentsOfURL:[[[[NSFileManager defaultManager]
        URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject
        URLByAppendingPathComponent:@"ZonoePatchV3"] URLByAppendingPathComponent:@"features-v1.json"]]
      options:0 error:&error];
  NSDictionary *preciseParams=preciseDoc[@"features"][0][@"parameters"];
  check([preciseParams[@"numericSchemaVersion"] isEqual:@3] &&
        [preciseParams[@"maximum"] isKindOfClass:NSString.class],
        "schema v3 serializes precise numeric text");
  feature.valueConfig.maximumText=@"18446744073709551616";
  check(![repo saveFeatures:@[feature] error:&error],"reject overflowed UInt64 exact range");
  feature.buttonType=ZNV3FeatureTypeSlider;
  feature.valueConfig=[ZNV3ValueConfig defaults];
  feature.valueConfig.valueType=ZNV3NumericTypeInt64;
  feature.valueConfig.minimumText=@"-9223372036854775808";
  feature.valueConfig.maximumText=@"9223372036854775807";
  feature.valueConfig.stepText=@"1";
  feature.valueConfig.defaultText=@"0";
  check([repo saveFeatures:@[feature] error:&error],
        "persist exact Int64 slider parameters");
  NSArray<ZNV3Feature *> *sliderExactLoaded=[repo loadFeatures:&error];
  check(sliderExactLoaded.count==1 &&
        [sliderExactLoaded[0].valueConfig.minimumText isEqualToString:@"-9223372036854775808"] &&
        [sliderExactLoaded[0].valueConfig.maximumText isEqualToString:@"9223372036854775807"],
        "roundtrip full precision Int64 slider range");
  feature.valueConfig.defaultText=@"9223372036854775808";
  check(![repo saveFeatures:@[feature] error:&error],
        "reject slider default beyond exact Int64");
  feature.valueConfig=[ZNV3ValueConfig defaults];
  // Existing P10.2 configurations used 0=Int32 / 1=Float32 without schema version.
  NSURL *migrationDir=[[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
      inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"ZonoePatchV3"];
  NSURL *migrationFile=[migrationDir URLByAppendingPathComponent:@"features-v1.json"];
  NSDictionary *oldNumericBase=@{@"minimum":@0,@"maximum":@100};
  NSMutableDictionary *oldInt=[oldNumericBase mutableCopy];oldInt[@"valueType"]=@0;
  NSMutableDictionary *oldFloat=[oldNumericBase mutableCopy];oldFloat[@"valueType"]=@1;
  NSDictionary *oldRule=@{@"id":@"typed-rule",@"offset":@"0x39059D4"};
  NSDictionary *oldA=@{@"id":@"old-int",@"name":@"old-int",@"detail":@"",
       @"module":@"UnityFramework",@"buttonType":@2,@"rules":@[oldRule],@"parameters":oldInt};
  NSDictionary *oldB=@{@"id":@"old-float",@"name":@"old-float",@"detail":@"",
       @"module":@"UnityFramework",@"buttonType":@2,@"rules":@[oldRule],@"parameters":oldFloat};
  NSData *oldDocument=[NSJSONSerialization dataWithJSONObject:@{@"schemaVersion":@1,
      @"features":@[oldA,oldB]} options:0 error:&error];
  check([oldDocument writeToURL:migrationFile options:NSDataWritingAtomic error:&error],
        "legacy numeric ID fixture written");
  NSArray<ZNV3Feature *> *migrated=[repo loadFeatures:&error];
  check(migrated.count==2 &&
        migrated[0].valueConfig.valueType==ZNV3NumericTypeInt32 &&
        migrated[1].valueConfig.valueType==ZNV3NumericTypeFloat32,
        "unversioned P10.2 integer and float IDs migrate correctly");
  feature.valueConfig=[ZNV3ValueConfig defaults];
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
  // D07: version binding remains explicit and legacy records stay editable.
  NSString *pin=@"12345678-1234-1234-1234-123456789ABC";
  check(ZNV3ValidBoundImageUUID(pin)&&
        ZNV3MatchesBoundImageUUID([pin lowercaseString],pin)&&
        !ZNV3MatchesBoundImageUUID(pin,@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")&&
        !ZNV3ValidBoundImageUUID(@"invalid"),"strict Mach-O UUID validation");
  feature.buttonType=ZNV3FeatureTypeToggle;
  rule.offsetText=@"0x39059D4";rule.patchText=@"E9FF9F52";
  feature.boundImageUUID=pin;
  check([repo saveFeatures:@[feature] error:&error],"save UUID binding");
  NSArray<ZNV3Feature *> *pinned=[repo loadFeatures:&error];
  check(pinned.count==1&&[pinned[0].boundImageUUID isEqualToString:pin],
        "persisted UUID roundtrips");
  ZNV3FeatureStore *boundStore=[ZNV3FeatureStore new];
  [boundStore editFeatureAtIndex:0];
  check([boundStore.draft.boundImageUUID isEqualToString:pin],
        "editing retains UUID binding");
  [boundStore cancelDraft];
  feature.boundImageUUID=@"INVALID";
  check(![repo saveFeatures:@[feature] error:&error],"reject malformed UUID on save");
  feature.boundImageUUID=nil;
  check([repo saveFeatures:@[feature] error:&error],"unbound legacy config remains editable");
  NSArray<ZNV3Feature *> *legacyUnbound=[repo loadFeatures:&error];
  check(legacyUnbound.count==1&&!legacyUnbound[0].boundImageUUID.length,
        "unbound legacy does not silently bind");
  // Malformed UUID in legacy JSON is quarantined and retained verbatim.
  NSURL *uuidFile=[[[[NSFileManager defaultManager]
    URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject
    URLByAppendingPathComponent:@"ZonoePatchV3"] URLByAppendingPathComponent:@"features-v1.json"];
  NSDictionary *badUUID=@{@"id":@"uuid-invalid",@"name":@"bad-uuid",
    @"detail":@"",@"module":@"UnityFramework",@"buttonType":@0,
    @"boundImageUUID":@"invalid",
    @"rules":@[@{@"id":@"rule-1",@"offset":@"0x39059D4",@"patch":@"E9FF9F52"}]};
  NSData *badUUIDData=[NSJSONSerialization dataWithJSONObject:
    @{@"schemaVersion":@1,@"features":@[badUUID]} options:0 error:&error];
  check([badUUIDData writeToURL:uuidFile options:NSDataWritingAtomic error:&error],
        "write invalid UUID fixture");
  ZNV3ConfigRepository *badUUIDRepo=[ZNV3ConfigRepository new];
  NSArray *badUUIDLoaded=[badUUIDRepo loadFeatures:&error];
  check(badUUIDLoaded.count==0&&badUUIDRepo.quarantinedFeatureCount==1,
        "invalid persisted UUID quarantined");
  check([badUUIDRepo saveFeatures:badUUIDLoaded error:&error],
        "preserve quarantined invalid UUID record");
  NSDictionary *badUUIDCopy=[NSJSONSerialization JSONObjectWithData:
     [NSData dataWithContentsOfURL:uuidFile] options:0 error:&error];
  check([badUUIDCopy[@"features"] count]==1 &&
        [badUUIDCopy[@"features"][0][@"boundImageUUID"] isEqualToString:@"invalid"],
        "malformed UUID original JSON not lost");
  [[NSFileManager defaultManager] removeItemAtURL:uuidFile error:nil];
  // Debt cleanup: duplicate ownership IDs are not safe as executable rows.
  ZNV3Feature *dupA=[ZNV3Feature feature:@"dup-a" detail:@"" module:@"UnityFramework"];
  ZNV3PatchRule *dupARule=[ZNV3PatchRule emptyRule];
  dupARule.offsetText=@"0x39059D4";dupARule.patchText=@"E9FF9F52";
  [dupA.rules addObject:dupARule];
  ZNV3Feature *dupB=[ZNV3Feature feature:@"dup-b" detail:@"" module:@"UnityFramework"];
  ZNV3PatchRule *dupBRule=[ZNV3PatchRule emptyRule];
  dupBRule.offsetText=@"0x39059D8";dupBRule.patchText=@"E9FF9F52";
  [dupB.rules addObject:dupBRule];
  dupB.identifier=dupA.identifier;
  check(![repo saveFeatures:@[dupA,dupB] error:&error],
        "duplicate Feature ID rejected on save");
  dupB.identifier=@"unique-b";
  dupBRule.identifier=dupARule.identifier;
  check([repo saveFeatures:@[dupA,dupB] error:&error],
        "the same Rule ID across separate features remains legal");
  ZNV3PatchRule *sameRule=[ZNV3PatchRule emptyRule];
  sameRule.identifier=dupARule.identifier;
  sameRule.offsetText=@"0x39059DC";sameRule.patchText=@"E9FF9F52";
  [dupA.rules addObject:sameRule];
  check(![repo saveFeatures:@[dupA,dupB] error:&error],
        "duplicate Rule ID within one feature rejected");
  [dupA.rules removeLastObject];
  dupA.identifier=@"";
  check(![repo saveFeatures:@[dupA] error:&error],
        "missing Feature ID rejected");
  dupA.identifier=@"unique-a";
  dupARule.identifier=@"";
  check(![repo saveFeatures:@[dupA] error:&error],
        "missing Rule ID rejected");
  dupARule.identifier=@"first-rule";
  check([repo saveFeatures:@[dupA,dupB] error:&error],
        "unique feature/rule ownership still saves");
  NSURL *idFile=[[[[NSFileManager defaultManager]
    URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject
    URLByAppendingPathComponent:@"ZonoePatchV3"] URLByAppendingPathComponent:@"features-v1.json"];
  NSDictionary *duplicateFeature=@{@"id":@"duplicate-loaded",@"name":@"loaded",
     @"detail":@"",@"module":@"UnityFramework",@"buttonType":@0,
     @"rules":@[@{@"id":@"r-1",@"offset":@"0x39059D4",@"patch":@"E9FF9F52"}]};
  NSDictionary *duplicateRule=@{@"id":@"duplicate-rule",@"name":@"loaded",
     @"detail":@"",@"module":@"UnityFramework",@"buttonType":@0,
     @"rules":@[@{@"id":@"r-1",@"offset":@"0x39059D4",@"patch":@"E9FF9F52"},
                 @{@"id":@"r-1",@"offset":@"0x39059D8",@"patch":@"E9FF9F52"}]};
  NSData *duplicateFixture=[NSJSONSerialization dataWithJSONObject:
    @{@"schemaVersion":@1,@"features":@[duplicateFeature,duplicateFeature,duplicateRule]}
    options:0 error:&error];
  check([duplicateFixture writeToURL:idFile options:NSDataWritingAtomic error:&error],
        "duplicate fixture written");
  ZNV3ConfigRepository *duplicateRepo=[ZNV3ConfigRepository new];
  NSArray *uniqueLoaded=[duplicateRepo loadFeatures:&error];
  check(uniqueLoaded.count==1&&duplicateRepo.quarantinedFeatureCount==2,
        "duplicate Feature/Rule ownership quarantined without execution");
  check([duplicateRepo saveFeatures:uniqueLoaded error:&error],
        "save preserves quarantined ambiguous records");
  NSDictionary *duplicatePreserved=[NSJSONSerialization JSONObjectWithData:
     [NSData dataWithContentsOfURL:idFile] options:0 error:&error];
  check([duplicatePreserved[@"features"] count]==3,
        "quarantined duplicate JSON preserved verbatim");
  [[NSFileManager defaultManager] removeItemAtURL:idFile error:nil];
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
