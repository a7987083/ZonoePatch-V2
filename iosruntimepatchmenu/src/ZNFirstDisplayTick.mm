#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include "ZNPerformance.h"
@interface ZNFirstTickObserver:NSObject
@property(nonatomic,strong) CADisplayLink *link;
@end
@implementation ZNFirstTickObserver {
 std::shared_ptr<znperf::Ticket> ticket;
}
- (void)start {ticket=znperf::ticket(znperf::FirstDisplayTick);if(!ticket)return;self.link=[CADisplayLink displayLinkWithTarget:self selector:@selector(fired:)];[self.link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];__weak ZNFirstTickObserver *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[weak timedOut];});}
- (void)fired:(CADisplayLink *)link{(void)link;if(ticket)ticket->finish();[self.link invalidate];self.link=nil;ticket.reset();}
- (void)timedOut {if(ticket)ticket->finish(znperf::Failed);[self.link invalidate];self.link=nil;ticket.reset();}
@end
extern "C" void ZNObserveFirstDisplayTick(void){if(!znperf::state().enabled.load())return;[[ZNFirstTickObserver new]start];}
