#pragma once
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <ctype.h>
#include <math.h>
static inline bool ZNScalarFinished(const char *end) {
    if(!end)return false;
    while(*end && isspace((unsigned char)*end))++end;
    return *end=='\0';
}
static inline bool ZNParseUnsignedScalar(const char *text,uint64_t *out) {
    if(!text)return false;
    while(*text && isspace((unsigned char)*text))++text;
    if(!*text || *text=='-')return false;
    errno=0;char *end=NULL;unsigned long long value=strtoull(text,&end,0);
    if(errno || end==text || !ZNScalarFinished(end))return false;
    if(out)*out=(uint64_t)value;
    return true;
}
static inline bool ZNParseSignedScalar(const char *text,int64_t *out) {
    if(!text)return false;
    errno=0;char *end=NULL;long long value=strtoll(text,&end,0);
    if(errno || end==text || !ZNScalarFinished(end))return false;
    if(out)*out=(int64_t)value;
    return true;
}
static inline bool ZNParseFiniteScalar(const char *text,double *out) {
    if(!text)return false;
    errno=0;char *end=NULL;double value=strtod(text,&end);
    if(errno || end==text || !ZNScalarFinished(end) || !isfinite(value))return false;
    if(out)*out=value;
    return true;
}
