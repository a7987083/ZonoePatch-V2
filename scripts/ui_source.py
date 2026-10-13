"""UI source inventory and exact, ordered expansion; standard imports stay opaque."""
from pathlib import Path
import re,json,hashlib
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'iosruntimepatchmenu/src'
INCLUDE=re.compile(r'^#include "(ui/[^"\n]+\.inc)"\n$',re.M)
def expanded_ui(root=ROOT):
    source=root/'iosruntimepatchmenu/src'
    text=(source/'ZNUnifiedUI.mm').read_text()
    def replace(m):
        path=(source/m[1]).resolve()
        if not path.is_relative_to(source.resolve()):raise ValueError('include traversal')
        return path.read_text()
    return INCLUDE.sub(replace,text)
def verify():
    manifest=json.loads((ROOT/'iosruntimepatchmenu/tests/ui_module_manifest.json').read_text())
    text=(SRC/'ZNUnifiedUI.mm').read_text()
    paths=INCLUDE.findall(text)
    expected=[m['path'] for m in manifest['modules']]
    assert paths==expected and len(paths)==len(set(paths)),'UI owner/order changed'
    assert set(paths)=={str(p.relative_to(SRC)) for p in (SRC/'ui').rglob('*.inc')},'unowned UI module'
    for m in manifest['modules']:
        assert hashlib.sha256((SRC/m['path']).read_bytes()).hexdigest()==m['sha256'],m['path']
    assert hashlib.sha256(expanded_ui().encode()).hexdigest()==manifest['expanded_sha256'],'UI expanded bytes changed'
    print(f'{len(paths)} modules; exact baseline UI expansion/ownership/order PASS')
if __name__=='__main__':verify()
