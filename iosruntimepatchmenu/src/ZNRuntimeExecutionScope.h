#pragma once
#include "ZNImageOperationLease.h"
#include <vector>
// A code owner holds only a short loader reference and an in-flight ticket.
// It deliberately does not take Lifetime::operations across native callbacks.
class ZNCodeExecutionOwner {
 void *handle=nullptr;std::shared_ptr<znimage::Lifetime> lifetime;bool entered=false;
 ZNCodeExecutionOwner(void *h,std::shared_ptr<znimage::Lifetime> s):handle(h),lifetime(std::move(s)){}
public:
 uintptr_t base=0;uint64_t incarnation()const{return lifetime->incarnation;}
 ~ZNCodeExecutionOwner(){if(entered)lifetime->executions.leave();if(handle)dlclose(handle);}
 bool valid()const{return entered&&lifetime->live.load(std::memory_order_acquire);}
 static std::unique_ptr<ZNCodeExecutionOwner> acquire(uintptr_t address,uint64_t expected=0){
  Dl_info info={};if(!address||!dladdr((void *)address,&info)||!info.dli_fbase)return {};
  uintptr_t base=(uintptr_t)info.dli_fbase;auto state=ZNImageLifetimeForHeader(base);
  if(!state||!state->live||(expected&&state->incarnation!=expected))return {};
  bool main=base==(uintptr_t)_dyld_get_image_header(0);auto path=ZNImagePathForHeader(base);
  void *h=main?nullptr:(path.empty()?nullptr:dlopen(path.c_str(),RTLD_LAZY|RTLD_NOLOAD));if(!main&&!h)return {};
  auto owner=std::unique_ptr<ZNCodeExecutionOwner>(new ZNCodeExecutionOwner(h,state));owner->base=base;
  if(ZNImageLifetimeForHeader(base)!=state||!state->live||!state->executions.enter())return {};
  owner->entered=true;if(!owner->valid())return {};
  Dl_info pinned={};if(!dladdr((void *)address,&pinned)||(uintptr_t)pinned.dli_fbase!=base)return {};
  return owner;
 }
};
class ZNRuntimeExecutionScope;
inline thread_local ZNRuntimeExecutionScope *gZNExecutionScope=nullptr;
class ZNRuntimeExecutionScope {
 ZNRuntimeExecutionScope *previous;ZNRuntimeExecutionScope *root;
 std::vector<std::unique_ptr<ZNCodeExecutionOwner>> owners;
public:
 ZNRuntimeExecutionScope():previous(gZNExecutionScope),root(previous?previous->root:this){gZNExecutionScope=this;}
 ~ZNRuntimeExecutionScope(){gZNExecutionScope=previous;}
 ZNRuntimeExecutionScope(const ZNRuntimeExecutionScope&)=delete;
 bool retain(uintptr_t address,uint64_t expected=0){
  Dl_info info={};if(!address||!dladdr((void *)address,&info))return false;
  uintptr_t base=(uintptr_t)info.dli_fbase;
  for(auto &owner:root->owners)if(owner->base==base)return owner->valid()&&(!expected||owner->incarnation()==expected);
  if(root->owners.size()>=32)return false;auto owner=ZNCodeExecutionOwner::acquire(address,expected);if(!owner)return false;root->owners.push_back(std::move(owner));return true;
 }
 void *resolve(const char *path,const char *name){
  if(!name)return nullptr;void *temporary=(path&&*path)?dlopen(path,RTLD_LAZY|RTLD_NOLOAD):nullptr;
  void *symbol=dlsym(RTLD_DEFAULT,name);if(!symbol&&temporary)symbol=dlsym(temporary,name);
  bool held=symbol&&retain((uintptr_t)symbol);if(temporary)dlclose(temporary);return held?symbol:nullptr;
 }
 uint64_t identity(uintptr_t address){Dl_info info={};if(!dladdr((void *)address,&info))return 0;for(auto &o:root->owners)if(o->base==(uintptr_t)info.dli_fbase&&o->valid())return o->incarnation();return 0;}
};
inline void *ZNResolveExecutionSymbol(const char *path,const char *name){return gZNExecutionScope?gZNExecutionScope->resolve(path,name):nullptr;}
