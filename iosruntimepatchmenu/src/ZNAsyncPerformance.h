#pragma once
#import <Foundation/Foundation.h>
void ZNPerfSearchEnqueue(NSString *token);
void ZNPerfSearchStarted(NSString *token);
void ZNPerfSearchCancelRequested(NSString *token);
void ZNPerfSearchFinished(NSString *token,BOOL cancelled);
NSDictionary *ZNPerfAsyncState(void);
