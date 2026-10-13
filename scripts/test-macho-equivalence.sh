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
cmp "$work/baseline/fixture.dylib" "$work/current/fixture.dylib"
echo 'production signer baseline/current complete-byte equivalence PASS'

clang++ -std=c++17 -fobjc-arc -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNStaticRVAProtection.mm iosruntimepatchmenu/tests/macho_writer_rejection_test.mm -o "$work/writer-test"
"$work/writer-test"
# Compatibility builder is retained and gets source compilation coverage even
# though the production Makefile routes only to V3/runtime-only.
clang++ -std=c++17 -fobjc-arc -fblocks -fsyntax-only -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNStaticBinaryBuilder.mm
