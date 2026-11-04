#import <Foundation/Foundation.h>
#import "../ZNMixedCustomerRuntime.h"
static int fails=0;
static void check(BOOL b,const char *name){if(!b){++fails;fprintf(stderr,"FAIL %s\n",name);}}
int main(){
 @autoreleasepool {
  ZNMixedCustomerRuntime *r=[ZNMixedCustomerRuntime shared];
  NSArray<ZNMixedCustomerFeature *> *catalog=[r discover];
  check(catalog!=nil,"catalog not nil");
  check(!r.recoveryFailed,"fresh coordinator unlocked");
  ZNMixedCustomerFeature *forged=[ZNMixedCustomerFeature new];
  NSError *error=nil;
  check(![r applyValue:@"10" feature:forged error:&error],"untrusted feature rejected before write");
  check(error!=nil,"error detail for invalid feature");
  error=nil;
  check(![r restoreFeature:forged error:&error],"untrusted feature cannot restore");
  check(error!=nil,"restore error explicit");
  check(!r.recoveryFailed,"invalid requests do not latch recovery failure");
  check([r discover].count==catalog.count,"catalog stable");
 }
 printf("P10.6.3 mixed customer public API: %s (%d failures)\n",fails?"FAIL":"PASS",fails);
 return fails?1:0;
}
