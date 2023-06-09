FINALPACKAGE := 1
TARGET := iphone:clang:latest:14.2
ARCHS := arm64 arm64e

DEBUG = 0
THEOS_LEAN_AND_MEAN = 1
USING_JINX = 1

THEOS_DEVICE_IP = localhost -p 2222

ROOTLESS := 1

# swift package location

XCDD_TOP = $(HOME)/Library/Developer/Xcode/DerivedData/
XCDD_MID = $(shell basename $(XCDD_TOP)/$(PWD)*)
XCDD_BOT = /SourcePackages/checkouts

MOD_NAME = Zip
MOD_LOC = $(XCDD_TOP)$(XCDD_MID)$(XCDD_BOT)/$(MOD_NAME)/Zip

# Set rootless package scheme
THEOS_PACKAGE_SCHEME =
ifeq ($(ROOTLESS),1)
THEOS_PACKAGE_SCHEME = rootless
endif

# Define included files, imported frameworks, etc.
TOOL_NAME = mldecrypt
$(TOOL_NAME)_FILES = $(shell find Sources/$(TOOL_NAME) -name '*.swift') $(wildcard $(shell find $(MOD_LOC) -name '*.swift')) $(shell find $(THEOS)/include/Minizip -name '*.c') $(shell find $(THEOS)/include/cdaswift -name '*.mm')
$(TOOL_NAME)_FILES += $(wildcard Sources/include/opainject/*.m)
$(TOOL_NAME)_CFLAGS = -w
$(TOOL_NAME)_SWIFTFLAGS = -ISources/include
ifeq ($(ROOTLESS),1)
$(TOOL_NAME)_INSTALL_PATH = /var/jb/usr/bin
else
$(TOOL_NAME)_INSTALL_PATH = /usr/local/bin
endif
$(TOOL_NAME)_PRIVATE_FRAMEWORKS = MobileCoreServices

LIBRARY_NAME = mldecryptor
$(LIBRARY_NAME)_FILES = Sources/load.s $(shell find Sources/$(LIBRARY_NAME) -name '*.swift') $(shell find $(THEOS)/include/kittymemswift -name '*.mm')
$(LIBRARY_NAME)_CFLAGS = -fobjc-arc -w
$(LIBRARY_NAME)_LIBRARIES = substrate

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk

ifeq ($(ROOTLESS),1)
before-package::
	ldid -S./entitlements.plist $(THEOS_STAGING_DIR)/var/jb/usr/bin/$(TOOL_NAME);

# if ldid doesn't work...push entitlements.plist and do ldid on the device
after-install::
	scp -P2222 entitlements.plist root@localhost:~/
	install.exec "ldid -Sentitlements.plist /var/jb/usr/bin/mldecrypt"
else
before-package::
	ldid -S./entitlements.plist $(THEOS_STAGING_DIR)/usr/local/bin/$(TOOL_NAME);

# if ldid doesn't work...push entitlements.plist and do ldid on the device
after-install::
	scp -P2222 entitlements.plist root@localhost:~/
	install.exec "ldid -Sentitlements.plist /usr/local/bin/mldecrypt"
endif

include $(THEOS_MAKE_PATH)/tool.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
