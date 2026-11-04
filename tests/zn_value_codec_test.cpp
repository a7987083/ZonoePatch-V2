#include "../ZNValueCodec.hpp"
#include <cassert>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>
using namespace ZNValueCodec;
static int fails=0;
static void check(bool ok,const char *label){if(!ok){++fails;std::cerr<<"FAIL "<<label<<"\n";}}
static void roundtrip(Type t,const std::string &value,const std::vector<uint8_t> &expected){
 std::vector<uint8_t> b;std::string error,decoded;
 check(encode(t,value,b,error),"encode valid literal");
 check(b==expected,"little endian encoding");
 check(decode(t,b.data(),b.size(),decoded,error),"decode exact width");
 std::vector<uint8_t> round;check(encode(t,decoded,round,error)&&round==b,"roundtrip bits");
}
static void reject(Type t,const std::string &value){
 std::vector<uint8_t> b={0xAA};std::string error;
 check(!encode(t,value,b,error),"reject malformed/overflow");
 check(b==std::vector<uint8_t>({0xAA}),"do not change output on failure");
}
int main(){
 roundtrip(Type::Int8,"-128",{0x80});
 roundtrip(Type::UInt8,"255",{0xFF});
 roundtrip(Type::Int16,"-32768",{0,0x80});
 roundtrip(Type::UInt16,"65535",{0xFF,0xFF});
 roundtrip(Type::Int32,"-2147483648",{0,0,0,0x80});
 roundtrip(Type::UInt32,"4294967295",{0xFF,0xFF,0xFF,0xFF});
 roundtrip(Type::Int64,"-9223372036854775808",{0,0,0,0,0,0,0,0x80});
 roundtrip(Type::UInt64,"18446744073709551615",{0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF});
 roundtrip(Type::Float32,"1.5",{0,0,0xC0,0x3F});
 roundtrip(Type::Float64,"1.5",{0,0,0,0,0,0,0xF8,0x3F});
 reject(Type::Int8,"128");reject(Type::Int8,"-129");
 reject(Type::UInt8,"256");reject(Type::UInt8,"-1");
 reject(Type::Int16,"32768");reject(Type::UInt16,"65536");
 reject(Type::Int32,"2147483648");reject(Type::UInt32,"4294967296");
 reject(Type::Int64,"9223372036854775808");
 reject(Type::UInt64,"18446744073709551616");
 reject(Type::Int32,"1.0");reject(Type::Float32,"1.0foo");
 reject(Type::Float64,"nan");reject(Type::Float64,"inf");
 reject(Type::Int64,"+");reject(Type::Float64,"1e");
 reject(Type::Int64," 12");reject(Type::UInt32,"0x10");
 std::vector<uint8_t> bad={1,2};std::string out="untouched",err;
 check(!decode(Type::UInt32,bad.data(),bad.size(),out,err),"reject wrong width");
 check(out=="untouched","decode preserves output on failure");
 std::cout<<"ZNValueCodec regression: "<<(fails?"FAIL":"PASS")<<" ("<<fails<<" failures)\n";
 return fails?1:0;
}
