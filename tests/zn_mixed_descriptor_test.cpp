#include "../ZNMixedDescriptor.hpp"
#include <cstdio>
using namespace ZNMixedDescriptor;
static int failures=0;static void check(bool ok,const char*n){if(!ok){failures++;fprintf(stderr,"FAIL %s\n",n);}}
int main(){
 Package p;p.records={
 {ZNTypedDescriptor::FeatureKind::Input,ZNValueCodec::Type::Int32,0x1000,false,"0","100","",""},
 {ZNTypedDescriptor::FeatureKind::Slider,ZNValueCodec::Type::Float32,0x2000,true,"0","10","1","2"}};
 p.features={{"uuid-input","输入框",0,1,ZNTypedDescriptor::FeatureKind::Input,ZNValueCodec::Type::Int32},
 {"uuid-slider","滑条",1,1,ZNTypedDescriptor::FeatureKind::Slider,ZNValueCodec::Type::Float32}};
 std::vector<uint8_t> out;std::string e;
 check(encode(p,out,e),"ZNM2 encoding");
 Package q;check(decode(out.data(),out.size(),q,e),"ZNM2 decoding");
 check(q.features.size()==2&&q.features[0].id=="uuid-input"&&q.features[1].name=="滑条","feature ID/name roundtrip");
 check(!ZNTypedDescriptor::decode(out.data(),out.size(),q.records,e),"legacy ZNT1 fail closed");
 auto dup=p;dup.features[1].id=dup.features[0].id;std::vector<uint8_t> buf;
 check(!encode(dup,buf,e),"duplicate feature ID rejected");
 auto overlap=p;overlap.features[1].start=0;
 check(!encode(overlap,buf,e),"overlapping ownership rejected");
 auto bad=p;bad.features[1].type=ZNValueCodec::Type::Int64;
 check(!encode(bad,buf,e),"kind/type mismatch rejected");
 bad=p;bad.records[1].rva=0x1000;check(!encode(bad,buf,e),"overlap RVA rejected");
 auto renamed=p;renamed.features[0].name="Renamed";
 check(encode(renamed,buf,e),"rename keeps ID independent");
 auto corrupt=out;corrupt[4]=1;check(!decode(corrupt.data(),corrupt.size(),q,e),"version rejected");
 corrupt=out;corrupt.pop_back();check(!decode(corrupt.data(),corrupt.size(),q,e),"truncation rejected");
 printf("ZNM2 identity tests: %s (%d)\n",failures?"FAIL":"PASS",failures);return failures?1:0;
}
