#!/bin/bash
set -euo pipefail
sdk=$(xcrun --sdk iphoneos --show-sdk-path)
for source in ui/features/ZNM562SliderIsolation.mm ui/compat/ZNM47VersionUI.mm ZNFirstDisplayTick.mm ZNMenuUIHelpers.mm ui/shell/ZNPublicCompactUI.mm ui/shell/ZNRuntimeMenuModalShell.mm ui/features/ZNFeatureBuilderControlsV2.mm; do
 xcrun --sdk iphoneos clang++ -target arm64-apple-ios14.0 -isysroot "$sdk" -std=gnu++17 -fobjc-arc -fblocks -Wall -Wextra -Werror -fsyntax-only -Iiosruntimepatchmenu/src "iosruntimepatchmenu/src/$source"
done
