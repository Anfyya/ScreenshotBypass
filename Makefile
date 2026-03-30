# 强制使用 Rootless 架构编译
export THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:16.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ScreenshotBypass
ScreenshotBypass_FILES = Tweak.x
ScreenshotBypass_CFLAGS = -fobjc-arc

# 引入设置面板子项目
SUBPROJECTS += Prefs

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk