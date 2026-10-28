#!/bin/bash
###############################################################################
# SatasOS ISO Build Script
# Uses live-build to create a bootable Ubuntu-based ISO image
# Base: Ubuntu 24.04 LTS (Noble Numbat)
###############################################################################
set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${SCRIPT_DIR}/work"
CONFIG_DIR="${SCRIPT_DIR}/config"
HOOKS_DIR="${SCRIPT_DIR}/hooks"
OUTPUT_DIR="${PROJECT_ROOT}/dist"

ISO_LABEL="SatasOS 1.0"
ISO_FILENAME="satasos-1.0-amd64.iso"
ISO_PUBLISHER="SatasOS Project"
ISO_APPLICATION="SatasOS Live/Install Media"

UBUNTU_MIRROR="http://archive.ubuntu.com/ubuntu"
UBUNTU_SECURITY_MIRROR="http://security.ubuntu.com/ubuntu"
UBUNTU_SUITE="noble"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================
log_info() {
    echo -e "${PURPLE}[SatasOS Build]${NC} ${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${PURPLE}[SatasOS Build]${NC} ${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${PURPLE}[SatasOS Build]${NC} ${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_dependencies() {
    log_info "Checking build dependencies..."
    local deps=(live-build debootstrap squashfs-tools xorriso grub-pc-bin
                grub-efi-amd64-bin grub-efi-amd64-signed shim-signed
                mtools dosfstools syslinux syslinux-utils isolinux)
    local missing=()

    for dep in "${deps[@]}"; do
        if ! dpkg -l "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Installing missing dependencies: ${missing[*]}"
        apt-get update -qq
        apt-get install -y "${missing[@]}"
    fi

    log_info "All build dependencies satisfied."
}

# =============================================================================
# Build Phases
# =============================================================================
phase_clean() {
    log_info "Cleaning previous build artifacts..."
    if [[ -d "$BUILD_DIR" ]]; then
        cd "$BUILD_DIR"
        lb clean --purge 2>/dev/null || true
        cd "$SCRIPT_DIR"
        rm -rf "$BUILD_DIR"
    fi
    log_info "Clean complete."
}

phase_configure() {
    log_info "Configuring live-build..."

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Initialize live-build configuration
    lb config \
        --binary-images iso-hybrid \
        --mode ubuntu \
        --distribution "$UBUNTU_SUITE" \
        --archive-areas "main restricted universe multiverse" \
        --mirror-bootstrap "$UBUNTU_MIRROR" \
        --mirror-chroot "$UBUNTU_MIRROR" \
        --mirror-chroot-security "$UBUNTU_SECURITY_MIRROR" \
        --mirror-binary "$UBUNTU_MIRROR" \
        --mirror-binary-security "$UBUNTU_SECURITY_MIRROR" \
        --architectures amd64 \
        --linux-flavours generic \
        --linux-packages "linux-image linux-headers" \
        --bootappend-live "boot=casper quiet splash locale=en_US.UTF-8 keyboard-configuration/layoutcode=us" \
        --bootappend-install "boot=casper quiet splash" \
        --memtest none \
        --iso-application "$ISO_APPLICATION" \
        --iso-publisher "$ISO_PUBLISHER" \
        --iso-volume "$ISO_LABEL" \
        --debootstrap-options "--include=apt-transport-https,ca-certificates,gnupg,wget,curl" \
        --apt-recommends true \
        --security true \
        --updates true \
        --backports true \
        --cache true \
        --cache-packages true \
        --firmware-binary true \
        --firmware-chroot true \
        --uefi-secure-boot enable \
        --binary-filesystem ext4 \
        --initramfs auto \
        --initsystem systemd \
        --interactive false \
        --win32-loader false \
        --checksums sha256

    log_info "Live-build configuration complete."
}

phase_copy_config() {
    log_info "Copying SatasOS configuration files..."
    cd "$BUILD_DIR"

    # Copy package lists
    mkdir -p config/package-lists
    for list_file in "${CONFIG_DIR}/package-lists/"*.list; do
        if [[ -f "$list_file" ]]; then
            cp "$list_file" config/package-lists/
            log_info "  Added package list: $(basename "$list_file")"
        fi
    done

    # Copy APT sources configuration
    mkdir -p config/archives
    if [[ -f "${CONFIG_DIR}/apt/sources.list" ]]; then
        cp "${CONFIG_DIR}/apt/sources.list" config/archives/satasos.list.chroot
        log_info "  Added APT sources"
    fi

    # Copy APT preferences (pinning)
    if [[ -f "${CONFIG_DIR}/apt/preferences" ]]; then
        mkdir -p config/apt
        cp "${CONFIG_DIR}/apt/preferences" config/apt/preferences.chroot
        log_info "  Added APT preferences"
    fi

    # Copy any GPG keys for third-party repos
    if [[ -d "${CONFIG_DIR}/apt/keys" ]]; then
        mkdir -p config/archives
        for key in "${CONFIG_DIR}/apt/keys/"*.gpg; do
            if [[ -f "$key" ]]; then
                cp "$key" config/archives/
                log_info "  Added GPG key: $(basename "$key")"
            fi
        done
    fi

    # Copy includes.chroot (files to place directly in the live filesystem)
    if [[ -d "${CONFIG_DIR}/includes.chroot" ]]; then
        cp -r "${CONFIG_DIR}/includes.chroot" config/includes.chroot
        log_info "  Added chroot includes"
    fi

    # Copy includes.binary (files for the ISO filesystem)
    if [[ -d "${CONFIG_DIR}/includes.binary" ]]; then
        cp -r "${CONFIG_DIR}/includes.binary" config/includes.binary
        log_info "  Added binary includes"
    fi

    log_info "Configuration files copied."
}

phase_copy_hooks() {
    log_info "Setting up build hooks..."
    cd "$BUILD_DIR"

    mkdir -p config/hooks/live

    # Copy numbered hook scripts in order
    local hook_count=0
    for hook in "${HOOKS_DIR}/"*.sh; do
        if [[ -f "$hook" ]]; then
            cp "$hook" config/hooks/live/
            chmod +x "config/hooks/live/$(basename "$hook")"
            log_info "  Added hook: $(basename "$hook")"
            ((hook_count++))
        fi
    done

    # Copy the chroot-setup script as a hook
    if [[ -f "${SCRIPT_DIR}/chroot-setup.sh" ]]; then
        cp "${SCRIPT_DIR}/chroot-setup.sh" config/hooks/live/00-chroot-setup.sh
        chmod +x config/hooks/live/00-chroot-setup.sh
        log_info "  Added chroot-setup hook"
        ((hook_count++))
    fi

    log_info "Added ${hook_count} build hooks."
}

phase_setup_bootloader() {
    log_info "Configuring bootloader (UEFI + Legacy BIOS)..."
    cd "$BUILD_DIR"

    # GRUB configuration for UEFI
    mkdir -p config/includes.binary/boot/grub
    cat > config/includes.binary/boot/grub/grub.cfg << 'GRUB_EOF'
# SatasOS GRUB Configuration
# Supports UEFI and Legacy BIOS boot

set default=0
set timeout=10
set gfxmode=auto
set gfxpayload=keep

# Load video modules
insmod all_video
insmod gfxterm
insmod png

# Set terminal
terminal_output gfxterm

# SatasOS Purple Theme
set color_normal=light-gray/black
set color_highlight=white/purple
set menu_color_normal=light-gray/black
set menu_color_highlight=white/purple

# SatasOS Boot Menu
menuentry "Start SatasOS (Live Session)" --class satasos --class linux {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper quiet splash locale=en_US.UTF-8 ---
    initrd /casper/initrd
}

menuentry "Start SatasOS (Safe Graphics)" --class satasos --class linux {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper quiet splash nomodeset locale=en_US.UTF-8 ---
    initrd /casper/initrd
}

menuentry "Install SatasOS" --class calamares --class linux {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper quiet splash locale=en_US.UTF-8 install ---
    initrd /casper/initrd
}

menuentry "OEM Install (for manufacturers)" --class calamares --class linux {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper quiet splash locale=en_US.UTF-8 oem-config/enable=true ---
    initrd /casper/initrd
}

menuentry "Check disc for defects" --class linux {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper integrity-check quiet splash ---
    initrd /casper/initrd
}

menuentry "Boot from first hard disk" --class hd {
    chainloader +1
}

menuentry "UEFI Firmware Settings" --class efi {
    fwsetup
}
GRUB_EOF

    # SYSLINUX / ISOLINUX configuration for Legacy BIOS
    mkdir -p config/includes.binary/isolinux
    cat > config/includes.binary/isolinux/isolinux.cfg << 'SYSLINUX_EOF'
# SatasOS ISOLINUX Configuration (Legacy BIOS)

DEFAULT live
PROMPT 0
TIMEOUT 100

UI vesamenu.c32

MENU TITLE SatasOS 1.0 Boot Menu
MENU BACKGROUND splash.png
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #ff7c3aed #00000000 std
MENU COLOR sel          7;37;40 #e0ffffff #207c3aed all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

LABEL live
    MENU LABEL ^Start SatasOS (Live Session)
    MENU DEFAULT
    KERNEL /casper/vmlinuz
    APPEND initrd=/casper/initrd boot=casper quiet splash locale=en_US.UTF-8 ---

LABEL safe
    MENU LABEL Start SatasOS (^Safe Graphics)
    KERNEL /casper/vmlinuz
    APPEND initrd=/casper/initrd boot=casper quiet splash nomodeset locale=en_US.UTF-8 ---

LABEL install
    MENU LABEL ^Install SatasOS
    KERNEL /casper/vmlinuz
    APPEND initrd=/casper/initrd boot=casper quiet splash locale=en_US.UTF-8 install ---

LABEL hd
    MENU LABEL ^Boot from first hard disk
    LOCALBOOT 0x80
SYSLINUX_EOF

    log_info "Bootloader configuration complete."
}

phase_setup_calamares() {
    log_info "Setting up Calamares installer..."
    cd "$BUILD_DIR"

    # Calamares configuration directory
    local cal_dir="config/includes.chroot/etc/calamares"
    mkdir -p "${cal_dir}/branding/satasos"
    mkdir -p "${cal_dir}/modules"

    # Main Calamares settings
    cat > "${cal_dir}/settings.conf" << 'CAL_SETTINGS_EOF'
# SatasOS Calamares Installer Configuration
---
modules-search: [ local, /usr/lib/calamares/modules ]

sequence:
  - show:
      - welcome
      - locale
      - keyboard
      - partition
      - users
      - summary
  - exec:
      - partition
      - mount
      - unpackfs
      - machineid
      - fstab
      - locale
      - keyboard
      - localecfg
      - luksbootkeyfile
      - users
      - displaymanager
      - networkcfg
      - hwclock
      - services-systemd
      - packages
      - bootloader
      - shellprocess
      - umount
  - show:
      - finished

branding: satasos

prompt-install: true
dont-chroot: false
oem-setup: false
disable-cancel: false
disable-cancel-during-exec: false
hide-back-and-next-during-exec: false
quit-at-end: false
CAL_SETTINGS_EOF

    # Calamares SatasOS branding
    cat > "${cal_dir}/branding/satasos/branding.desc" << 'CAL_BRANDING_EOF'
---
componentName: satasos

strings:
    productName:         "SatasOS"
    shortProductName:    "SatasOS"
    version:             "1.0"
    shortVersion:        "1.0"
    versionedName:       "SatasOS 1.0"
    shortVersionedName:  "SatasOS 1.0"
    bootloaderEntryName: "SatasOS"
    productUrl:          "https://satasos.org"
    supportUrl:          "https://satasos.org/support"
    knownIssuesUrl:      "https://satasos.org/issues"
    releaseNotesUrl:     "https://satasos.org/releases/1.0"

images:
    productLogo:         "satasos-logo.png"
    productIcon:         "satasos-icon.png"
    productWelcome:      "satasos-welcome.png"

slideshow:               "show.qml"

style:
    sidebarBackground:   "#1E1B2E"
    sidebarText:         "#FFFFFF"
    sidebarTextSelect:   "#7C3AED"
    sidebarTextHighlight: "#A78BFA"
CAL_BRANDING_EOF

    # Calamares display manager module config
    cat > "${cal_dir}/modules/displaymanager.conf" << 'CAL_DM_EOF'
---
displaymanagers:
  - gdm
  - lightdm
CAL_DM_EOF

    # Calamares unpackfs module config
    cat > "${cal_dir}/modules/unpackfs.conf" << 'CAL_UNPACKFS_EOF'
---
unpack:
  - source: "/cdrom/casper/filesystem.squashfs"
    sourcefs: "squashfs"
    destination: ""
CAL_UNPACKFS_EOF

    # Calamares bootloader module config
    cat > "${cal_dir}/modules/bootloader.conf" << 'CAL_BOOT_EOF'
---
efiBootLoader: "grub"
kernel: "/vmlinuz"
img: "/initrd.img"
timeout: 10
kernelLine: ", with SatasOS"
fallbackKernelLine: ", with SatasOS (fallback)"
grubInstall: "grub-install"
grubMkconfig: "grub-mkconfig"
grubCfg: "/boot/grub/grub.cfg"
grubProbe: "grub-probe"
efiBootloaderId: "SatasOS"
CAL_BOOT_EOF

    # Calamares finished module config
    cat > "${cal_dir}/modules/finished.conf" << 'CAL_FINISHED_EOF'
---
restartNowEnabled: true
restartNowChecked: true
restartNowCommand: "systemctl -i reboot"
notifyOnFinished: true
CAL_FINISHED_EOF

    # Calamares shellprocess for post-install customizations
    cat > "${cal_dir}/modules/shellprocess.conf" << 'CAL_SHELL_EOF'
---
dontChroot: false
timeout: 300
script:
  - command: "/usr/bin/env bash -c 'update-grub'"
    timeout: 120
  - command: "/usr/bin/env bash -c 'update-initramfs -u'"
    timeout: 120
CAL_SHELL_EOF

    log_info "Calamares installer configured."
}

