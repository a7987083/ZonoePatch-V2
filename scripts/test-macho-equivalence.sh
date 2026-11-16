#!/bin/bash
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
baseline=5e7d1d4c8b487c6c3fd5a3eb5685954ede24870a
git show "$baseline:iosruntimepatchmenu/src/ZNAdhocMachOSigner.mm" > "$work/baseline.mm"
for version in baseline current; do
  source="$work/baseline.mm"
  if [ "$version" = current ]; then source=iosruntimepatchmenu/src/ZNAdhocMachOSigner.mm; fi
  clang++ -std=c++17 -fobjc-arc -framework Foundation -Iiosruntimepatchmenu/src "$source" iosruntimepatchmenu/tests/macho_signer_fixture.mm -o "$work/$version-test"
  "$work/$version-test" "$work/$version"
done
# Signer flags/requirements intentionally differ; compare unaffected executable bytes.
python3 - "$work/baseline/fixture.dylib" "$work/current/fixture.dylib" <<'PY'
import struct,sys
from pathlib import Path
def image(path):
    b=Path(path).read_bytes()
    magic,cpu,_,kind,ncmds,sizeofcmds=struct.unpack_from('<6I',b)
    assert (magic,cpu,kind)==(0xfeedfacf,0x100000c,6)
    pos=32;link=None;sig=None
    for _ in range(ncmds):
        cmd,size=struct.unpack_from('<II',b,pos)
        assert size>=8 and pos+size<=len(b)
        if cmd==0x19 and b[pos+8:pos+24].split(bytes([0]),1)[0]==b'__LINKEDIT':link=pos
        if cmd==0x1d:sig=(pos,*struct.unpack_from('<II',b,pos+8))
        pos+=size
    assert pos==32+sizeofcmds and link is not None and sig is not None
    assert sig[1]>0 and sig[1]+sig[2]<=len(b)
    return b,link,sig
old,ol,os=image(sys.argv[1]);new,nl,ns=image(sys.argv[2])
assert (ol,os[0],os[1])==(nl,ns[0],ns[1])
left=bytearray(old[:os[1]]);right=bytearray(new[:ns[1]])
for p,n in ((ol+32,8),(ol+48,8),(os[0]+12,4)):
    left[p:p+n]=right[p:p+n]=bytes(n)
assert left==right,'unexpected mutation outside signature and LINKEDIT size metadata'
blob=new[ns[1]:ns[1]+ns[2]]
magic,total,count=struct.unpack_from('>3I',blob)
assert magic==0xfade0cc0 and 12+8*count<=total<=len(blob)
dirs=set();req=0
for i in range(count):
    slot,off=struct.unpack_from('>II',blob,12+i*8)
    assert off+12<=total
    m,length=struct.unpack_from('>II',blob,off)
    assert 12<=length<=total-off
    if slot in (0,0x1000):
        assert m==0xfade0c02 and length>=88
        assert struct.unpack_from('>I',blob,off+12)[0]==2,'CS_ADHOC missing'
        dirs.add(slot)
    elif slot==2:
        assert m==0xfade0c01 and length==12
        assert struct.unpack_from('>I',blob,off+8)[0]==0
        req+=1
assert dirs=={0,0x1000} and req==1
print('signer code bytes unchanged; CS_ADHOC and empty requirements verified')
PY

clang++ -std=c++17 -fobjc-arc -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNStaticRVAProtection.mm iosruntimepatchmenu/tests/macho_writer_rejection_test.mm iosruntimepatchmenu/src/ZNImageGeneration.mm -o "$work/writer-test"
"$work/writer-test"
# Compatibility builder is retained and gets source compilation coverage even
# though the production Makefile routes only to V3/runtime-only.
clang++ -std=c++17 -fobjc-arc -fblocks -fsyntax-only -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNStaticBinaryBuilder.mm
git show "$baseline:iosruntimepatchmenu/src/ZNStaticBinaryBuilderV3.mm" > "$work/v3-baseline.mm"
for version in baseline current; do
  source="$work/v3-baseline.mm"
  if [ "$version" = current ]; then source=iosruntimepatchmenu/src/ZNStaticBinaryBuilderV3.mm; fi
  python3 scripts/extract-macho-layout-fixture.py "$source" "$work/layout-$version.mm"
  clang++ -std=c++17 -fobjc-arc -framework Foundation -Iiosruntimepatchmenu/src "$work/layout-$version.mm" -o "$work/layout-$version-test"
  "$work/layout-$version-test" "$work/layout-$version.bin"
