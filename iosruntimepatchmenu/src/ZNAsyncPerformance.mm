#import "ZNAsyncPerformance.h"
#include "ZNPerformance.h"
#include <map>
#include <string>
struct ZNPerfSearchSpan {std::shared_ptr<znperf::Ticket> queue,cancel;};
static std::mutex spansLock;
static std::map<std::string,ZNPerfSearchSpan> spans;
static uint64_t dropped=0;
static std::string key(NSString *token){return token.UTF8String?:"";}
void ZNPerfSearchEnqueue(NSString *token){if(!token.length||!znperf::state().enabled.load())return;std::lock_guard<std::mutex> lock(spansLock);if(spans.size()>=256){++dropped;return;}spans[key(token)]={znperf::ticket(znperf::SearchQueueWait),{}};}
void ZNPerfSearchStarted(NSString *token){std::shared_ptr<znperf::Ticket> ticket;{std::lock_guard<std::mutex> lock(spansLock);auto it=spans.find(key(token));if(it==spans.end())return;ticket=it->second.queue;it->second.queue.reset();}if(ticket)ticket->finish();}
void ZNPerfSearchCancelRequested(NSString *token){std::lock_guard<std::mutex> lock(spansLock);auto it=spans.find(key(token));if(it!=spans.end()&&!it->second.cancel)it->second.cancel=znperf::ticket(znperf::SearchCancelLatency);}
void ZNPerfSearchFinished(NSString *token,BOOL cancelled){ZNPerfSearchSpan span;{std::lock_guard<std::mutex> lock(spansLock);auto it=spans.find(key(token));if(it==spans.end())return;span=it->second;spans.erase(it);}if(span.queue)span.queue->finish(znperf::Failed);if(span.cancel)span.cancel->finish(cancelled?znperf::Cancelled:znperf::Completed);}
NSDictionary *ZNPerfAsyncState(void){std::lock_guard<std::mutex> lock(spansLock);return @{@"pending":@(spans.size()),@"capacity":@256,@"dropped":@(dropped)};}
