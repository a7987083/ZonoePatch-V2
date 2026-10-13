#import <Foundation/Foundation.h>
#import "ZNActivationStageRunner.h"
#include <cassert>
@interface ZNRuntimeMenuControllerV040:NSObject @end
@implementation ZNRuntimeMenuControllerV040 @end
int main(){@autoreleasepool{__block unsigned calls=0;BOOL threw=NO;
 @try{ZNRunActivationStage(@"FeatureGroupUI",^{calls++;});}@catch(NSException *e){(void)e;threw=YES;}
 assert(threw&&calls==0);
 ZNRunActivationStage(@"RuntimeMenu",^{calls++;});ZNRunActivationStage(@"RuntimeMenu",^{calls++;});assert(calls==1);
 ZNRunActivationStage(@"FeatureGroupUI",^{calls++;});assert(calls==2);
 @try{ZNRunActivationStage(@"Fault",^{[NSException raise:@"injected" format:@"fault"];});}@catch(NSException *e){(void)e;}
 ZNRunActivationStage(@"Fault",^{calls++;});assert(calls==3);
 puts("activation dependency/idempotency/failure-state PASS");
}}
