#import "ZNPerformanceReport.h"
#include "ZNPerformance.h"
NSDictionary<NSString *,id> *ZNPerformanceSnapshot(void){
 auto samples=znperf::snapshot();NSMutableDictionary *metrics=[NSMutableDictionary dictionary];
 for(unsigned i=0;i<znperf::Count;i++){
  const auto &s=samples[i];NSString *name=[NSString stringWithUTF8String:znperf::name((znperf::Metric)i)];
  metrics[name]=@{@"totalCount":@(s.total),@"retainedCount":@(s.used),@"medianNs":@(znperf::percentile(s,50)),@"p95Ns":@(znperf::percentile(s,95)),@"status":s.used?@"measured":@"未验证"};
 }
 return @{@"schema":@"zonoe.performance/v1",@"clock":@"steady_clock",@"enabled":@(znperf::state().enabled.load()),@"sampleCapacityPerMetric":@1024,@"quantilePolicy":@"sorted retained samples; floor((N-1)*p/100)",@"metrics":metrics};
}
void ZNPerformanceReset(void){znperf::reset();}
void ZNPerformanceEnable(BOOL enabled){znperf::enable(enabled);}
