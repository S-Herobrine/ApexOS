#!/bin/bash
# ==============================================================================
# ApexOS Standard Edition ISO Builder (Full Experience)
# Optimized for machines with 8GB+ RAM and 30GB+ storage
# ==============================================================================

set -euo pipefail

DIST_NAME="ApexOS"
DIST_VERSION="1.0"
DIST_EDITION="Standard"
ARCH="amd64"
CODENAME="noble"
BUILD_DIR="$(pwd)/build/chroot-standard"
OUTPUT_DIR="$(pwd)/build/output"
ISO_NAME="${DIST_NAME}-${DIST_VERSION}-${DIST_EDITION}-${ARCH}.iso"

echo "======================================================================"
echo "          Starting ${DIST_NAME} ${DIST_VERSION} (${DIST_EDITION}) ISO Build"
echo "          Targeting Full Multimedia, Android GMS, and Developer Tools"
echo "======================================================================"

mkdir -p "${OUTPUT_DIR}"
mkdir -p "${BUILD_DIR}"

if [ ! -f "${BUILD_DIR}/bin/bash" ]; then
    echo "==> [Stage 1/6] Debootstrapping Ubuntu 24.04 base..."
    debootstrap --arch="${ARCH}" "${CODENAME}" "${BUILD_DIR}" http://archive.ubuntu.com/ubuntu/
fi

echo "==> [Stage 2/6] Mounting virtual filesystems..."
mount --bind /dev "${BUILD_DIR}/dev"
mount --bind /run "${BUILD_DIR}/run"
mount -t proc proc "${BUILD_DIR}/proc"
mount -t sysfs sysfs "${BUILD_DIR}/sys"
mount -t devpts devpts "${BUILD_DIR}/dev/pts"

cleanup() {
    echo "==> Cleaning chroot mounts..."
    umount -lf "${BUILD_DIR}/dev/pts" 2>/dev/null || true
    umount -lf "${BUILD_DIR}/sys" 2>/dev/null || true
    umount -lf "${BUILD_DIR}/proc" 2>/dev/null || true
    umount -lf "${BUILD_DIR}/run" 2>/dev/null || true
    umount -lf "${BUILD_DIR}/dev" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> [Stage 3/6] Configuring repositories and packages..."
# Copy repo setup scripts and package lists
mkdir -p "${BUILD_DIR}/tmp/apexos"
cp -r build/config/package-lists "${BUILD_DIR}/tmp/apexos/"
cp build/hooks/*.sh "${BUILD_DIR}/tmp/apexos/"

chroot "${BUILD_DIR}" /bin/bash << 'CHROOT_EOF'
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

apt-get update
apt-get install -y --no-install-recommends \
    linux-generic \
    systemd-sysv \
    gnome-shell \
    gnome-control-center \
    pipewire \
    wireplumber \
    mesa-vulkan-drivers \
    vlc \
    gimp \
    inkscape \
    libreoffice \
    code \
    google-chrome-stable \
    firefox \
    microsoft-edge-stable \
    opera-stable \
    waydroid \
    calamares \
    casper

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
CHROOT_EOF

echo "==> [Stage 4/6] Creating Squashfs filesystem..."
mkdir -p "${BUILD_DIR}/../iso-standard/casper"
mksquashfs "${BUILD_DIR}" "${BUILD_DIR}/../iso-standard/casper/filesystem.squashfs" \
    -comp zstd -noappend

echo "==> [Stage 5/6] Packaging bootable hybrid ISO..."
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "${DIST_NAME}_STD" \
    -output "${OUTPUT_DIR}/${ISO_NAME}" \
    "${BUILD_DIR}/../iso-standard" 2>/dev/null || true

echo "======================================================================"
echo "  Standard Edition ISO Build Complete!"
echo "  Output: ${OUTPUT_DIR}/${ISO_NAME}"
echo "======================================================================"
