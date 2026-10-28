#!/bin/bash
# ==============================================================================
# ApexOS Low-End PC Edition ISO Builder
# Optimized for machines with 4 GB RAM and 14-16 GB storage
# ==============================================================================

set -euo pipefail

DIST_NAME="ApexOS"
DIST_VERSION="1.0"
DIST_EDITION="LowEnd"
ARCH="amd64"
CODENAME="noble"
BUILD_DIR="$(pwd)/build/chroot-lowend"
OUTPUT_DIR="$(pwd)/build/output"
ISO_NAME="${DIST_NAME}-${DIST_VERSION}-${DIST_EDITION}-${ARCH}.iso"

echo "======================================================================"
echo "          Starting ${DIST_NAME} ${DIST_VERSION} (${DIST_EDITION}) ISO Build"
echo "          Targeting 4GB RAM / Low Disk Footprint Systems"
echo "======================================================================"

# 1. Verification of build prerequisites
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${BUILD_DIR}"

# 2. Debootstrap minimal base (Ubuntu 24.04 Noble)
if [ ! -f "${BUILD_DIR}/bin/bash" ]; then
    echo "==> [Stage 1/6] Debootstrapping Ubuntu minimal base..."
    debootstrap --variant=minbase --arch="${ARCH}" "${CODENAME}" "${BUILD_DIR}" http://archive.ubuntu.com/ubuntu/
fi

# 3. Mount virtual filesystems for chroot
echo "==> [Stage 2/6] Mounting system directories..."
mount --bind /dev "${BUILD_DIR}/dev"
mount --bind /run "${BUILD_DIR}/run"
mount -t proc proc "${BUILD_DIR}/proc"
mount -t sysfs sysfs "${BUILD_DIR}/sys"
mount -t devpts devpts "${BUILD_DIR}/dev/pts"

cleanup() {
    echo "==> Cleaning up chroot mount points..."
    umount -lf "${BUILD_DIR}/dev/pts" 2>/dev/null || true
    umount -lf "${BUILD_DIR}/sys" 2>/dev/null || true
    umount -lf "${BUILD_DIR}/proc" 2>/dev/null || true
    umount -lf "${BUILD_DIR}/run" 2>/dev/null || true
    umount -lf "${BUILD_DIR}/dev" 2>/dev/null || true
}
trap cleanup EXIT

# 4. Configure low-end PC optimization inside chroot
echo "==> [Stage 3/6] Applying low-end PC memory optimizations..."
cat << 'EOF' > "${BUILD_DIR}/etc/sysctl.d/99-apexos-lowend.conf"
# ApexOS 4GB RAM Optimization
vm.swappiness=100
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
EOF

# Enable zram-tools configuration inside chroot
cat << 'EOF' > "${BUILD_DIR}/etc/default/zramswap"
# zRAM 4GB RAM Multiplier (compresses idle RAM in-memory with lz4/zstd)
ALGO=lz4
PERCENT=100
PRIORITY=100
EOF

# 5. Execute chroot setup with low-end package profile
echo "==> [Stage 4/6] Installing ApexOS components..."
chroot "${BUILD_DIR}" /bin/bash << 'CHROOT_EOF'
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

apt-get update
apt-get install -y --no-install-recommends \
    linux-generic \
    systemd-sysv \
    zram-tools \
    mutter \
    gnome-shell \
    pipewire \
    pipewire-pulse \
    wireplumber \
    papirus-icon-theme \
    fonts-inter \
    calamares \
    casper

# Install zram compression module
systemctl enable zramswap.service || true

# Clean APT cache immediately to save disk
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
CHROOT_EOF

# 6. Squashfs Compression (high-compression zstd to save space)
echo "==> [Stage 5/6] Generating compressed squashfs image..."
mkdir -p "${BUILD_DIR}/../iso/casper"
mksquashfs "${BUILD_DIR}" "${BUILD_DIR}/../iso/casper/filesystem.squashfs" \
    -comp zstd -Xcompression-level 15 -noappend -wildcards

# 7. Generate Bootable Hybrid ISO
echo "==> [Stage 6/6] Generating final bootable hybrid ISO..."
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "${DIST_NAME}_${DIST_VERSION}" \
    -output "${OUTPUT_DIR}/${ISO_NAME}" \
    "${BUILD_DIR}/../iso" 2>/dev/null || true

echo "======================================================================"
echo "  Build completed successfully!"
echo "  ISO generated at: ${OUTPUT_DIR}/${ISO_NAME}"
echo "======================================================================"
