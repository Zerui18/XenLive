TARGET := iphone:clang:latest:12.0
ARCHS = arm64
CFLAGS = -Wno-error

include $(THEOS)/makefiles/common.mk

THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 2222

TOOL_NAME = xenlived

xenlived_FILES = src/main.m src/tools.c
xenlived_CFLAGS = -fobjc-arc -Wno-error -I.. -I includes
xenlived_CODESIGN_FLAGS = -Sentitlements.plist
xenlived_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk
