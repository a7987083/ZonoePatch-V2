"""Lexical cross-section dependency evidence; never label it a complete runtime call graph."""
from pathlib import Path
import json,re,collections,argparse
root=Path(__file__).resolve().parents[1];src=root/'iosruntimepatchmenu/src'
p=argparse.ArgumentParser();p.add_argument('--output',default='docs/UI_DEPENDENCIES.json');args=p.parse_args()
files={str(f.relative_to(src)):f.read_text() for f in sorted(p for p in (src/'ui').rglob('*') if p.suffix in {'.inc','.mm'})}
tokens={name:set(re.findall(r'\b[A-Za-z_]\w*\b',text)) for name,text in files.items()}
symbols={}
for name,text in files.items():
 patterns=[r'^#define\s+(\w+)',r'^static\s+[^;{}=\n]*?\b(\w+)\s*(?:\(|=|\{)']
 for pattern in patterns:
  for m in re.finditer(pattern,text,re.M):
   token=m[1];consumers=sorted(n for n,t in tokens.items() if n!=name and token in t)
   if consumers:symbols[token]=dict(owner=name,line=text[:m.start()].count('\n')+1,consumers=consumers)
modules=[]
for name,text in sorted(files.items()):
 modules.append(dict(path=name,implementations=re.findall(r'@implementation\s+([^\n]+)',text),exchanges=len(re.findall(r'\bmethod_exchangeImplementations\s*\(',text)),sets=len(re.findall(r'\bmethod_setImplementation\s*\(',text)),dynamicLookupLines=[i for i,line in enumerate(text.splitlines(),1) if re.search(r'NSClassFromString|NSSelectorFromString|performSelector|objc_msgSend|dlsym',line)]))
report=dict(schema='zonoe.ui-lexical-dependencies/v1',scope='static/macro token references across UI sections; relocated private symbols live in explicit owner interfaces; macro lifetimes require #undef analysis',resolvedBaseline='docs/UI_DEPENDENCIES_BASELINE.json',macroFalseEdges=['ZonoePatchStart','ZonoePatchShow'],symbols=symbols,modules=modules)
(root/args.output).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(f'{len(modules)} sections, {len(symbols)} cross-section file-private/macro symbols recorded')
for n,e in sorted(symbols.items(),key=lambda x:-len(x[1]['consumers']))[:10]:print(n,e['owner'],len(e['consumers']))
