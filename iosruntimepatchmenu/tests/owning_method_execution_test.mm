#import "ZNIL2CPPOwningMethodResolver.h"
#include "ZNRuntimeExecutionScope.h"
#include <cassert>
int main(int argc,char **argv){@autoreleasepool{
 assert(argc==2);ZNCurrentImageGeneration();uint64_t prior=0;
 for(int pass=0;pass<2;pass++){
  void *h=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);assert(h);uintptr_t f=(uintptr_t)dlsym(h,"FixtureRun");Dl_info info={};assert(dladdr((void*)f,&info));auto state=ZNImageLifetimeForHeader((uintptr_t)info.dli_fbase);assert(state&&state->incarnation!=prior);
  NSString *error=nil;NSArray *candidates=[[ZNIL2CPPOwningMethodResolver sharedResolver] resolveRVA:f-(uintptr_t)info.dli_fbase limit:16 error:&error];
  assert(candidates.count==1);NSDictionary *candidate=candidates[0];assert([candidate[@"methodPointer"] unsignedLongLongValue]==f);assert([candidate[@"runtimeImageIncarnation"] unsignedLongLongValue]==state->incarnation);assert(state->executions.inFlight()==0);
  {ZNRuntimeExecutionScope scope;assert(scope.retain(f,state->incarnation));if(prior)assert(!scope.retain(f,prior));assert(((int(*)(void))f)()==42);}
  prior=state->incarnation;assert(dlclose(h)==0&&!state->live);
 }
 puts("actual OwningMethodResolver scan/API execution scopes/candidate incarnation/unload-reload PASS (synthetic IL2CPP metadata)");
}}
