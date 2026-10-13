"""Execute exact production Executor/public target builders/provider dispatch/filesystem.
Session, workspace, manifest models and provider backends are explicit host doubles;
production BuildSession isolation and built-in binary stages have separate tests.
"""
from pathlib import Path
import sys,runpy,tempfile,json,hashlib
root=Path(__file__).resolve().parents[1];src=root/'iosruntimepatchmenu/src';out=Path(sys.argv[1]);original_argv=sys.argv[:]
with tempfile.TemporaryDirectory() as d:
 sys.argv=['extract-builder-combinations.py',str(Path(d)/'base.mm')];runpy.run_path(str(root/'scripts/extract-builder-combinations.py'));base=(Path(d)/'base.mm').read_text().split('int main(')[0]
sys.argv=original_argv
# Keep exact production algorithms, replacing only module-path lookup and opaque
# authoring models. Public target generation and complete outer Executor run.
base=base.replace('static NSDictionary *fixtureModule;','static NSDictionary *fixtureModule;static NSDictionary *fixtureModules;').replace('(void)name;return fixtureModule;','return fixtureModules[name]?:fixtureModule;')
prefix=(root/'iosruntimepatchmenu/tests/executor_transaction_models.inc').read_text();records=[];parts=[]
def function(file,name):
 s=(src/file).read_text();pos=s.index(name+'(');a=s.rfind('\n',0,pos)+1;b=s.index('{',pos);depth=1;e=b+1
 while depth:
  if s[e]=='{':depth+=1
  elif s[e]=='}':depth-=1
  e+=1
 code=s[a:e];parts.append(code);records.append(dict(file=file,symbol=name,sha256=hashlib.sha256(code.encode()).hexdigest()))
# OutputIO is compiled in this TU so it sees the fixture session binding. The
# transaction implementation itself is linked unchanged as a separate owner.
s=(src/'ZNBuildOutputIO.mm').read_text();parts.append(s[s.index('NSString *ZNCreateBuildOutputDirectory'):]);records.append(dict(file='ZNBuildOutputIO.mm',sha256=hashlib.sha256(parts[-1].encode()).hexdigest()))
function('ZNStaticBinaryBuilderV3.mm','ZNStaticBinaryBuilderV3BuildWorkspace')
function('ZNRuntimeOnlyBinaryBuilder.mm','ZNRuntimeOnlyBinaryBuilderBuildWorkspace')
for name in ['ZNPrepareBuildManifestProviders','ZNEmitBuildManifestProviders']:function('ZNBuildManifest.mm',name)
parts.append((root/'iosruntimepatchmenu/tests/executor_transaction_adapters.inc').read_text())
s=(src/'ZNBuildExecutor.mm').read_text();parts.append(s[s.index('static NSArray<NSNumber *> *ZNM684StaticRowIndexes'):]);records.append(dict(file='ZNBuildExecutor.mm',span='entire production control flow including captured session and final publication',sha256=hashlib.sha256(parts[-1].encode()).hexdigest()))
out.write_text(base+'\n'+prefix+'\n'+'\n'.join(parts)+'\n'+(root/'iosruntimepatchmenu/tests/executor_transaction_main.inc').read_text());out.with_suffix('.json').write_text(json.dumps(records,indent=2)+'\n')
