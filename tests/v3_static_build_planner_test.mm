#import <Foundation/Foundation.h>
#import "../V3StaticBuildPlanner.h"
static int failed=0;
static void check(BOOL condition,const char *name) {
 if(!condition){fprintf(stderr,"FAIL: %s\n",name);failed++;}
}
static ZNV3StaticBuildEntry *entry(NSString *id,NSString *uuid,NSString *path,uint64_t rva,uint64_t file) {
 const uint8_t oldBytes[4]={0x11,0x22,0x33,0x44};
 const uint8_t newBytes[4]={0xAA,0xBB,0xCC,0xDD};
 return [[ZNV3StaticBuildEntry alloc]initWithRuleID:id uuid:uuid path:path rva:rva fileOffset:file
 original:[NSData dataWithBytes:oldBytes length:4] patch:[NSData dataWithBytes:newBytes length:4]];
}
static ZNV3UnifiedNumericSpan *numericSpan(NSString *feature,NSString *rule,uint64_t rva,uint64_t file,uint64_t width) {
 return [[ZNV3UnifiedNumericSpan alloc]initWithFeatureID:feature ruleID:rule
  uuid:@"uuid-1" path:@"/tmp/a" rva:rva fileOffset:file width:width];
}
int main(void) {
 @autoreleasepool {
  NSError *e=nil;
  ZNV3StaticBuildEntry *a=entry(@"a",@"uuid-1",@"/tmp/a",0x1000,0x2000);
  ZNV3StaticBuildEntry *b=entry(@"b",@"uuid-1",@"/tmp/a",0x1004,0x2004);
  check([ZNV3StaticBuildPlan validateEntries:@[a,b] error:&e],"disjoint plan accepted");
  ZNV3StaticBuildPlan *plan=[[ZNV3StaticBuildPlan alloc]initWithModule:@"UnityFramework" entries:@[a,b]];
  NSDictionary *manifest=[plan manifest];
  check([manifest[@"binaryGenerated"] isEqual:@NO],"manifest cannot claim binary generation");
  check([manifest[@"imageUUID"] isEqual:@"uuid-1"],"manifest UUID");
  check([manifest[@"rules"] count]==2,"manifest retains all rules");
  check(![ZNV3StaticBuildPlan validateEntries:@[a,entry(@"c",@"uuid-1",@"/tmp/a",0x1002,0x3000)] error:&e],"unaligned RVA rejected");
  check(![ZNV3StaticBuildPlan validateEntries:@[a,entry(@"c",@"uuid-1",@"/tmp/a",0x1000,0x3000)] error:&e],"overlap RVA rejected");
  check(![ZNV3StaticBuildPlan validateEntries:@[a,entry(@"c",@"uuid-1",@"/tmp/a",0x3000,0x2000)] error:&e],"overlap file range rejected");
  check(![ZNV3StaticBuildPlan validateEntries:@[a,entry(@"c",@"uuid-2",@"/tmp/a",0x3000,0x3000)] error:&e],"different UUID rejected");
  check(![ZNV3StaticBuildPlan validateEntries:@[a,entry(@"c",@"uuid-1",@"/tmp/b",0x3000,0x3000)] error:&e],"different image path rejected");
  check(![ZNV3StaticBuildPlan validateEntries:@[a,entry(@"a",@"uuid-1",@"/tmp/a",0x3000,0x3000)] error:&e],"duplicate rule identity rejected");

  // P10.6 cross-kind preflight: this cannot enable mixed binary export.
  ZNV3UnifiedBuildPlan *unified=[ZNV3UnifiedBuildPlan planWithStaticEntries:@[a]
    numericSpans:@[numericSpan(@"n1",@"r1",0x3000,0x4000,4),
                   numericSpan(@"n2",@"r2",0x3008,0x4008,8)] error:&e];
  check(unified!=nil&&unified.numericSpans.count==2,"mixed disjoint ownership accepted");
  check(![ZNV3UnifiedBuildPlan planWithStaticEntries:@[a]
    numericSpans:@[numericSpan(@"n1",@"r1",0x1000,0x4000,4)] error:&e],
    "mixed RVA collision rejected");
  check(![ZNV3UnifiedBuildPlan planWithStaticEntries:@[a]
    numericSpans:@[numericSpan(@"n1",@"r1",0x3000,0x2000,4)] error:&e],
    "mixed file collision rejected");
  check(![ZNV3UnifiedBuildPlan planWithStaticEntries:@[]
    numericSpans:@[numericSpan(@"n1",@"r1",0x3000,0x4000,4),
                   numericSpan(@"n2",@"r2",0x3000,0x5000,4)] error:&e],
    "numeric-to-numeric RVA collision rejected");
  check(![ZNV3UnifiedBuildPlan planWithStaticEntries:@[]
    numericSpans:@[numericSpan(@"n1",@"r1",0x3000,0x4000,4),
                   numericSpan(@"n2",@"r2",0x5000,0x4002,2)] error:&e],
    "numeric-to-numeric file collision rejected");
  check(![ZNV3UnifiedBuildPlan planWithStaticEntries:@[]
    numericSpans:@[numericSpan(@"n1",@"r1",0x3000,0x4000,4),
                   numericSpan(@"n1",@"r1",0x5000,0x6000,4)] error:&e],
    "duplicate numeric owner rejected");
  check(![ZNV3UnifiedBuildPlan planWithStaticEntries:@[]
    numericSpans:@[[[ZNV3UnifiedNumericSpan alloc]initWithFeatureID:@"n"
      ruleID:@"r" uuid:@"other" path:@"/tmp/a" rva:0x3000
      fileOffset:0x4000 width:4],numericSpan(@"n2",@"r2",0x5000,0x6000,4)] error:&e],
    "numeric UUID mismatch rejected");
  check(![ZNV3UnifiedBuildPlan planWithStaticEntries:@[]
    numericSpans:@[numericSpan(@"n",@"r",0x3001,0x4000,4)] error:&e],
    "misaligned numeric rejected");
 }
 printf("P6 static planner: %s (%d failures)\n",failed?"FAIL":"PASS",failed);
 return failed?1:0;
}
