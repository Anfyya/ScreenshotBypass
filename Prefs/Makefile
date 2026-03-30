TARGET := iphone:clang:latest:16.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ScreenshotBypassPrefs
ScreenshotBypassPrefs_FILES = RootListController.m
ScreenshotBypassPrefs_FRAMEWORKS = UIKit
ScreenshotBypassPrefs_PRIVATE_FRAMEWORKS = Preferences
ScreenshotBypassPrefs_INSTALL_PATH = /Library/PreferenceBundles
ScreenshotBypassPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk