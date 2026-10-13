#include "ZNScalarParser.h"
#include <cassert>
#include <cstdio>
int main(){uint64_t u=7;int64_t i=7;double d=7;
 assert(!ZNParseUnsignedScalar("-1",&u));assert(u==7);
 assert(!ZNParseUnsignedScalar("  -0x1 ",&u));
 assert(ZNParseUnsignedScalar("18446744073709551615",&u)&&u==UINT64_MAX);
 assert(!ZNParseUnsignedScalar("18446744073709551616",&u));
 assert(ZNParseUnsignedScalar(" +0x10 ",&u)&&u==16);
 assert(!ZNParseUnsignedScalar("42junk",&u));assert(!ZNParseUnsignedScalar("",&u));
 assert(ZNParseSignedScalar("-9223372036854775808",&i)&&i==INT64_MIN);
 assert(!ZNParseSignedScalar("9223372036854775808",&i));
 assert(ZNParseFiniteScalar(" 1.25 ",&d)&&d==1.25);
 assert(!ZNParseFiniteScalar("nan",&d));assert(!ZNParseFiniteScalar("inf",&d));assert(!ZNParseFiniteScalar("1e10000",&d));
 puts("production scalar parser boundaries PASS");
}
