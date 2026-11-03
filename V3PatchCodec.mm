#import "V3PatchCodec.h"

@implementation ZNV3PatchCodec
+ (NSData *)codeBytesFromText:(NSString *)text error:(NSError **)error {
 NSString *input=[text isKindOfClass:NSString.class] ? text : @"";
 NSMutableString *hex=[NSMutableString string];
 NSCharacterSet *space=NSCharacterSet.whitespaceAndNewlineCharacterSet;
 for(NSUInteger i=0;i<input.length;i++){
  unichar c=[input characterAtIndex:i];
  if([space characterIsMember:c])continue;
  [hex appendFormat:@"%C",c];
 }
 if([hex hasPrefix:@"0x"]||[hex hasPrefix:@"0X"])
  [hex deleteCharactersInRange:NSMakeRange(0,2)];
 NSString *msg=nil;
 if(!hex.length||hex.length%2||hex.length>512)msg=@"Patch 仅支持 4–256 字节的完整十六进制数据";
 else if(hex.length%8)msg=@"ARM64 Code Patch 长度必须是 4 字节的倍数";
 else {
  NSCharacterSet *invalid=[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet];
  if([hex rangeOfCharacterFromSet:invalid].location!=NSNotFound)msg=@"Patch 包含非法十六进制字符";
 }
 if(msg){
  if(error)*error=[NSError errorWithDomain:@"ZonoePatch.V3.PatchCodec" code:1
   userInfo:@{NSLocalizedDescriptionKey:msg}];
  return nil;
 }
 NSMutableData *bytes=[NSMutableData dataWithLength:hex.length/2];
 uint8_t *out=(uint8_t *)bytes.mutableBytes;
 for(NSUInteger i=0;i<hex.length;i+=2){
  unichar a=[hex characterAtIndex:i],b=[hex characterAtIndex:i+1];
  unsigned hi=a<='9'?(unsigned)(a-'0'):(unsigned)((a|32)-'a'+10);
  unsigned lo=b<='9'?(unsigned)(b-'0'):(unsigned)((b|32)-'a'+10);
  out[i/2]=(uint8_t)((hi<<4)|lo);
 }
 return bytes;
}
+ (BOOL)isValidCodeText:(NSString *)text {
 return [self codeBytesFromText:text error:nil]!=nil;
}
@end
