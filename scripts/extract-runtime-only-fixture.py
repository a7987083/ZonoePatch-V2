"""Exact production runtime-only target builder with a path-provider test double."""
from pathlib import Path
import sys,hashlib,json
s=Path(sys.argv[1]).read_text();out=Path(sys.argv[2]);parts=[];records=[]
a=s.index('static const uint64_t kZNRBPage');b=s.index('static BOOL',a);parts.append(s[a:b])
for name in ['ZNRBShiftU32','ZNRBParse','ZNRBShiftLinkeditReferences','ZNRBBuildTarget']:
 if name+'(' not in s:assert name=='ZNRBShiftU32';continue
 a=s.rfind('static ',0,s.index(name+'('));b=s.index('{',a);depth=1;e=b+1
 while depth:
  if s[e]=='{':depth+=1
  elif s[e]=='}':depth-=1
  e+=1
 code=s[a:e];parts.append(code);records.append(dict(symbol=name,sha256=hashlib.sha256(code.encode()).hexdigest()))
headers='''#import <Foundation/Foundation.h>
#import "ZNPatchCore.h"
#include "ZNMachOFile.h"
#include "ZNGeneratedDataLayout.h"
#import <mach-o/loader.h>
#import <mach/machine.h>
#import <mach/vm_prot.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#include <vector>
#include <cassert>
#include <cerrno>
static NSDictionary *fixtureModule;
@implementation ZNModuleManager
+ (instancetype)sharedManager { static ZNModuleManager *m; if(!m)m=[self new];return m; }
- (NSDictionary *)moduleNamed:(NSString *)name { (void)name;return fixtureModule; }
@end
'''
fixture=(Path(__file__).resolve().parents[1]/'iosruntimepatchmenu/tests/macho_layout_fixture_main.inc').read_text().split(' ZNV3Layout layout=')[0]
fixture=fixture.replace('ZNV3OwnedSegmentCommand','ZNRBOwnedDataCommand')
fixture+=''' NSString *dir=[NSString stringWithUTF8String:argv[1]],*input=[dir stringByAppendingPathComponent:@"input"],*output=[dir stringByAppendingPathComponent:@"output"];
 for(NSString *folder in @[input,output])[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
 NSString *inputPath=[input stringByAppendingPathComponent:@"fixture.dylib"];
 assert([[NSData dataWithBytes:image.data() length:image.size()]writeToFile:inputPath atomically:YES]);fixtureModule=@{@"path":inputPath};
 NSString *result=nil,*error=nil;NSDictionary *metadata=nil;
 assert(ZNRBBuildTarget(@"fixture",output,&result,&metadata,&error));assert(metadata.count&&result.length);
 NSData *binary=[NSData dataWithContentsOfFile:result];znmacho::File verified;assert(znmacho::parse((const uint8_t*)binary.bytes,binary.length,verified));assert(verified.commands.size()==5);
 NSLog(@"extracted production runtime-only target generation fixture PASS");
}}
'''
out.write_text(headers+'\n'.join(parts)+'\n'+fixture);out.with_suffix('.json').write_text(json.dumps(records,indent=2)+'\n')
