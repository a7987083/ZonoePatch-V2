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
clang++ -std=c++17 -fobjc-arc -fblocks -framework Foundation -Iiosruntimepatchmenu/src "$work/combinations.mm" iosruntimepatchmenu/src/ZNBuildFileTransaction.mm iosruntimepatchmenu/src/ZNRuntimeLogger.mm iosruntimepatchmenu/src/ZNBinaryPatchRow.mm iosruntimepatchmenu/src/ZNAdhocMachOSigner.mm -o "$work/combinations-test"
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

clang++ -std=c++17 -fobjc-arc -fblocks -DZN_BUILD_FAULT_TESTING -framework Foundation -Iiosruntimepatchmenu/src "$work/combinations.mm" iosruntimepatchmenu/src/ZNBuildFileTransaction.mm iosruntimepatchmenu/src/ZNRuntimeLogger.mm iosruntimepatchmenu/src/ZNBinaryPatchRow.mm iosruntimepatchmenu/src/ZNAdhocMachOSigner.mm -o "$work/combinations-fault-test"
"$work/combinations-fault-test" "$work/fault-combinations"

python3 scripts/extract-executor-transaction-fixture.py "$work/executor.mm"
clang++ -std=c++17 -fobjc-arc -fblocks -DZN_BUILD_FAULT_TESTING -framework Foundation -Iiosruntimepatchmenu/src "$work/executor.mm" iosruntimepatchmenu/src/ZNBuildOutputTransaction.mm iosruntimepatchmenu/src/ZNBuildFileTransaction.mm iosruntimepatchmenu/src/ZNRuntimeLogger.mm iosruntimepatchmenu/src/ZNBinaryPatchRow.mm iosruntimepatchmenu/src/ZNBuildItem.mm iosruntimepatchmenu/src/ZNAdhocMachOSigner.mm -o "$work/executor-test"
"$work/executor-test" "$work/executor"
cp "$work/executor.json" dist/production-executor-extraction.json
