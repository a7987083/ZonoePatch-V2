#pragma once
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#ifdef __cplusplus
extern "C" {
#endif
void ZNUITraceEnable(BOOL enabled);
void ZNUITraceReset(void);
NSDictionary *ZNUITraceSnapshot(void);
NSString *ZNUITraceStage(NSString *stage);
void ZNUITraceExchange(Method first,Method second,const char *source,unsigned line);
IMP ZNUITraceSet(Method method,IMP implementation,const char *source,unsigned line);
#ifdef __cplusplus
}
#endif
#ifndef ZN_UI_TRACE_IMPLEMENTATION
#define method_exchangeImplementations(a,b) ZNUITraceExchange((a),(b),__FILE__,__LINE__)
#define method_setImplementation(m,i) ZNUITraceSet((m),(i),__FILE__,__LINE__)
#endif
