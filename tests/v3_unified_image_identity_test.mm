#import <Foundation/Foundation.h>
#import "../V3UnifiedImageIdentity.h"
#include <cstdio>
static int failures=0;
static void check(bool ok,const char *name){
 if(!ok){++failures;std::fprintf(stderr,"FAIL %s\n",name);}
}
int main(){
 @autoreleasepool {
  // Two distinct NSString instances with the same bytes: the regression fixture.
  NSString *uuid1=[[NSString alloc]initWithUTF8String:"A1B2C3D4-0000-1111-2222-123456789ABC"];
  NSString *uuid2=[[NSString alloc]initWithBytes:[uuid1 UTF8String] length:uuid1.length
                                          encoding:NSUTF8StringEncoding];
  NSString *path1=[[NSString alloc]initWithUTF8String:"/private/var/containers/Bundle/Application/TEST/Game.app/Frameworks/UnityFramework.framework/UnityFramework"];
  NSString *path2=[[NSString alloc]initWithBytes:[path1 UTF8String] length:[path1 lengthOfBytesUsingEncoding:NSUTF8StringEncoding]
                                          encoding:NSUTF8StringEncoding];
  check(uuid1!=uuid2&&path1!=path2,"fixtures must have distinct object pointers");
  check(ZNV3SameImageIdentity(uuid1,path1,uuid2,path2),
        "same UUID and path content accepted independent of pointer identity");
  check(!ZNV3SameImageIdentity(uuid1,path1,[uuid2 stringByAppendingString:@"X"],path2),
        "different UUID rejected");
  check(!ZNV3SameImageIdentity(uuid1,path1,uuid2,[path2 stringByAppendingString:@"X"]),
        "different source path rejected");
  check(!ZNV3SameImageIdentity(uuid1,path1,nil,path2),"missing UUID rejected");
  check(!ZNV3SameImageIdentity(uuid1,path1,uuid2,@""),"empty path rejected");
 }
 std::printf("P10.6.4 unified Mach-O identity: %s (%d failures)\n",
             failures?"FAIL":"PASS",failures);
 return failures?1:0;
}
