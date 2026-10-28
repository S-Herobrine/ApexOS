# ApexOS Unified Multi-Edition Build Automation Makefile

SHELL := /bin/bash
PROJECT_NAME := ApexOS
VERSION := 1.0
ARCH := amd64
OUTPUT_DIR := build/output
ISO_LOWEND := $(PROJECT_NAME)-$(VERSION)-LowEnd-$(ARCH).iso
ISO_STANDARD := $(PROJECT_NAME)-$(VERSION)-Standard-$(ARCH).iso

.PHONY: all clean install-deps build-lowend build-standard build-all test-lowend test-standard help

all: help

help:
	@echo "=================================================================="
	@echo "                   ApexOS Build System                           "
	@echo "=================================================================="
	@echo "Available build targets:"
	@echo "  make install-deps    - Install build tools (debootstrap, xorriso, etc.)"
	@echo "  make build-lowend    - Build ApexOS Low-End ISO (4GB RAM, <2GB ISO)"
	@echo "  make build-standard  - Build ApexOS Standard ISO (8GB+ RAM, Full App Suite)"
	@echo "  make build-all       - Build BOTH Low-End and Standard ISOs"
	@echo "  make test-lowend     - Boot Low-End ISO in QEMU (4GB RAM emulation)"
	@echo "  make test-standard   - Boot Standard ISO in QEMU (8GB RAM emulation)"
	@echo "  make clean           - Remove temporary build chroots and caches"
	@echo "=================================================================="

install-deps:
	@echo "==> Installing build dependencies..."
	sudo apt update && sudo apt install -y \
		live-build debootstrap xorriso squashfs-tools \
		mtools dosfstools grub-pc-bin grub-efi-amd64-bin \
		isolinux syslinux-utils git make curl wget gnupg zram-tools

build-lowend:
	@echo "==> Building ApexOS Low-End Edition ISO..."
	sudo bash build/build-iso-lowend.sh

build-standard:
	@echo "==> Building ApexOS Standard Edition ISO..."
	sudo bash build/build-iso-standard.sh

build-all: build-lowend build-standard
	@echo "==> Both ApexOS ISO editions built successfully!"

test-lowend:
	@if [ ! -f $(OUTPUT_DIR)/$(ISO_LOWEND) ]; then \
		echo "Error: ISO not found at $(OUTPUT_DIR)/$(ISO_LOWEND). Run 'make build-lowend' first."; \
		exit 1; \
	fi
	@echo "==> Emulating Low-End PC: 4GB RAM, 2 cores..."
	qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 -vga virtio -display gtk,gl=on -cdrom $(OUTPUT_DIR)/$(ISO_LOWEND) -boot d

test-standard:
	@if [ ! -f $(OUTPUT_DIR)/$(ISO_STANDARD) ]; then \
		echo "Error: ISO not found at $(OUTPUT_DIR)/$(ISO_STANDARD). Run 'make build-standard' first."; \
		exit 1; \
	fi
	@echo "==> Emulating Standard PC: 8GB RAM, 4 cores..."
	qemu-system-x86_64 -enable-kvm -m 8192 -smp 4 -vga virtio -display gtk,gl=on -cdrom $(OUTPUT_DIR)/$(ISO_STANDARD) -boot d

clean:
	@echo "==> Cleaning temporary build files..."
	sudo rm -rf build/chroot-lowend build/chroot-standard build/iso build/iso-standard
	@echo "==> Clean complete."
