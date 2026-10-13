#!/bin/bash
set -euo pipefail
: "${THEOS:?THEOS must point to the pinned checkout}"
TASK_SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
xcodebuild -version
xcrun clang --version
make -C iosruntimepatchmenu clean
make -C iosruntimepatchmenu FINALPACKAGE=1 TARGET="iphone:clang:${TASK_SDK_VERSION}:14.0" 2>&1 | tee build-ios.log
mkdir -p dist
cp iosruntimepatchmenu/.theos/obj/ZonoePatchV03.dylib dist/ZonoePatch-V2-arm64.dylib
file dist/ZonoePatch-V2-arm64.dylib | tee dist/file.txt
otool -L dist/ZonoePatch-V2-arm64.dylib | tee dist/load-commands.txt
shasum -a 256 dist/ZonoePatch-V2-arm64.dylib > dist/SHA256.txt
python3 - <<'PY'
from pathlib import Path
import struct
p=Path('dist/ZonoePatch-V2-arm64.dylib'); data=p.read_bytes()
magic,cpu,sub,filetype=struct.unpack_from('<IIII',data)
assert magic==0xfeedfacf and cpu==0x100000c and filetype==6,(magic,cpu,filetype)
assert 'dobby' not in Path('dist/load-commands.txt').read_text().lower()
print('Mach-O arm64 dylib + static Dobby linkage verified; device execution NOT verified')
PY
