#import "ZNIL2CPPResolver.h"
#include "ZNImageOperationLease.h"
#include <cassert>
int main(int argc,char **argv){@autoreleasepool{
 assert(argc==2);ZNCurrentImageGeneration();void *handle=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);assert(handle);Dl_info info={};assert(dladdr(dlsym(handle,"FixtureRun"),&info));uintptr_t base=(uintptr_t)info.dli_fbase;auto state=ZNImageLifetimeForHeader(base);assert(state);ZNIL2CPPResolver *r=[ZNIL2CPPResolver sharedResolver];
 for(int i=0;i<100;i++){[r refresh];assert(r.isAvailable);NSDictionary *result=[r resolveMethodAssembly:@"Assembly-CSharp.dll" namespace:@"Tests" className:@"Fixture" method:@"Run" argumentCount:0];assert(result&&[result[@"methodInfo"] unsignedLongLongValue]);}
 assert(dlclose(handle)==0);assert(!state->live);[r refresh];assert(!r.isAvailable);assert(![r resolveMethodAssembly:@"Assembly-CSharp.dll" namespace:@"Tests" className:@"Fixture" method:@"Run" argumentCount:0]);puts("production resolver 100 refresh/resolve calls balanced loader retains; unload revokes API availability PASS (synthetic IL2CPP export backend)");
}}
