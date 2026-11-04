#import <Foundation/Foundation.h>
#import "../ZNTypedCustomerRuntime.h"
static int failures=0;
static void check(BOOL v,const char *label){
 if(!v){++failures;fprintf(stderr,"FAIL: %s\n",label);}
}
int main(void){
 @autoreleasepool {
  ZNTypedCustomerRuntime *runtime=[ZNTypedCustomerRuntime shared];
  NSArray<ZNTypedCustomerFeature *> *catalog=[runtime discover];
  check(catalog!=nil,"discovery never returns nil");
  check(!runtime.recoveryFailed,"fresh runtime unlocked");
  ZNTypedCustomerFeature *untrusted=[ZNTypedCustomerFeature new];
  NSError *error=nil;
  check(![runtime applyValue:@"123" feature:untrusted error:&error],
        "reject forged feature before any memory write");
  check(error!=nil,"forged feature produces explicit error");
  error=nil;
  check(![runtime restoreFeature:untrusted error:&error],
        "reject restore with no active transaction");
  check(error!=nil,"missing restore snapshot produces explicit error");
  check(!runtime.recoveryFailed,"expected invalid calls do not lock runtime");
  check([[runtime discover] count]==catalog.count,"discovery stable after invalid calls");
 }
 fprintf(stdout,"P10.4.2 typed customer API: %s (%d failures)\n",
         failures?"FAIL":"PASS",failures);
 return failures?1:0;
}
