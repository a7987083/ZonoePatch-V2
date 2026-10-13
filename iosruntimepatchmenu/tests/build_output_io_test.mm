#import <Foundation/Foundation.h>
#import "ZNBuildOutputIO.h"
#include <cassert>
int main(){@autoreleasepool{
 NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];NSString *error=nil;
 NSString *a=ZNCreateBuildOutputDirectory(root,@"same",&error),*b=ZNCreateBuildOutputDirectory(root,@"same",&error);
 assert(a&&b&&![a isEqualToString:b]);
 NSString *old=[a stringByAppendingPathComponent:@"report.json"];
 assert(ZNWriteBuildReport(@{@"old":@YES},old,&error));NSData *before=[NSData dataWithContentsOfFile:old];
 assert(!ZNWriteBuildReport(@{@"bad":@YES},[root stringByAppendingPathComponent:@"missing/report.json"],&error));
 assert([before isEqualToData:[NSData dataWithContentsOfFile:old]]);
 assert(!ZNDiscardOwnedBuildDirectory(root));assert(ZNDiscardOwnedBuildDirectory(b));
 assert([NSFileManager.defaultManager fileExistsAtPath:old]);assert(ZNDiscardOwnedBuildDirectory(a));
 [NSFileManager.defaultManager removeItemAtPath:root error:nil];puts("unique build directory/write-failure/ownership regression PASS");
}}