done
cmp "$work/layout-baseline.bin" "$work/layout-current.bin"
echo 'extracted production V3 owned-segment install baseline/current complete-byte equivalence PASS'
git show "$baseline:iosruntimepatchmenu/src/ZNRuntimeOnlyBinaryBuilder.mm" > "$work/runtime-baseline.mm"
for version in baseline current; do
  source="$work/runtime-baseline.mm"
  if [ "$version" = current ]; then source=iosruntimepatchmenu/src/ZNRuntimeOnlyBinaryBuilder.mm; fi
  python3 scripts/extract-runtime-only-fixture.py "$source" "$work/runtime-$version-fixture.mm"
  clang++ -std=c++17 -fobjc-arc -Wno-incomplete-implementation -framework Foundation -Iiosruntimepatchmenu/src "$work/runtime-$version-fixture.mm" -o "$work/runtime-$version-test"
  "$work/runtime-$version-test" "$work/runtime-$version"
done
cmp "$work/runtime-baseline/output/fixture.dylib" "$work/runtime-current/output/fixture.dylib"
echo 'extracted production runtime-only target generation baseline/current complete-byte equivalence PASS'

python3 scripts/extract-builder-combinations.py "$work/combinations.mm"
clang++ -std=c++17 -fobjc-arc -fblocks -framework Foundation -Iiosruntimepatchmenu/src "$work/combinations.mm" iosruntimepatchmenu/src/ZNBuildFileTransaction.mm iosruntimepatchmenu/src/ZNRuntimeLogger.mm iosruntimepatchmenu/src/ZNBinaryPatchRow.mm iosruntimepatchmenu/src/ZNAdhocMachOSigner.mm iosruntimepatchmenu/src/ZNImageGeneration.mm -o "$work/combinations-test"
"$work/combinations-test" "$work/combinations"
mkdir -p dist
cp "$work/combinations.json" dist/production-builder-extraction.json

# Independent final-byte CodeDirectory verification applies the same strict iOS
# ARM64/SDK/signature policy as the deliverable, not just signer idempotence.
verified_count=0
for generated in "$work"/combinations/mode-0/*.znpatched "$work"/combinations/mode-1/UnityFramework "$work"/combinations/mode-2/UnityFramework "$work"/combinations/mode-3/UnityFramework.znpatched "$work"/combinations/capacity/*.dylib; do
  report="dist/generated-$(basename "$(dirname "$generated")")-signature.json"
  test -f "$generated"
  python3 scripts/verify-artifact.py "$generated" > "$report"
  verified_count=$((verified_count+1))
done
test "$verified_count" = 5
echo 'production combination outputs independent iOS ARM64 CodeDirectory page hashes PASS'

clang++ -std=c++17 -fobjc-arc -fblocks -DZN_BUILD_FAULT_TESTING -framework Foundation -Iiosruntimepatchmenu/src "$work/combinations.mm" iosruntimepatchmenu/src/ZNBuildFileTransaction.mm iosruntimepatchmenu/src/ZNRuntimeLogger.mm iosruntimepatchmenu/src/ZNBinaryPatchRow.mm iosruntimepatchmenu/src/ZNAdhocMachOSigner.mm iosruntimepatchmenu/src/ZNImageGeneration.mm -o "$work/combinations-fault-test"
"$work/combinations-fault-test" "$work/fault-combinations"

python3 scripts/extract-executor-transaction-fixture.py "$work/executor.mm"
clang++ -std=c++17 -fobjc-arc -fblocks -DZN_BUILD_FAULT_TESTING -framework Foundation -Iiosruntimepatchmenu/src "$work/executor.mm" iosruntimepatchmenu/src/ZNBuildOutputTransaction.mm iosruntimepatchmenu/src/ZNBuildFileTransaction.mm iosruntimepatchmenu/src/ZNRuntimeLogger.mm iosruntimepatchmenu/src/ZNBinaryPatchRow.mm iosruntimepatchmenu/src/ZNBuildItem.mm iosruntimepatchmenu/src/ZNAdhocMachOSigner.mm iosruntimepatchmenu/src/ZNImageGeneration.mm -o "$work/executor-test"
"$work/executor-test" "$work/executor"
cp "$work/executor.json" dist/production-executor-extraction.json
