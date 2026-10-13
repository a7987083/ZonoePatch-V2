#define ZN_UI_TRACE_IMPLEMENTATION
#import "ZNUIInstallationTrace.h"
#include <atomic>
#include <mutex>
static std::atomic<bool> traceEnabled{false};
static std::mutex traceLock;
static NSMutableArray *events;
static uint64_t total=0;
static NSString *const stageKey=@"zonoe.private.ui-install-trace.stage";
void ZNUITraceEnable(BOOL enabled){traceEnabled.store(enabled,std::memory_order_relaxed);}
void ZNUITraceReset(void){std::lock_guard<std::mutex> lock(traceLock);events=[NSMutableArray array];total=0;}
NSString *ZNUITraceStage(NSString *stage){NSMutableDictionary *dict=NSThread.currentThread.threadDictionary;NSString *previous=dict[stageKey];if(stage)dict[stageKey]=stage;else[dict removeObjectForKey:stageKey];return previous;}
static NSString *selName(Method method){return method?NSStringFromSelector(method_getName(method)):@"<nil>";}
static void record(NSString *kind,Method first,Method second,IMP beforeFirst,IMP beforeSecond,const char *source,unsigned line){
 NSDictionary *event=@{@"kind":kind,@"source":[NSString stringWithUTF8String:source?:""]?:@"",@"line":@(line),@"stage":NSThread.currentThread.threadDictionary[stageKey]?:@"outside-stage",@"first":selName(first),@"second":selName(second),@"firstMethod":@((uintptr_t)first),@"secondMethod":@((uintptr_t)second),@"beforeFirst":@((uintptr_t)beforeFirst),@"beforeSecond":@((uintptr_t)beforeSecond),@"afterFirst":@((uintptr_t)(first?method_getImplementation(first):nullptr)),@"afterSecond":@((uintptr_t)(second?method_getImplementation(second):nullptr))};
 std::lock_guard<std::mutex> lock(traceLock);++total;if(!events)events=[NSMutableArray array];if(events.count<4096)[events addObject:event];
}
void ZNUITraceExchange(Method first,Method second,const char *source,unsigned line){
 bool enabled=traceEnabled.load(std::memory_order_relaxed);IMP a=enabled&&first?method_getImplementation(first):nullptr,b=enabled&&second?method_getImplementation(second):nullptr;
 method_exchangeImplementations(first,second);if(enabled)record(@"exchange",first,second,a,b,source,line);
}
IMP ZNUITraceSet(Method method,IMP implementation,const char *source,unsigned line){IMP prior=method_setImplementation(method,implementation);if(traceEnabled.load(std::memory_order_relaxed))record(@"set",method,nullptr,prior,implementation,source,line);return prior;}
NSDictionary *ZNUITraceSnapshot(void){std::lock_guard<std::mutex> lock(traceLock);return @{@"schema":@"zonoe.ui-install/v1",@"enabled":@(traceEnabled.load()),@"total":@(total),@"retained":@(events.count),@"complete":@(total==events.count),@"events":[events copy]?:@[],@"scope":@"observed installation Method/IMP addresses in this process; static self-call graph is separate"};}
