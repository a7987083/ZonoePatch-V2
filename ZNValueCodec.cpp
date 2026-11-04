#include "ZNValueCodec.hpp"
#include <cerrno>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <limits>
#include <locale>
#include <sstream>

namespace ZNValueCodec {
size_t width(Type t) {
 switch(t) {
  case Type::Int8: case Type::UInt8: return 1;
  case Type::Int16: case Type::UInt16: return 2;
  case Type::Int32: case Type::UInt32: case Type::Float32: return 4;
  case Type::Int64: case Type::UInt64: case Type::Float64: return 8;
 } return 0;
}
static bool decimalSyntax(const std::string &s, bool signedValue, bool floating) {
 if(s.empty() || s.size()>128)return false;
 size_t i=0;
 if(s[i]=='-' || s[i]=='+'){if(!signedValue && s[i]=='-')return false;++i;}
 if(i==s.size())return false;
 bool any=false, dot=false, exp=false, expDigits=false;
 for(;i<s.size();++i){
  char c=s[i];
  if(c>='0'&&c<='9'){any=true;if(exp)expDigits=true;continue;}
  if(floating && c=='.' && !dot && !exp){dot=true;continue;}
  if(floating && (c=='e'||c=='E') && !exp && any){
   exp=true;expDigits=false;
   if(i+1<s.size() && (s[i+1]=='+'||s[i+1]=='-'))++i;
   continue;
  }
  return false;
 }
 return any && (!exp || expDigits);
}
static bool signedType(Type t){return t==Type::Int8||t==Type::Int16||t==Type::Int32||t==Type::Int64;}
static bool unsignedType(Type t){return t==Type::UInt8||t==Type::UInt16||t==Type::UInt32||t==Type::UInt64;}
static uint64_t maskFor(size_t n){return n==8?UINT64_MAX:((uint64_t(1)<<(n*8))-1);}
static void littleBytes(uint64_t bits, size_t n, std::vector<uint8_t> &out) {
 std::vector<uint8_t> candidate(n);
 for(size_t i=0;i<n;++i)candidate[i]=uint8_t(bits>>(i*8));
 out.swap(candidate);
}
bool encode(Type t,const std::string &s,std::vector<uint8_t> &out,std::string &error) {
 const size_t n=width(t);
 if(!n){error="unknown numeric type";return false;}
 const bool integral=signedType(t)||unsignedType(t);
 if(!decimalSyntax(s,signedType(t)||!integral,!integral)){error="invalid decimal literal";return false;}
 if(integral){
  errno=0; char *end=nullptr;
  if(signedType(t)){
   long long value=strtoll(s.c_str(),&end,10);
   if(errno==ERANGE||!end||*end){error="signed integer overflow";return false;}
   int bits=int(n*8);
   int64_t minimum=bits==64?INT64_MIN:-(int64_t(1)<<(bits-1));
   int64_t maximum=bits==64?INT64_MAX:((int64_t(1)<<(bits-1))-1);
   if(value<minimum||value>maximum){error="value outside signed type range";return false;}
   littleBytes(uint64_t(value),n,out);
  }else{
   unsigned long long value=strtoull(s.c_str(),&end,10);
   if(errno==ERANGE||!end||*end||value>maskFor(n)){error="unsigned integer overflow";return false;}
   littleBytes(uint64_t(value),n,out);
  }
 }else{
  errno=0;char *end=nullptr;
  double value=strtod(s.c_str(),&end);
  if(!end||*end||!std::isfinite(value)|| (errno==ERANGE && value==HUGE_VAL)){
   error="invalid or overflowing float";return false;
  }
  if(t==Type::Float32){
   float f=static_cast<float>(value);
   if(!std::isfinite(f)){error="Float32 overflow";return false;}
   uint32_t bits=0;static_assert(sizeof(f)==sizeof(bits),"float width");
   std::memcpy(&bits,&f,sizeof(bits));littleBytes(bits,4,out);
  }else{
   uint64_t bits=0;std::memcpy(&bits,&value,sizeof(bits));littleBytes(bits,8,out);
  }
 }
 error.clear();return true;
}
bool decode(Type t,const uint8_t *data,size_t length,std::string &out,std::string &error){
 const size_t n=width(t);
 if(!data||!n||length!=n){error="incorrect numeric byte width";return false;}
 uint64_t bits=0;
 for(size_t i=0;i<n;++i)bits|=uint64_t(data[i])<<(i*8);
 std::ostringstream stream;stream.imbue(std::locale::classic());
 if(signedType(t)){
  if(n<8 && (bits & (uint64_t(1)<<(n*8-1))))bits|=~maskFor(n);
  stream<<static_cast<int64_t>(bits);
 }else if(unsignedType(t)){
  stream<<bits;
 }else if(t==Type::Float32){
  uint32_t word=static_cast<uint32_t>(bits);float f=0;
  std::memcpy(&f,&word,sizeof(f));
  if(!std::isfinite(f)){error="non-finite float cannot be displayed";return false;}
  stream<<std::setprecision(std::numeric_limits<float>::max_digits10)<<f;
 }else{
  double d=0;std::memcpy(&d,&bits,sizeof(d));
  if(!std::isfinite(d)){error="non-finite double cannot be displayed";return false;}
  stream<<std::setprecision(std::numeric_limits<double>::max_digits10)<<d;
 }
 out=stream.str();error.clear();return true;
}
} // namespace
