#!/bin/bash
set -euo pipefail
# New ownership modules have no blanket warning suppressions. Historical dynamic
# category code retains existing flags until it has a reviewed migration.
for task_source in ZNBuildSession.mm ZNBuildWorkspaceSnapshot.mm ZNBinaryPatchRow.mm ZNActivationStageRunner.mm ZNBuildOutputIO.mm ZNRuntimeLogger.mm ZNImageGeneration.mm; do
  clang++ -std=gnu++17 -fobjc-arc -fblocks -Wall -Wextra -Werror -fsyntax-only -Iiosruntimepatchmenu/src "iosruntimepatchmenu/src/$task_source"
done
