#pragma once
#import <Foundation/Foundation.h>
#import "ZNValueTypeModel.h"
#include "ZNImageOperationLease.h"
#include <float.h>
#include <math.h>
#include <string.h>
inline BOOL ZNM56StoreCell(ZNImageOperationLease &lease,uintptr_t cell,uint64_t raw,size_t width,NSString **error){
 if(lease.store(cell,raw,width))return YES;
 if(error)*error=@"Value Cell 写入租约已撤销或地址不可写";return NO;
}
inline BOOL ZNM56ScanSigned(NSString *text,long long *out){NSScanner *s=[NSScanner scannerWithString:text?:@""];long long v=0;if(![s scanLongLong:&v]||!s.isAtEnd)return NO;if(out)*out=v;return YES;}
inline BOOL ZNM56ScanUnsigned(NSString *text,unsigned long long *out){NSString *t=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(!t.length||[t hasPrefix:@"-"])return NO;NSScanner *s=[NSScanner scannerWithString:t];unsigned long long v=0;if(![s scanUnsignedLongLong:&v]||!s.isAtEnd)return NO;if(out)*out=v;return YES;}

inline BOOL ZNM56WriteTextToCell(NSString *text,ZNValueType type,uintptr_t cell,ZNImageOperationLease &lease,NSString **error){
    if(type==ZNValueTypeI32){long long v=0;if(!ZNM56ScanSigned(text,&v)||v<INT32_MIN||v>INT32_MAX){if(error)*error=@"不是有效 I32";return NO;}uint32_t raw=(uint32_t)(int32_t)v;return ZNM56StoreCell(lease,cell,raw,4,error);}
    if(type==ZNValueTypeU32){unsigned long long v=0;if(!ZNM56ScanUnsigned(text,&v)||v>UINT32_MAX){if(error)*error=@"不是有效 U32";return NO;}return ZNM56StoreCell(lease,cell,(uint32_t)v,4,error);}
    if(type==ZNValueTypeI64){long long v=0;if(!ZNM56ScanSigned(text,&v)){if(error)*error=@"不是有效 I64";return NO;}return ZNM56StoreCell(lease,cell,(uint64_t)v,8,error);}
    if(type==ZNValueTypeU64){unsigned long long v=0;if(!ZNM56ScanUnsigned(text,&v)){if(error)*error=@"不是有效 U64";return NO;}return ZNM56StoreCell(lease,cell,(uint64_t)v,8,error);}
    if(type==ZNValueTypeF32){NSScanner *s=[NSScanner scannerWithString:text?:@""];double d=0;if(![s scanDouble:&d]||!s.isAtEnd||!isfinite(d)){if(error)*error=@"不是有效 F32";return NO;}if(fabs(d)>FLT_MAX){if(error)*error=@"F32 超出有限范围";return NO;}float f=(float)d;uint32_t raw=0;memcpy(&raw,&f,4);return ZNM56StoreCell(lease,cell,raw,4,error);}
    if(type==ZNValueTypeF64){NSScanner *s=[NSScanner scannerWithString:text?:@""];double d=0;if(![s scanDouble:&d]||!s.isAtEnd||!isfinite(d)){if(error)*error=@"不是有效 F64";return NO;}uint64_t raw=0;memcpy(&raw,&d,8);return ZNM56StoreCell(lease,cell,raw,8,error);}
    if(error)*error=@"Value Cell 不支持 Auto/未知类型";return NO;
}

