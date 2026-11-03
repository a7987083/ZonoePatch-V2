#import <Foundation/Foundation.h>
#import "../V3PatchCodec.h"

static int fails=0;
static void expect(BOOL passed,const char *what){
 if(!passed){fprintf(stderr,"FAIL: %s\n",what);fails++;}
}
static NSString *repeat(NSString *pair,NSUInteger count){
 NSMutableString *s=[NSMutableString string];for(NSUInteger i=0;i<count;i++)[s appendString:pair];return s;
}
int main(){
 @autoreleasepool{
  NSError *error=nil;
  NSData *a=[ZNV3PatchCodec codeBytesFromText:@"0xE9FF9F52" error:&error];
  NSData *b=[ZNV3PatchCodec codeBytesFromText:@"E9FF9F52" error:&error];
  NSData *c=[ZNV3PatchCodec codeBytesFromText:@"E9 FF 9F 52" error:&error];
  NSData *d=[ZNV3PatchCodec codeBytesFromText:@"0X e9 ff 9f 52" error:&error];
  const uint8_t expected[]={0xE9,0xFF,0x9F,0x52};
  expect(a.length==4&&!memcmp(a.bytes,expected,4),"0x HEX bytes are not reversed");
  expect([a isEqualToData:b]&&[b isEqualToData:c]&&[c isEqualToData:d],"format variants");
  expect(![ZNV3PatchCodec isValidCodeText:@""],"empty");
  expect(![ZNV3PatchCodec isValidCodeText:@"0x"],"prefix only");
  expect(![ZNV3PatchCodec isValidCodeText:@"ABC"],"odd length");
  expect(![ZNV3PatchCodec isValidCodeText:@"GGFF9F52"],"invalid characters");
  expect(![ZNV3PatchCodec isValidCodeText:@"0xFF"],"one byte unaligned");
  expect(![ZNV3PatchCodec isValidCodeText:@"0xE9FF9F52ZZ"],"trailing garbage");
  expect([ZNV3PatchCodec isValidCodeText:repeat(@"00",256)],"256-byte limit inclusive");
  expect(![ZNV3PatchCodec isValidCodeText:repeat(@"00",260)],"over 256-byte limit");
  expect(![ZNV3PatchCodec isValidCodeText:repeat(@"00",255)],"unaligned 255-byte patch");
 }
 printf("V3 Patch Codec: %s (%d failures)\n",fails?"FAIL":"PASS",fails);
 return fails?1:0;
}
