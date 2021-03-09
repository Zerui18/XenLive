TARGET := iphone:clang:latest:12.0
INSTALL_TARGET_PROCESSES = SpringBoard
SYSROOT = /Users/zeruichen/theos/sdks/iPhoneOS13.0.sdk

ARCHS = arm64e

THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 2222

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = XenLive
PACKAGE_VERSION = 0.0.1

XenLive_FILES = Tweak.xm echo.mm
XenLive_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += xenlived
include $(THEOS_MAKE_PATH)/aggregate.mk