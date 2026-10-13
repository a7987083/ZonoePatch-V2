"""Exact private production builders; substitutes only module path and validated-byte inputs.
No copied/rewritten builder algorithm; records SHA-256 for every extracted span.
"""
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[1];src=root/'iosruntimepatchmenu/src';parts=[];records=[]
def span(file,start,end):
 s=(src/file).read_text();a=s.index(start);b=s.index(end,a);code=s[a:b];parts.append(code);records.append(dict(file=file,start=start,end=end,sha256=hashlib.sha256(code.encode()).hexdigest()))
def function(file,name):
 s=(src/file).read_text();pos=s.index(name+'(');a=s.rfind('\n',0,pos)+1;b=s.index('{',pos);depth=1;e=b+1
 while depth:
  if s[e]=='{':depth+=1
  elif s[e]=='}':depth-=1
  e+=1
 code=s[a:e];parts.append(code);records.append(dict(file=file,symbol=name,sha256=hashlib.sha256(code.encode()).hexdigest()))
headers=(src/'ZNStaticBinaryBuilderV3.mm').read_text().split('// Static Binary Builder V3')[0]
headers+='\n#include "ZNBuildFault.h"\n#import "ZNBuildFileTransaction.h"\n#import "ZNRuntimeActionModel.h"\n#import "ZNNativeHookAction.h"\n#import "ZNIL2CPPMethodSignature.h"\n#import "ZNComplexStructCodec.h"\n#import "ZNRuntimeActionFormat.h"\n#import "ZNGeneratedDataLayout.h"\n#import "ZNAdhocMachOSigner.h"\n#include <cassert>\n'
mock='''
// Input adapters, not replacement builders or runtime validation.
static NSDictionary *fixtureModule;
@interface FixtureModuleManager:NSObject
+ (instancetype)sharedManager;
- (NSDictionary *)moduleNamed:(NSString *)name;
@end
@implementation FixtureModuleManager
+ (instancetype)sharedManager {static FixtureModuleManager *m;if(!m)m=[self new];return m;}
- (NSDictionary *)moduleNamed:(NSString *)name {(void)name;return fixtureModule;}
@end
#define ZNModuleManager FixtureModuleManager
@interface FixtureValidatedBytes:NSObject
@property(nonatomic,strong) NSData *patchBytes;
@property(nonatomic,strong) NSData *capturedOriginalBytes;
@property(nonatomic,assign) uint64_t rva;
@end
@implementation FixtureValidatedBytes
@end
'''
span('ZNStaticBinaryBuilderV3.mm','static const uint64_t kZNV3Page','BOOL ZNStaticBinaryBuilderV3BuildWorkspace')
span('ZNRuntimeOnlyBinaryBuilder.mm','static const uint64_t kZNRBPage','BOOL ZNRuntimeOnlyBinaryBuilderBuildWorkspace')
span('ZNRuntimeActionBuilder.mm','static BOOL ZNRABAppendString','static BOOL ZNRABUpdateBuildReport')
function('ZNRuntimeActionBuilder.mm','ZNRABEmbedTableAtPrivatePath')
function('ZNRuntimeActionBuilder.mm','ZNRABEmbedTableAtPath')
for file,name in [('ZNRuntimeActionModel.mm','ZNRuntimeMethodAction'),('ZNNativeHookAction.mm','ZNNativeHookAction')]:
 s=(src/file).read_text();a=s.index('@implementation '+name);b=s.index('@end',a)+4;code=s[a:b];parts.append(code);records.append(dict(file=file,implementation=name,sha256=hashlib.sha256(code.encode()).hexdigest()))
span('ZNComplexStructCodec.mm','NSString * const ZNComplexStructCodecSecureLongWholeAccessor','typedef int64_t')
for name in ['ZNM46Trim','ZNM46ClassPath','ZNIL2CPPEncodeParameterTypeNames','ZNIL2CPPFullMethodIdentity']:function('ZNIL2CPPMethodSignature.mm',name)

