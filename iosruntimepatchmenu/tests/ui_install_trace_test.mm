#import "ZNUIInstallationTrace.h"
#include <cassert>
@interface ZNTraceFixture:NSObject
- (NSInteger)base;
- (NSInteger)first;
- (NSInteger)second;
@end
@implementation ZNTraceFixture
- (NSInteger)base{return 1;}
- (NSInteger)first{return [self first]+10;}
- (NSInteger)second{return [self second]+100;}
@end
static NSInteger replacement(id,SEL){return 777;}
int main(){@autoreleasepool{
 Method base=class_getInstanceMethod(ZNTraceFixture.class,@selector(base)),first=class_getInstanceMethod(ZNTraceFixture.class,@selector(first)),second=class_getInstanceMethod(ZNTraceFixture.class,@selector(second));IMP a=method_getImplementation(base),b=method_getImplementation(first),c=method_getImplementation(second);
 ZNTraceFixture *fixture=[ZNTraceFixture new];ZNUITraceReset();ZNUITraceEnable(YES);NSString *prior=ZNUITraceStage(@"fixture");
 method_exchangeImplementations(base,first);assert([fixture base]==11&&[fixture first]==1);method_exchangeImplementations(base,second);assert([fixture base]==111&&[fixture second]==11);
 assert(method_getImplementation(base)==c&&method_getImplementation(first)==a&&method_getImplementation(second)==b);
 IMP old=method_setImplementation(base,(IMP)replacement);assert(old==c&&[fixture base]==777);method_setImplementation(base,old);assert([fixture base]==111);
 ZNUITraceStage(prior);NSDictionary *snapshot=ZNUITraceSnapshot();assert([snapshot[@"total"] unsignedIntegerValue]==4&&[snapshot[@"complete"] boolValue]);assert([snapshot[@"events"][0][@"stage"]isEqual:@"fixture"]);assert([NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil]);
 ZNUITraceEnable(NO);method_exchangeImplementations(base,second);method_exchangeImplementations(base,first);assert([fixture base]==1);assert([ZNUITraceSnapshot()[@"total"] unsignedIntegerValue]==4);
 NSLog(@"actual Objective-C selector/IMP chain/set return/order/disabled trace PASS");
}}
