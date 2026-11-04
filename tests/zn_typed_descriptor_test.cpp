#include "../ZNTypedDescriptor.hpp"
#include <cstdio>
#include <string>
#include <vector>
using namespace ZNTypedDescriptor;
using ZNValueCodec::Type;
static int failures=0;
static void check(bool value,const char *name){
 if(!value){++failures;std::fprintf(stderr,"FAIL: %s\n",name);}
}
static Record input(Type type,uint64_t rva,const std::string &min,const std::string &max){
 return {FeatureKind::Input,type,rva,false,min,max,"",""};
}
static Record slider(Type type,uint64_t rva,const std::string &min,const std::string &max,
                     const std::string &step,const std::string &def){
 return {FeatureKind::Slider,type,rva,true,min,max,step,def};
}
static void reject(const std::vector<Record> &records){
 std::vector<uint8_t> out={0xAA};std::string error;
 check(!encode(records,out,error),"reject invalid typed descriptor");
 check(out==std::vector<uint8_t>({0xAA}),"preserve buffer after failure");
}
int main(){
 std::string error;std::vector<uint8_t> bytes;
 std::vector<Record> values={
  input(Type::Int8,0x1001,"-128","127"),
  input(Type::UInt8,0x1002,"0","255"),
  input(Type::Int16,0x1004,"-32768","32767"),
  input(Type::UInt16,0x1006,"0","65535"),
  input(Type::Int32,0x1008,"-2147483648","2147483647"),
  input(Type::UInt32,0x100C,"0","4294967295"),
  input(Type::Int64,0x1010,"-9223372036854775808","9223372036854775807"),
  input(Type::UInt64,0x1018,"0","18446744073709551615"),
  slider(Type::Float32,0x1020,"-10","10","0.5","1.5"),
  slider(Type::Float64,0x1028,"-10","10","0.125","1.25")
 };
 check(encode(values,bytes,error),"encode ten typed values");
 check(bytes.size()==12+10*48,"versioned descriptor length");
 check(bytes.size()>12 && bytes[0]=='Z'&&bytes[1]=='N'&&bytes[2]=='T'&&bytes[3]=='1',"descriptor magic");
 std::vector<Record> restored;
 check(decode(bytes.data(),bytes.size(),restored,error),"decode ten typed values");
 check(restored.size()==values.size(),"restore record count");
 if(restored.size()==values.size()){
  check(restored[6].minimum=="-9223372036854775808"&&restored[6].maximum=="9223372036854775807",
        "signed 64-bit extrema preserved exactly");
  check(restored[7].maximum=="18446744073709551615","unsigned 64-bit maximum preserved exactly");
  check(restored[8].requiresEnableSwitch&&restored[8].defaultValue=="1.5","slider enable gate preserved");
  check(!restored[2].requiresEnableSwitch&&restored[2].step.empty(),"input has no slider fields");
 }
 std::vector<uint8_t> again;
 check(encode(restored,again,error)&&again==bytes,"descriptor binary roundtrip");
 reject({input(Type::UInt8,0,"0","1")});
 reject({input(Type::UInt8,0x1001,"-1","100")});
 reject({input(Type::Int32,0x1001,"0","10")});
 reject({input(Type::UInt32,0x1004,"10","1")});
 reject({input(Type::UInt64,0x1008,"0","18446744073709551616")});
 reject({slider(Type::Int32,0x2000,"0","10","0","3")});
 reject({slider(Type::Int32,0x2000,"0","10","1","11")});
 reject({slider(Type::Float32,0x2000,"0","10","1","nan")});
 Record ungated=slider(Type::Int32,0x2000,"0","10","1","1");
 ungated.requiresEnableSwitch=false;reject({ungated});
 Record inputWithStep=input(Type::Int8,0x2001,"0","10");inputWithStep.step="1";
 reject({inputWithStep});
 reject({input(Type::Int32,0x3000,"0","10"),input(Type::UInt8,0x3002,"0","5")});
 auto malformed=bytes;malformed[4]=2;
 check(!decode(malformed.data(),malformed.size(),restored,error),"reject unknown descriptor version");
 malformed=bytes;malformed[11]=1;
 check(!decode(malformed.data(),malformed.size(),restored,error),"reject nonzero header reserved");
 malformed=bytes;malformed[12+11]=1;
 check(!decode(malformed.data(),malformed.size(),restored,error),"reject wrong typed width");
 malformed=bytes;malformed.push_back(0);
 check(!decode(malformed.data(),malformed.size(),restored,error),"reject trailing bytes");
 malformed=bytes;malformed[12+48*8+10]=0;
 check(!decode(malformed.data(),malformed.size(),restored,error),"reject missing slider gate");
 check(restored.size()==values.size(),"decode failure leaves existing output intact");
 std::printf("P10.3 Typed Descriptor: %s (%d failures)\n",failures?"FAIL":"PASS",failures);
 return failures?1:0;
}
