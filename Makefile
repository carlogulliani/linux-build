export RELEASE_NAME ?= 0.1~dev
export RELEASE ?= 1
export BOOT_TOOLS_BRANCH ?= master
export KERNEL_DIR ?= kernel
export UBOOT_DIR ?= u-boot

BUILD_SYSTEMS := bionic xenial jessie stretch
BUILD_VARIANTS := minimal mate lxde i3 openmediavault containers
BUILD_ARCHS := armhf arm64
BUILD_MODELS := rock64 rockpro64

KERNEL_EXTRAVERSION ?= -rockchip-ayufan-$(RELEASE)
KERNEL_DEFCONFIG ?= rockchip_linux_defconfig

BOARD_TARGET ?= rock64

ifeq (rock64,$(BOARD_TARGET))
ATF_PLAT ?= rk322xh
UBOOT_DEFCONFIG ?= rock64-rk3328_defconfig
BOARD_CHIP ?= rk3328
else ifeq (rockpro64,$(BOARD_TARGET))
ATF_PLAT ?= rk3399
UBOOT_DEFCONFIG ?= rockpro64-rk3399_defconfig
BL31 ?= rkbin/rk33/rk3399_bl31_v1.00.elf
BOARD_CHIP ?= rk3399
USE_UBOOT_SPL ?= yes
else
$(error Unsupported BOARD_TARGET)
endif

REMOTE_HOST ?= rock64.home

IMAGE_SUFFIX := $(RELEASE_NAME)-$(RELEASE)

all: linux-rock64

include Makefile.atf.mk
include Makefile.uboot.mk
include Makefile.package.mk
include Makefile.kernel.mk
include Makefile.system.mk
include Makefile.variants.mk
include Makefile.loader.mk
include Makefile.dev.mk

