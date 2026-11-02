ARCHS = arm64
TARGET = iphone:clang:18.5:14.0
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = ZonoePatchV3
ZonoePatchV3_FILES = Tweak.mm V3MenuHost.mm V3Menu.mm V3HookPage.mm V3FeatureModels.mm
ZonoePatchV3_CFLAGS = -fobjc-arc -fblocks -std=c++17
ZonoePatchV3_FRAMEWORKS = UIKit QuartzCore Foundation
include $(THEOS_MAKE_PATH)/tweak.mk
