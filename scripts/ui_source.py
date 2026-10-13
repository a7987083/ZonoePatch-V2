"""UI source inventory and exact, ordered expansion; standard imports stay opaque."""
from pathlib import Path
import re,json,hashlib
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'iosruntimepatchmenu/src'
INCLUDE=re.compile(r'^(?:#include "(ui/[^"\n]+\.inc)"|// UI_COMPILED_MODULE: (ui/[^\n]+\.mm))\n',re.M)
def expanded_ui(root=ROOT):
    source=root/'iosruntimepatchmenu/src'
    text=(source/'ZNUnifiedUI.mm').read_text()
    def replace(m):
        path=(source/(m[1] or m[2])).resolve()
        if not path.is_relative_to(source.resolve()):raise ValueError('include traversal')
        return re.sub(r'^.*// UI_MODULE_IMPORT\n','',path.read_text(),flags=re.M)
    text=text.replace('// UI_INCLUDE_DIAGNOSTICS_BEGIN\n#pragma clang diagnostic push\n#pragma clang diagnostic ignored "-Wnullability-completeness"\n','')
    text=text.replace('// UI_INCLUDE_DIAGNOSTICS_END\n#pragma clang diagnostic pop\n','')
    text=re.sub(r'^.*// UI_MODULE_IMPORT\n','',text,flags=re.M)
    text=INCLUDE.sub(replace,text)
    review=root/'iosruntimepatchmenu/tests/ui_reviewed_edits.json'
    if review.exists():
        for edit in json.loads(review.read_text())['edits']:
            assert text.count(edit['after'])==1,'UI reviewed edit changed: '+edit['path']
            text=text.replace(edit['after'],edit['before'])
    def relocated(m):
        path=source/m[1]
        content=path.read_text();start='// UI_RELOCATED_BEGIN '+m[2]+'\n';end='// UI_RELOCATED_END '+m[2]+'\n'
        region=content.split(start,1)[1].split(end,1)[0]
        return region.replace('ZN_UI_LINKAGE ','static ')
    return re.sub(r'^// UI_RELOCATED: (ZNMenu[A-Za-z]+\.(?:mm|h)):(\w+)\n',relocated,text,flags=re.M)
def verify():
    manifest=json.loads((ROOT/'iosruntimepatchmenu/tests/ui_module_manifest.json').read_text())
    text=(SRC/'ZNUnifiedUI.mm').read_text()
    paths=[a or b for a,b in INCLUDE.findall(text)]
    expected=[m['path'] for m in manifest['modules']]
    assert paths==expected and len(paths)==len(set(paths)),'UI owner/order changed'
    assert set(paths)=={str(p.relative_to(SRC)) for p in (SRC/'ui').rglob('*') if p.suffix in {'.inc','.mm'}},'unowned UI module'
    for m in manifest['modules']:
        assert hashlib.sha256((SRC/m['path']).read_bytes()).hexdigest()==m['sha256'],m['path']
    assert hashlib.sha256(expanded_ui().encode()).hexdigest()==manifest['expanded_sha256'],'UI expanded bytes changed'
    for path,digest in manifest.get('external_owner_hashes',{}).items():
        assert hashlib.sha256((SRC/path).read_bytes()).hexdigest()==digest,'external UI owner changed: '+path
    previous=expanded_ui().replace('#include "ZNPerformance.h"\n','').replace(' znperf::Scope znPageMeasure(znperf::PageRefresh);','')
    previous=re.sub(r'^.*// ZN_PERF_ONLY\n','',previous,flags=re.M)
    assert hashlib.sha256(previous.encode()).hexdigest()==manifest.get('pre_performance_expanded_sha256',manifest['expanded_sha256']), 'non-metric UI change'
    print(f'{len(paths)} modules; reviewed expansion/metric-only delta/ownership/order PASS')
if __name__=='__main__':verify()
