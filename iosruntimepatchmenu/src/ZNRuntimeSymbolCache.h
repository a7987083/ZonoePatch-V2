#pragma once
#include "ZNRuntimeExecutionScope.h"
#include <mutex>
// Cached values never own loader handles. Every hit must acquire the exact
// recorded incarnation in the current execution scope before becoming callable.
class ZNRuntimeSymbolCache {
 std::mutex mutex;uintptr_t address=0;uint64_t incarnation=0;std::string pathKey,nameKey;
public:
 void *resolve(ZNRuntimeExecutionScope &scope,const char *path,const char *name){
  if(!name)return nullptr;std::string p=path?path:"",n=name;uintptr_t old=0;uint64_t generation=0;
  {std::lock_guard<std::mutex> g(mutex);if(pathKey==p&&nameKey==n){old=address;generation=incarnation;}}
  if(old&&scope.retain(old,generation))return (void *)old;
  void *fresh=scope.resolve(path,name);if(!fresh)return nullptr;uint64_t identity=scope.identity((uintptr_t)fresh);if(!identity)return nullptr;
  {std::lock_guard<std::mutex> g(mutex);address=(uintptr_t)fresh;incarnation=identity;pathKey=p;nameKey=n;}
  return fresh;
 }
};
