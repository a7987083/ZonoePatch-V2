#include "ZNGeneratedDataLayout.h"
#include <vector>
#include <cassert>
#include <cstdio>
int main(){uint64_t n=0;
 assert(!ZNCheckedAdd64(UINT64_MAX,1,&n));assert(!ZNCheckedAlign8(UINT64_MAX,&n));
 assert(!ZNCheckedRange64(64,UINT64_MAX,8));assert(!ZNCheckedRange64(64,63,2));
 // Deliberately unaligned serialized input: production parser uses memcpy.
 std::vector<uint8_t> bytes(1024);uint8_t *p=bytes.data()+1;
 ZN44StaticHeader h={};h.magic0=ZN44_STATIC_MAGIC0;h.magic1=ZN44_STATIC_MAGIC1;h.version=ZN44_STATIC_VERSION_V3;
 h.entrySize=sizeof(ZN44StaticEntry);h.flags=ZN44_STATIC_HEADER_FLAG_GENERATED_LAYOUT_V1;
 memcpy(p,&h,sizeof(h));uint64_t d=ZNGeneratedDataAlign8(sizeof(h));
 ZN44FeatureDescriptionHeader desc={};desc.magic0=ZN44_FEATURE_DESC_MAGIC0;desc.magic1=ZN44_FEATURE_DESC_MAGIC1;
 desc.entrySize=sizeof(ZN44FeatureDescriptionEntry);memcpy(p+d,&desc,sizeof(desc));
 assert(ZNGeneratedDataLayoutV1LocateRuntimeAction(p,1023,&n));
 assert(!ZNGeneratedDataLayoutV1LocateRuntimeAction(p,d+sizeof(desc)-1,&n));
 h.count=UINT32_MAX;memcpy(p,&h,sizeof(h));assert(!ZNGeneratedDataLayoutV1LocateRuntimeAction(p,1023,&n));
 // 100k deterministic malformed buffers: bounded production layout reader.
 uint32_t seed=1;
 for(unsigned i=0;i<100000;i++){
  for(unsigned j=0;j<256;j++){seed=seed*1664525u+1013904223u;p[j]=(uint8_t)(seed>>24);}
  assert(!ZNGeneratedDataLayoutV1LocateRuntimeAction(p,i%256,&n));
 }
 puts("checked arithmetic/unaligned/truncated/malformed production layout PASS");
}
