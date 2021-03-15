TARGET := iphone:clang:latest:12.0
ARCHS = arm64
CFLAGS = -Wno-error

include $(THEOS)/makefiles/common.mk

THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 2222

TOOL_NAME = xenlived

xenlived_FILES = main.m
xenlived_CFLAGS = -fobjc-arc -Iinclude -Wno-error -I..
xenlived_OBJ_FILES = ./libmicrohttpd.a
xenlived_CODESIGN_FLAGS = -Sentitlements.plist
xenlived_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk
