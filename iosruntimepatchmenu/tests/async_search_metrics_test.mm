#import "ZNAsyncPerformance.h"
#include "ZNPerformance.h"
#include <cassert>
int main(){@autoreleasepool{
 znperf::enable(false);ZNPerfSearchEnqueue(@"disabled");assert([ZNPerfAsyncState()[@"pending"] unsignedIntegerValue]==0);
 znperf::enable(true);znperf::reset();ZNPerfSearchEnqueue(@"a");ZNPerfSearchStarted(@"a");ZNPerfSearchCancelRequested(@"a");ZNPerfSearchCancelRequested(@"a");ZNPerfSearchFinished(@"a",YES);ZNPerfSearchFinished(@"a",YES);
 auto s=znperf::snapshot();assert(s[znperf::SearchQueueWait].total==1&&s[znperf::SearchCancelLatency].cancelled==1);assert([ZNPerfAsyncState()[@"pending"] unsignedIntegerValue]==0);
 for(int i=0;i<300;i++)ZNPerfSearchEnqueue([NSString stringWithFormat:@"%d",i]);assert([ZNPerfAsyncState()[@"pending"] unsignedIntegerValue]==256&&[ZNPerfAsyncState()[@"dropped"] unsignedIntegerValue]==44);
 for(int i=0;i<300;i++)ZNPerfSearchFinished([NSString stringWithFormat:@"%d",i],NO);assert([ZNPerfAsyncState()[@"pending"] unsignedIntegerValue]==0);
 NSLog(@"production async search queue/cancel registry/capacity/cleanup PASS");
}}