parts.append("""
// Only the Store snapshot/descriptor sink is a fixture adapter; native file
// instrumentation, gap policy, ARM64 encoding and signing remain production.
static NSArray<ZNNativeHookAction *> *fixtureHooks;
@interface FixtureHookStore:NSObject
+ (instancetype)sharedStore;
- (NSArray *)actionsSnapshot;
- (void)restoreStaticPrepatchDescriptorsFromActions:(NSArray *)actions;
- (BOOL)updateStaticPrepatchDescriptor:(NSDictionary *)d atIndex:(NSUInteger)i error:(NSString **)error;
@end
@implementation FixtureHookStore
+ (instancetype)sharedStore {static FixtureHookStore *s;if(!s)s=[self new];return s;}
- (NSArray *)actionsSnapshot {NSMutableArray *a=[NSMutableArray array];for(ZNNativeHookAction *h in fixtureHooks)[a addObject:[h copy]];return a;}
- (void)restoreStaticPrepatchDescriptorsFromActions:(NSArray *)actions {for(NSUInteger i=0;i<actions.count;i++){ZNNativeHookAction *old=actions[i],*h=fixtureHooks[i];h.staticPrepatch=old.staticPrepatch;h.staticHookSlotRVA=old.staticHookSlotRVA;h.staticTrampolineRVA=old.staticTrampolineRVA;h.staticCodeCaveRVA=old.staticCodeCaveRVA;h.staticDisplacedInstruction=old.staticDisplacedInstruction;}}
- (BOOL)updateStaticPrepatchDescriptor:(NSDictionary *)d atIndex:(NSUInteger)i error:(NSString **)error {if(ZNBuildFail("descriptor.write")){if(error)*error=@"Injected sink failure";return NO;}ZNNativeHookAction *h=fixtureHooks[i];h.staticPrepatch=YES;h.staticHookSlotRVA=[d[@"hookSlotRVA"] unsignedLongLongValue];h.staticTrampolineRVA=[d[@"trampolineRVA"] unsignedLongLongValue];h.staticCodeCaveRVA=[d[@"codeCaveRVA"] unsignedLongLongValue];h.staticDisplacedInstruction=[d[@"displacedInstruction"] unsignedIntValue];return YES;}
@end
#define ZNNativeHookStore FixtureHookStore
#import <uuid/uuid.h>
""")
parts.append("""
static NSArray<ZNRuntimeMethodAction *> *fixtureSignatureActions;
@interface FixtureRuntimeStore:NSObject
+ (instancetype)sharedStore;
- (NSArray *)actionsSnapshot;
@end
@implementation FixtureRuntimeStore
+ (instancetype)sharedStore {static FixtureRuntimeStore *s;if(!s)s=[self new];return s;}
- (NSArray *)actionsSnapshot {return fixtureSignatureActions?:@[];}
@end
#define ZNRuntimeActionStore FixtureRuntimeStore
""")
span('ZNRuntimeActionSignaturePostprocess.mm','static BOOL ZNM46ZeroRange','BOOL ZNRuntimeActionAugmentGeneratedOutputsM46')
function('ZNRuntimeActionSignaturePostprocess.mm','ZNRuntimeActionAugmentGeneratedOutputsM46')
s=(src/'ZNNativeHookStaticPrepatch.mm').read_text();a=s.index('typedef struct {');code=s[a:];parts.append(code);records.append(dict(file='ZNNativeHookStaticPrepatch.mm',span='all helpers and complete ZNBuildInstallStaticPreparedNativeHooksV1',sha256=hashlib.sha256(code.encode()).hexdigest()))
out=Path(sys.argv[1]);out.write_text(headers+mock+'\n'.join(parts)+'\n'+(root/'iosruntimepatchmenu/tests/builder_combinations_main.inc').read_text());out.with_suffix('.json').write_text(json.dumps(records,indent=2)+'\n')
