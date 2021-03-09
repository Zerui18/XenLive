TARGET := iphone:clang:latest:12.0
ARCHS = arm64
CFLAGS = -Wno-error

include $(THEOS)/makefiles/common.mk

TOOL_NAME = xenlived

xenlived_FILES = main.m
xenlived_CFLAGS = -fobjc-arc -I/Users/zeruichen/Downloads/libmicrohttpd-0.9.72/src/include
xenlived_OBJ_FILES = ./libmicrohttpd.a
xenlived_CODESIGN_FLAGS = -Sentitlements.plist
xenlived_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk
