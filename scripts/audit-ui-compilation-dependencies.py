"""Reproducible type/Block/selector/IMP inventory, not a semantic call-graph claim."""
from pathlib import Path
import re,json,hashlib
root=Path(__file__).resolve().parents[1];src=root/'iosruntimepatchmenu/src';files={str(p.relative_to(src)):p.read_text() for p in sorted((src/'ui').rglob('*')) if p.suffix in {'.inc','.mm'}}
owners={}
for name,text in files.items():
 for pattern in [r'@interface\s+(\w+)\s*(?::|\n)',r'typedef[\s\S]*?\(\s*\^\s*(\w+)\s*\)',r'^typedef\s+[^;\n{}]+\s+(\w+)\s*;',r'^}\s*(\w+)\s*;']:
  for m in re.finditer(pattern,text,re.M):owners.setdefault(m[1],set()).add(name)
modules=[]
for name,text in files.items():
 if not name.endswith('.inc'):continue
 tokens=set(re.findall(r'\b\w+\b',text));edges=[dict(type=t,owners=sorted(paths)) for t,paths in sorted(owners.items()) if t in tokens and name not in paths]
 line=lambda offset:text[:offset].count('\n')+1
 modules.append(dict(path=name,sha256=hashlib.sha256(text.encode()).hexdigest(),lines=len(text.splitlines()),interfaces=re.findall(r'@interface\s+([^\n]+)',text),implementations=re.findall(r'@implementation\s+([^\n]+)',text),namedTypeEdges=edges,blockLines=[i for i,l in enumerate(text.splitlines(),1) if '^' in l],privateSelectorLiterals=sorted(set(re.findall(r'@selector\s*\(([^)]+)\)',text))),selfMessageLines=[i for i,l in enumerate(text.splitlines(),1) if re.search(r'\[self\s+\w+',l)],installationLines=[i for i,l in enumerate(text.splitlines(),1) if re.search(r'method_exchangeImplementations|method_setImplementation|method_getImplementation|dispatch_once|constructor|ZNInstall\w+',l)],initializationOrder='Original ZNUnifiedUI marker and deferred installers preserved; module-specific closure requires source review + strict standalone compile + real IMP fixture'))
report=dict(schema='zonoe.ui-compilation-dependencies/v2',scope='All remaining inc sections: types, named Block edges, selector literals, self-call source lines, IMP and initialization sites. Lexical references include comments/macros; not proof of semantic closure or external consumers.',remaining=len(modules),independent=sum(p.endswith('.mm') for p in files),typeOwners={k:sorted(v) for k,v in sorted(owners.items())},modules=modules)
(root/'docs/UI_COMPILATION_DEPENDENCIES.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(f"{len(modules)} remaining sections: type/Block/Selector/IMP/initialization inventory recorded")
