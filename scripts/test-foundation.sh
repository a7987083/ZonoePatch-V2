#!/bin/bash
set -euo pipefail
clang++ -std=c++17 -fobjc-arc -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/tests/il2cpp_runtime_common_test.mm -o /tmp/common-test
/tmp/common-test
clang++ -std=c++17 -fobjc-arc -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/tests/native_hook_template_test.mm -o /tmp/hook-test
/tmp/hook-test
clang++ -std=gnu++17 -fobjc-arc -fblocks -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNNativeHookScheduler.mm iosruntimepatchmenu/tests/native_hook_scheduler_test.mm -o /tmp/scheduler-test
/tmp/scheduler-test
clang++ -std=c++17 -fobjc-arc -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNBuildOutputIO.mm iosruntimepatchmenu/tests/build_output_io_test.mm -o /tmp/output-test
/tmp/output-test
clang++ -std=gnu++17 -fobjc-arc -fblocks -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNActivationStageRunner.mm iosruntimepatchmenu/src/ZNUIInstallationTrace.mm iosruntimepatchmenu/tests/activation_stage_runner_test.mm -o /tmp/activation-test
/tmp/activation-test
clang++ -std=gnu++17 -fobjc-arc -fblocks -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNBuildSession.mm iosruntimepatchmenu/src/ZNBuildWorkspaceSnapshot.mm iosruntimepatchmenu/src/ZNBinaryPatchRow.mm iosruntimepatchmenu/src/ZNRuntimeActionModel.mm iosruntimepatchmenu/src/ZNNativeHookAction.mm iosruntimepatchmenu/src/ZNIL2CPPMethodSignature.mm iosruntimepatchmenu/src/ZNIL2CPPABIMetadata.mm iosruntimepatchmenu/src/ZNValueTypeModel.mm iosruntimepatchmenu/src/ZNComplexStructCodec.mm iosruntimepatchmenu/tests/build_session_test.mm -o /tmp/build-session-test
/tmp/build-session-test
clang++ -std=gnu++17 -fobjc-arc -fblocks -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNIL2CPPABIMetadata.mm iosruntimepatchmenu/tests/il2cpp_abi_classifier_test.mm -o /tmp/abi-test
/tmp/abi-test
clang++ -std=c++17 -fobjc-arc -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNBuildRouterShadow.mm iosruntimepatchmenu/tests/build_router_shadow_test.mm -o /tmp/router-test
/tmp/router-test
clang++ -std=c++17 -fobjc-arc -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNFeatureMetadataCodec.mm iosruntimepatchmenu/src/ZNValueTypeModel.mm iosruntimepatchmenu/tests/feature_metadata_policy_stub.mm iosruntimepatchmenu/tests/feature_metadata_codec_test.mm -o /tmp/metadata-test
/tmp/metadata-test
clang++ -std=gnu++17 -fobjc-arc -fblocks -Wall -Wextra -Werror -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNRuntimeLogger.mm iosruntimepatchmenu/tests/runtime_logger_test.mm -o /tmp/logger-test
/tmp/logger-test
if [ "$(uname -m)" = arm64 ]; then
  clang++ -std=c++17 -O0 -Wall -Wextra -Werror iosruntimepatchmenu/tests/arm64_compiler_abi_fixture.cpp -o /tmp/native-arm64-abi
  /tmp/native-arm64-abi
else
  echo 'Native arm64 compiler fixture NOT VERIFIED on this runner'
fi

clang++ -std=c++17 -fobjc-arc -Wall -Wextra -Werror -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNPerformanceReport.mm iosruntimepatchmenu/tests/performance_report_test.mm -o /tmp/performance-report-test
/tmp/performance-report-test
for class_mode in present absent; do
  flag=""
  if [ "$class_mode" = absent ]; then flag=-DTEST_NO_MENU_CLASS; fi
  clang++ -std=c++17 -fobjc-arc -Wall -Wextra -Werror $flag -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNMenuPresentationDefaults.mm iosruntimepatchmenu/tests/menu_presentation_defaults_test.mm -o /tmp/menu-defaults-test
  /tmp/menu-defaults-test
done
work_image=$(mktemp -d)
printf 'int ZNImageFixture(void){return 42;}\n' > "$work_image/image.c"
clang -dynamiclib "$work_image/image.c" -o "$work_image/loaded-image-fixture.dylib"
clang++ -std=c++17 -fobjc-arc -fblocks -Wall -Wextra -Werror -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNImageGeneration.mm iosruntimepatchmenu/tests/loaded_image_apple_test.mm -o "$work_image/image-test"
"$work_image/image-test" "$work_image/loaded-image-fixture.dylib"
rm -rf "$work_image"
clang++ -std=c++17 -fobjc-arc -Wall -Wextra -Werror -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNMenuUIKeys.mm iosruntimepatchmenu/src/ZNMenuSearchPolicy.mm iosruntimepatchmenu/tests/ui_key_consumer_test.mm iosruntimepatchmenu/tests/ui_shared_owner_test.mm -o /tmp/ui-owner-test
/tmp/ui-owner-test

clang++ -std=c++17 -fobjc-arc -Wall -Wextra -Werror -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNUIInstallationTrace.mm iosruntimepatchmenu/tests/ui_install_trace_test.mm -o /tmp/ui-trace-test
/tmp/ui-trace-test

clang++ -std=c++17 -fobjc-arc -Wall -Wextra -Werror -framework Foundation -Iiosruntimepatchmenu/src iosruntimepatchmenu/src/ZNAsyncPerformance.mm iosruntimepatchmenu/tests/async_search_metrics_test.mm -o /tmp/search-metrics-test
/tmp/search-metrics-test
