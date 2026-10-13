from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
source=root/'iosruntimepatchmenu/src'
from ui_source import expanded_ui
ui=expanded_ui()
make=(root/'iosruntimepatchmenu/Makefile').read_text()
assert 'src/legacy/ZNLegacyStaticBinaryPipeline.mm' in make
assert 'ZNBuildExecutorBuildWorkspace' in ui
assert '[ZNStaticBinaryBuilder buildWorkspace:ws' not in ui
assert 'ZNLegacyM585PrepareStaticBuild' in ui and 'ZNLegacyM591PrepareStaticBuild' in ui
# These files cannot be called dead just because they are outside today's source list.
paths=['ZNStaticBinaryBuilder.mm','ZNStaticBinarySigningBridge.mm','ZNAnyImageAddressResolver.mm','legacy/ZNLegacyStaticBinaryPipeline.mm']
records=[]
for rel in paths:
 p=source/rel;assert p.is_file()
 records.append({'path':str(p.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'status':'retained; dynamic/external references not proven absent'})
(root/'compatibility-audit.json').write_text(json.dumps(records,indent=2)+'\n')
print('compatibility code retained; active builder routed via executor PASS')
