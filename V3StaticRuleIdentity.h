#pragma once
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#include <stdint.h>
// P6-C. Build-bound identity is stored in the existing 120-byte feature description.
// This is a compatibility guard against applying a different saved rule to the same RVA,
// not a cryptographic attestation of the on-disk Mach-O.
static inline NSString *ZNP6RuleBinding(NSString *uuid, NSString *ruleID, uint64_t rva, NSData *patch) {
 if(!uuid.length||!ruleID.length||!patch.length)return nil;
 NSMutableData *data=[NSMutableData data];
 NSData *prefix=[@"ZonoePatch.P6.StaticRule.v1" dataUsingEncoding:NSUTF8StringEncoding];
 [data appendData:prefix];
 for(NSString *component in @[uuid.uppercaseString,ruleID]){
  NSData *part=[component dataUsingEncoding:NSUTF8StringEncoding];
  uint64_t n=CFSwapInt64HostToBig((uint64_t)part.length);
  [data appendBytes:&n length:sizeof(n)];
  [data appendData:part];
 }
 uint64_t r=CFSwapInt64HostToBig(rva),n=CFSwapInt64HostToBig(patch.length);
 [data appendBytes:&r length:sizeof(r)];[data appendBytes:&n length:sizeof(n)];
 [data appendData:patch];
 unsigned char hash[CC_SHA256_DIGEST_LENGTH]={};
 CC_SHA256(data.bytes,(CC_LONG)data.length,hash);
 NSMutableString *identity=[NSMutableString stringWithString:@"P6C1:"];
 for(NSUInteger i=0;i<sizeof(hash);i++)[identity appendFormat:@"%02X",hash[i]];
 return identity;
}
