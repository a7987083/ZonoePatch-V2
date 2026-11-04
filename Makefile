ARCHS = arm64
TARGET = iphone:clang:18.5:14.0
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = ZonoePatchV3 ZonoePatchCustomer
ZonoePatchV3_FILES = Tweak.mm V3MenuHost.mm V3Menu.mm V3HookPage.mm V3FeatureEditor.mm V3FeatureModels.mm V3ConfigRepository.mm V3ModuleResolver.mm V3AddressResolver.mm V3PatchValidator.mm V3PatchCodec.mm ZNValueCodec.cpp ZNTypedDescriptor.cpp ZNMixedDescriptor.cpp ZNArm64NumericInstruction.cpp ZNArm64ValueCellPlan.cpp ZNArm64CodeSitePlan.cpp ZNUnifiedBuildPlan.cpp V3UnifiedBuildPlanner.mm ZNTypedValueTransaction.cpp ZNTypedMachOBuilder.mm V3RuntimePatchExecutor.mm V3RuntimeBytesBackend.mm V3PatchSession.mm V3StaticBuildPlan.mm V3StaticBuildPlanner.mm V3StaticBinaryBuilder.mm V3StaticBinaryExport.mm V3StaticSlotTransaction.mm V3StaticDispatchRuntime.mm ZNAdhocMachOSigner.mm
ZonoePatchV3_CFLAGS = -fobjc-arc -fblocks -std=c++17
ZonoePatchV3_FRAMEWORKS = UIKit QuartzCore Foundation
# Customer build ships only UI, installed Static Dispatch catalog and RW slot transaction.
# No static generator, Runtime Bytes backend, JSON persistence or developer controls.
ZonoePatchCustomer_FILES = Tweak.mm V3CustomerHost.mm V3CustomerMenuController.mm V3CustomerRuntime.mm V3StaticSlotTransaction.mm ZNValueCodec.cpp ZNTypedDescriptor.cpp ZNTypedValueTransaction.cpp ZNLiveTypedValueBackend.mm ZNTypedCustomerRuntime.mm ZNMixedDescriptor.cpp ZNMixedValueCoordinator.cpp ZNMixedCustomerRuntime.mm
ZonoePatchCustomer_CFLAGS = -fobjc-arc -fblocks -std=c++17
ZonoePatchCustomer_FRAMEWORKS = UIKit QuartzCore Foundation
include $(THEOS_MAKE_PATH)/tweak.mk
