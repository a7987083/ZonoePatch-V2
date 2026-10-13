"""Complete source operation inventory; dynamic IMP targets stay explicitly unresolved."""
from pathlib import Path
import re,json,hashlib,sys
from ui_source import expanded_ui
root=Path(__file__).resolve().parents[1]
text=expanded_ui()
# Mask strings/comments without shifting source offsets; nested Objective-C syntax is retained.
masked=re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|@?"(?:\\.|[^"\\])*"',lambda m:''.join('\n' if c=='\n' else ' ' for c in m[0]),text)
def matching(start,left='{',right='}'):
 depth=1;i=start+1
 while i<len(masked) and depth:
  if masked[i]==left:depth+=1
  elif masked[i]==right:depth-=1
  i+=1
 assert depth==0,'unbalanced source'
 return i
methods=[];operations=[];invocations=[]
for impl in re.finditer(r'@implementation\s+(\w+)(?:\s*\(([^)]*)\))?',masked):
 end=masked.index('@end',impl.end());owner=impl[1].replace('ZNRuntimeMenuControllerV024','ZNRuntimeMenuControllerV040');category=impl[2] or '<primary>'
 for m in re.finditer(r'^([-+])\s*\([^\n]+',masked[impl.end():end],re.M):
  start=impl.end()+m.start();brace=masked.index('{',start)
  if brace>=end:continue
  finish=matching(brace);sig=masked[start:brace];labels=re.findall(r'\b(\w+)\s*:',sig)
  selector=''.join(x+':' for x in labels) if labels else re.search(r'[-+]\s*\([^)]*\)\s*(\w+)',sig)[1]
  calls=[]
  for call in re.finditer(r'\[\s*self\s+(\w+)',masked[brace:finish]):
   offset=brace+call.start();last=matching(offset,'[',']');body=masked[offset:last];depth=0;labels2=[]
   for token in re.finditer(r'\[|\]|\b(\w+)\s*:',body):
    if token[0]=='[':depth+=1
    elif token[0]==']':depth-=1
    elif depth==1:labels2.append(token[1])
   calls.append(''.join(x+':' for x in labels2) if labels2 else call[1])
  methods.append(dict(owner=owner,category=category,kind=m[1],selector=selector,line=text[:start].count('\n')+1,bodySHA256=hashlib.sha256(text[brace:finish].encode()).hexdigest(),selfCalls=sorted(set(calls)),forwardingAlias=selector in calls))
for m in re.finditer(r'\b(method_exchangeImplementations|method_setImplementation)\s*\(',masked):
 start=masked.index('(',m.start());end=matching(start,'(',')')
 operations.append(dict(kind=m[1],line=text[:m.start()].count('\n')+1,expression=text[m.start():end],selectors=re.findall(r'@selector\s*\(([^)]+)\)',text[max(0,m.start()-800):end]),resolution='runtime Method/IMP binding required; see opt-in ZNUITraceSnapshot'))
for m in re.finditer(r'\b(\w+)\s*\([^;{}\n]*@selector\s*\(([^)]+)\)[^;{}\n]*@selector\s*\(([^)]+)\)[^;{}\n]*\)',text):
 invocations.append(dict(helper=m[1],first=m[2],second=m[3],line=text[:m.start()].count('\n')+1))
assert len(operations)==71,'incomplete operation coverage'
report=dict(schema='zonoe.selector-install-source/v1',sourceSHA256=hashlib.sha256(text.encode()).hexdigest(),scope='all UI method definitions, syntactic self-call edges, all 63 exchange/8 set source sites and literal helper calls; not a fabricated full dynamic call graph',methods=methods,operations=operations,literalHelperInvocations=invocations,dynamicGraph='DEVICE PENDING: enable zonoe.diagnostics.ui-install.enabled before activation and export ZNUITraceSnapshot; >4096 events marks incomplete')
(root/'docs/UI_SELECTOR_IMP_GRAPH.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(f'{len(methods)} method definitions / {len(operations)} install sites / {len(invocations)} literal helper invocations recorded')
# A moved category cannot override an existing body implicitly via changed loader order.
independent=['ZNRuntimeMethodCallFinderUI','ZNRuntimeMethodCallFeatureUI','ZNMethodFinderM43Polish','ZNM551RuntimeSliderStability','ZNM57UnifiedRuntimeControls','ZNM57RuntimeOnlyBuilderGate','ZNIL2CPPABIDetailUI','ZNM52MethodSearchHistory','ZNM442SearchRestore','ZNMethodFinderM22StableCancelUX','ZNMethodFinderM21CancelUX','ZNMethodFinderM2UI','ZNFeatureRuntimeControlsV2','ZNFeatureGroupUI','ZNM562SliderIsolation','ZNM47VersionUI','ZNPublicCompactUI','ZNFeatureBuilderControlsV2','ZNRuntimeMenuModalShell']
for category in independent:
 for method in (m for m in methods if m['category']==category):
  collisions=[m for m in methods if (m['owner'],m['kind'],m['selector'])==(method['owner'],method['kind'],method['selector'])]
  assert len(collisions)==1,(category,method['selector'],len(collisions))
print('independent category method bodies have no same-class selector collision PASS')
