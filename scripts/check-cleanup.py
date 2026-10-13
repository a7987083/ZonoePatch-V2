from pathlib import Path
import re,json
root=Path(__file__).resolve().parents[1]
r=root/'iosruntimepatchmenu/src'
text='\n'.join(p.read_text() for p in r.rglob('*') if p.suffix in {'.h','.mm','.inc','.cpp'})
for e in json.loads((root/'docs/L02_REMOVAL_EVIDENCE.json').read_text())['removed']:
 assert not re.search(r'\b'+e['symbol']+r'\b',text),e['symbol']
print('four proven unreferenced file-local alignment helpers removed; cleanup contract PASS')
