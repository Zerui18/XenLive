TARGET := iphone:clang:latest:12.0
INSTALL_TARGET_PROCESSES = SpringBoard
SYSROOT = /Users/zeruichen/theos/sdks/iPhoneOS13.0.sdk

THEOS_DEVICE_IP = 192.168.0.112
THEOS_DEVICE_PORT = 22

TWEAK_NAME = XenLive
PACKAGE_VERSION = 1.1.0-beta1

include $(THEOS)/makefiles/common.mk

XenLive_FILES = Tweak.xm
XenLive_CFLAGS = -fobjc-arc -Wno-error

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += xenlived
include $(THEOS_MAKE_PATH)/aggregate.mk