phase_build() {
    log_info "Starting ISO build process..."
    log_info "This may take 30-60 minutes depending on network speed and system resources."
    cd "$BUILD_DIR"

    # Build the ISO
    lb build 2>&1 | tee "${SCRIPT_DIR}/build.log"

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log_error "Build failed! Check ${SCRIPT_DIR}/build.log for details."
        exit 1
    fi

    log_info "Build completed successfully."
}

phase_output() {
    log_info "Collecting output..."

    mkdir -p "$OUTPUT_DIR"

    # Find the generated ISO
    local iso_file
    iso_file=$(find "$BUILD_DIR" -maxdepth 1 -name "*.iso" -type f | head -1)

    if [[ -z "$iso_file" ]]; then
        log_error "No ISO file found after build!"
        exit 1
    fi

    # Move and rename the ISO
    mv "$iso_file" "${OUTPUT_DIR}/${ISO_FILENAME}"
    log_info "ISO moved to: ${OUTPUT_DIR}/${ISO_FILENAME}"

    # Generate checksums
    cd "$OUTPUT_DIR"
    sha256sum "$ISO_FILENAME" > "${ISO_FILENAME}.sha256"
    md5sum "$ISO_FILENAME" > "${ISO_FILENAME}.md5"

    # Display ISO info
    local iso_size
    iso_size=$(du -h "${OUTPUT_DIR}/${ISO_FILENAME}" | cut -f1)

    echo ""
    echo -e "${PURPLE}============================================${NC}"
    echo -e "${PURPLE}  SatasOS 1.0 Build Complete!${NC}"
    echo -e "${PURPLE}============================================${NC}"
    echo -e "  ISO:      ${OUTPUT_DIR}/${ISO_FILENAME}"
    echo -e "  Size:     ${iso_size}"
    echo -e "  SHA256:   $(cat "${ISO_FILENAME}.sha256" | cut -d' ' -f1)"
    echo -e "${PURPLE}============================================${NC}"
    echo ""
}

# =============================================================================
# Main Entry Point
# =============================================================================
main() {
    echo -e "${PURPLE}"
    echo "  ____        _           ___  ____  "
    echo " / ___|  __ _| |_ __ _ __/ _ \\/ ___| "
    echo " \\___ \\ / _\` | __/ _\` / __| | \\___ \\ "
    echo "  ___) | (_| | || (_| \\__ \\ |_|___) |"
    echo " |____/ \\__,_|\\__\\__,_|___/\\___/____/ "
    echo "                                      "
    echo "  ISO Build System v1.0               "
    echo -e "${NC}"

    check_root
    check_dependencies

    # Parse arguments
    local skip_clean=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-clean)
                skip_clean=true
                shift
                ;;
            --clean-only)
                phase_clean
                exit 0
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --no-clean     Skip cleaning previous build"
                echo "  --clean-only   Only clean, don't build"
                echo "  --help, -h     Show this help"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Execute build phases in order
    if [[ "$skip_clean" == false ]]; then
        phase_clean
    fi

    phase_configure
    phase_copy_config
    phase_copy_hooks
    phase_setup_bootloader
    phase_setup_calamares
    phase_build
    phase_output

    log_info "All done! Your SatasOS ISO is ready."
}

main "$@"
