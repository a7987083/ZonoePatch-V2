#import "ZNPerformanceReport.h"
#include "ZNPerformance.h"
#include <cassert>
int main(){@autoreleasepool{
 ZNPerformanceReset();ZNPerformanceEnable(NO);assert([ZNPerformanceSnapshot()[@"metrics"] count]==5);
 ZNPerformanceEnable(YES);{znperf::Scope s(znperf::Search);}
 NSDictionary *report=ZNPerformanceSnapshot();assert([report[@"metrics"][@"search.sync"][@"totalCount"] unsignedIntegerValue]==1);
 assert([NSJSONSerialization dataWithJSONObject:report options:0 error:nil]);ZNPerformanceReset();assert([ZNPerformanceSnapshot()[@"metrics"][@"search.sync"][@"totalCount"] unsignedIntegerValue]==0);
 NSLog(@"production performance report PASS");
}}
