from pathlib import Path
import sys,json,hashlib,re
root=Path(__file__).resolve().parents[1];src=root/'iosruntimepatchmenu/src';out=Path(sys.argv[1]);parts=[];records=[]
for file,name in [('ZNRuntimeActionBuilder.mm','ZNRABUpdateBuildReport')]:
 s=(src/file).read_text();match=re.search(r'^(?:static )?(?:NSString \*|BOOL )'+name+r'\s*\(',s,re.M);assert match,name;pos=match.start();a=pos;b=s.index('{',pos);depth=1;e=b+1
 while depth:
  if s[e]=='{':depth+=1
  elif s[e]=='}':depth-=1
  e+=1
 code=s[a:e];parts.append(code);records.append(dict(file=file,symbol=name,sha256=hashlib.sha256(code.encode()).hexdigest()))
headers='''#import <Foundation/Foundation.h>
#import "ZNRuntimeActionModel.h"
#import "ZNNativeHookAction.h"
#import "ZNRuntimeActionFormat.h"
#import "ZNBuildOutputIO.h"
#include "ZNBuildFault.h"
#include <cassert>
'''
test='''int main(){@autoreleasepool{
 NSFileManager *fm=NSFileManager.defaultManager;NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];assert([fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil]);NSString *path=[root stringByAppendingPathComponent:@"build_report.json"];NSData *original=[@"{\\"fixture\\":true}" dataUsingEncoding:NSUTF8StringEncoding];assert([original writeToFile:path atomically:YES]);NSString *error=nil;
 znfault::fail=[](const char *point){return strcmp(point,"file.write")==0;};assert(!ZNRABUpdateBuildReport(@[path],@[],@[],64,&error));znfault::fail={};assert(error.length&&[original isEqual:[NSData dataWithContentsOfFile:path]]);
 assert(ZNRABUpdateBuildReport(@[path],@[],@[],64,&error));NSDictionary *object=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:nil];assert([object[@"fixture"] boolValue]&&object[@"runtimeMethodCall"]&&object[@"nativeHook"]);
 NSData *malformed=[@"malformed" dataUsingEncoding:NSUTF8StringEncoding];assert([malformed writeToFile:path atomically:YES]);assert(!ZNRABUpdateBuildReport(@[path],@[],@[],64,&error));assert([malformed isEqual:[NSData dataWithContentsOfFile:path]]);assert(ZNRABUpdateBuildReport(@[],@[],@[],64,&error));
 [fm removeItemAtPath:root error:nil];puts("actual Runtime report update propagates sink failure, rejects malformed input, preserves prior bytes, retains report-less compatibility PASS");
}}
'''
out.write_text(headers+'\n'.join(parts)+'\n'+test);out.with_suffix('.json').write_text(json.dumps(records,indent=2)+'\n')
