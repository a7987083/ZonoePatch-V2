#import "V3PatchValidator.h"
#import "V3AddressResolver.h"
#import <mach/mach.h>
#include <stdint.h>
#include <limits.h>

static NSError *ZNVPError(NSInteger code, NSString *message) {
 return [NSError errorWithDomain:@"ZonoePatch.V3.PatchValidator" code:code
   userInfo:@{NSLocalizedDescriptionKey:message}];
}
static NSString *ZNVPHex(NSData *data) {
 const uint8_t *p=(const uint8_t *)data.bytes;
 NSMutableString *out=[NSMutableString stringWithCapacity:data.length*2];
 for(NSUInteger i=0;i<data.length;i++)[out appendFormat:@"%02X",p[i]];
 return out;
}
@implementation ZNV3PatchValidation
- (instancetype)initWithAddress:(ZNV3ResolvedAddress *)address patch:(NSData *)patch original:(NSData *)original {
 if((self=[super init])){_address=address;_patchBytes=[patch copy];_originalBytes=[original copy];
  _originalHex=ZNVPHex(original);_patchHex=ZNVPHex(patch);}return self;
}
@end
@implementation ZNV3PatchValidator
+ (NSData *)parsePatchBytes:(NSString *)text error:(NSError **)error {
 NSString *input=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 NSMutableString *hex=[NSMutableString string];
 NSCharacterSet *space=NSCharacterSet.whitespaceAndNewlineCharacterSet;
 for(NSUInteger i=0;i<input.length;i++){unichar c=[input characterAtIndex:i];
  if([space characterIsMember:c])continue;
  [hex appendFormat:@"%C",c];
 }
 if([hex hasPrefix:@"0x"]||[hex hasPrefix:@"0X"])[hex deleteCharactersInRange:NSMakeRange(0,2)];
 if(!hex.length||hex.length%2||hex.length>512){
  if(error)*error=ZNVPError(1,@"Patch 必须是 1–256 字节的完整十六进制字节序列");
  return nil;
 }
 NSCharacterSet *invalid=[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet];
 if([hex rangeOfCharacterFromSet:invalid].location!=NSNotFound){
  if(error)*error=ZNVPError(2,@"Patch 包含非法十六进制字符");
  return nil;
 }
 NSMutableData *bytes=[NSMutableData dataWithLength:hex.length/2];
 uint8_t *out=(uint8_t *)bytes.mutableBytes;
 for(NSUInteger i=0;i<hex.length;i+=2){
  unsigned int hi=0,lo=0;
  unichar a=[hex characterAtIndex:i],b=[hex characterAtIndex:i+1];
  hi=(a<='9'?(unsigned)(a-'0'):(unsigned)((a|32)-'a'+10));
  lo=(b<='9'?(unsigned)(b-'0'):(unsigned)((b|32)-'a'+10));
  out[i/2]=(uint8_t)((hi<<4)|lo);
 }
 return bytes;
}
+ (ZNV3PatchValidation *)validateOffset:(NSString *)offset patch:(NSString *)patch
 module:(NSString *)module error:(NSError **)error {
 NSError *e=nil;
 NSData *bytes=[self parsePatchBytes:patch error:&e];if(!bytes){if(error)*error=e;return nil;}
 ZNV3ResolvedAddress *start=[ZNV3AddressResolver resolve:offset module:module error:&e];
 if(!start){if(error)*error=e;return nil;}
 if((start.rva&3)!=0||((bytes.length&3)!=0)){
  if(error)*error=ZNVPError(3,@"ARM64 Code Patch 的 Offset 和字节长度必须按 4 字节对齐");
  return nil;
 }
 if(!start.fileBacked){
  if(error)*error=ZNVPError(4,@"目标地址不对应文件内容，无法用于后续静态构建");
  return nil;
 }
 uint64_t count=(uint64_t)bytes.length;
 if(start.rva>UINT64_MAX-(count-1)||start.runtimeVA>UINT64_MAX-(count-1)||
    start.fileOffset>UINT64_MAX-(count-1)){
  if(error)*error=ZNVPError(5,@"Patch 地址范围溢出");return nil;
 }
 // Resolve the last byte independently to ensure the complete patch stays file-backed
 // within one contiguous Mach-O segment, not merely its first instruction.
 NSString *lastOffset=[NSString stringWithFormat:@"rva:0x%llX",(unsigned long long)(start.rva+count-1)];
 ZNV3ResolvedAddress *last=[ZNV3AddressResolver resolve:lastOffset module:module error:&e];
 if(!last||!last.fileBacked||![last.segmentName isEqualToString:start.segmentName]||
    last.fileOffset!=start.fileOffset+count-1||
    last.runtimeVA!=start.runtimeVA+count-1||
    ![last.imagePath isEqualToString:start.imagePath]){
  if(error)*error=ZNVPError(6,@"Patch 跨越 Segment 或文件映射边界，拒绝读取");
  return nil;
 }
 if(start.runtimeVA>UINTPTR_MAX){
  if(error)*error=ZNVPError(7,@"当前架构无法表示目标运行时地址");return nil;
 }
 NSMutableData *original=[NSMutableData dataWithLength:bytes.length];
 vm_size_t copied=0;
 kern_return_t kr=vm_read_overwrite(mach_task_self(),(vm_address_t)start.runtimeVA,
                 (vm_size_t)bytes.length,(vm_address_t)original.mutableBytes,&copied);
 if(kr!=KERN_SUCCESS||copied!=bytes.length){
  if(error)*error=ZNVPError(8,[NSString stringWithFormat:@"无法读取目标原始字节：kern_return=%d",kr]);return nil;
 }
 if([original isEqualToData:bytes]){
  if(error)*error=ZNVPError(9,@"现场字节已经等于 Patch，无法确认未修改的 Original；请使用原版进程验证");
  return nil;
 }
 return [[ZNV3PatchValidation alloc] initWithAddress:start patch:bytes original:original];
}
@end
