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

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="/tmp/apexos-build"
BUILD_DIR="${WORK_DIR}/chroot"
ISO_DIR="${WORK_DIR}/iso"
OUTPUT_DIR="${WORKSPACE_ROOT}/build/output"
ISO_NAME="${DIST_NAME}-${DIST_VERSION}-${DIST_EDITION}-${ARCH}.iso"

echo "======================================================================"
echo "          Starting ${DIST_NAME} ${DIST_VERSION} (${DIST_EDITION}) ISO Build"
echo "          Targeting 4GB RAM / Low Disk Footprint Systems"
echo "======================================================================"

# Ensure clean working directories
rm -rf "${WORK_DIR}"
mkdir -p "${OUTPUT_DIR}" "${BUILD_DIR}" "${ISO_DIR}/casper" "${ISO_DIR}/boot/grub"

# 1. Debootstrap minimal Ubuntu 24.04 LTS (Noble) base
echo "==> [Stage 1/7] Debootstrapping Ubuntu minimal base..."
debootstrap --variant=minbase --arch="${ARCH}" "${CODENAME}" "${BUILD_DIR}" http://archive.ubuntu.com/ubuntu/

# 2. Configure Repositories & DNS inside chroot
echo "==> [Stage 2/7] Configuring APT sources and networking..."
cp /etc/resolv.conf "${BUILD_DIR}/etc/resolv.conf"

cat << 'EOF' > "${BUILD_DIR}/etc/apt/sources.list"
deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
EOF

# Low-End RAM kernel optimizations
cat << 'EOF' > "${BUILD_DIR}/etc/sysctl.d/99-apexos-lowend.conf"
vm.swappiness=100
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
EOF

# zRAM swap configuration
cat << 'EOF' > "${BUILD_DIR}/etc/default/zramswap"
ALGO=lz4
PERCENT=100
PRIORITY=100
EOF

# 3. Mount virtual filesystems for chroot package management
echo "==> [Stage 3/7] Mounting chroot virtual filesystems..."
mount -t proc proc "${BUILD_DIR}/proc"
mount -t sysfs sysfs "${BUILD_DIR}/sys"
mount --bind /dev "${BUILD_DIR}/dev"
mount --bind /dev/pts "${BUILD_DIR}/dev/pts"

unmount_chroot() {
    echo "==> Unmounting chroot filesystems..."
    umount -lf "${BUILD_DIR}/dev/pts" 2>/dev/null || true
    umount -lf "${BUILD_DIR}/dev" 2>/dev/null || true
    umount -lf "${BUILD_DIR}/sys" 2>/dev/null || true
    umount -lf "${BUILD_DIR}/proc" 2>/dev/null || true
}
trap unmount_chroot EXIT

# 4. Install Core Packages & Live Boot System inside chroot
echo "==> [Stage 4/7] Installing kernel, casper, and desktop packages..."
chroot "${BUILD_DIR}" /bin/bash << 'CHROOT_EOF'
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

apt-get update
apt-get install -y --no-install-recommends \
    linux-generic \
    casper \
    user-setup \
    systemd-sysv \
    systemd \
    dbus \
    libpam-systemd \
    network-manager \
    locales \
    sudo \
    zram-tools \
    mutter \
    gnome-shell \
    gdm3 \
    pipewire \
    pipewire-pulse \
    wireplumber \
    papirus-icon-theme \
    fonts-inter \
    firefox \
    calamares \
    zenity

# Initialize machine-id (critical: prevents systemd PID 1 exit failure)
systemd-machine-id-setup
touch /etc/machine-id

# Configure default locale and hostname
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
echo "apexos" > /etc/hostname

# Pre-create live user 'apex' with password 'apex' and sudo rights
if ! id -u apex &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,adm,audio,video,plugdev,netdev apex
    echo "apex:apex" | chpasswd
    echo "root:apexos" | chpasswd
    echo "apex ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/apex
    chmod 0440 /etc/sudoers.d/apex
fi

# Configure GDM3 autologin for live session
mkdir -p /etc/gdm3
cat << 'GDM_EOF' > /etc/gdm3/custom.conf
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=apex
WaylandEnable=true
GDM_EOF

# Enable zram
systemctl enable zramswap.service || true

# Update initramfs with casper live hooks
update-initramfs -u -k all

# Clean APT caches to keep image small
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
CHROOT_EOF

# 5. Inject ApexOS Themes, Wallpapers, and Shell configs
echo "==> [Stage 5/7] Injecting ApexOS desktop customizations..."
mkdir -p "${BUILD_DIR}/usr/share/backgrounds/apexos"
mkdir -p "${BUILD_DIR}/usr/share/themes/ApexOS-Dark"
mkdir -p "${BUILD_DIR}/usr/share/themes/ApexOS-Light"
mkdir -p "${BUILD_DIR}/usr/local/bin"

if [ -d "${WORKSPACE_ROOT}/themes/wallpapers" ]; then
    cp -r "${WORKSPACE_ROOT}/themes/wallpapers/"* "${BUILD_DIR}/usr/share/backgrounds/apexos/" 2>/dev/null || true
fi
if [ -d "${WORKSPACE_ROOT}/themes/gtk-3.0" ]; then
    cp -r "${WORKSPACE_ROOT}/themes/gtk-3.0" "${BUILD_DIR}/usr/share/themes/ApexOS-Dark/" 2>/dev/null || true
fi
if [ -d "${WORKSPACE_ROOT}/themes/gtk-4.0" ]; then
    cp -r "${WORKSPACE_ROOT}/themes/gtk-4.0" "${BUILD_DIR}/usr/share/themes/ApexOS-Dark/" 2>/dev/null || true
fi

if [ -d "${WORKSPACE_ROOT}/scripts" ]; then
    cp "${WORKSPACE_ROOT}/scripts/"*.sh "${BUILD_DIR}/usr/local/bin/" 2>/dev/null || true
    cp "${WORKSPACE_ROOT}/scripts/"*.py "${BUILD_DIR}/usr/local/bin/" 2>/dev/null || true
    chmod +x "${BUILD_DIR}/usr/local/bin/"* 2>/dev/null || true
fi

# Extract Kernel and Initrd for Live Boot before unmounting
echo "==> Extracting live kernel and initramfs..."
VMLINUZ=$(ls -1 "${BUILD_DIR}/boot/vmlinuz-"* | tail -n1)
INITRD=$(ls -1 "${BUILD_DIR}/boot/initrd.img-"* | tail -n1)
cp "${VMLINUZ}" "${ISO_DIR}/casper/vmlinuz"
cp "${INITRD}" "${ISO_DIR}/casper/initrd"

# 6. CRITICAL: Unmount ALL virtual filesystems BEFORE mksquashfs!
unmount_chroot
trap - EXIT

# Remove temporary resolv.conf
rm -f "${BUILD_DIR}/etc/resolv.conf"

# Generate Squashfs with fast zstd compression (Level 3 for fast build)
echo "==> [Stage 6/7] Creating compressed squashfs filesystem (~3-5 mins)..."
mksquashfs "${BUILD_DIR}" "${ISO_DIR}/casper/filesystem.squashfs" \
    -comp zstd -Xcompression-level 3 -noappend \
    -e proc sys dev run tmp mnt media

# 7. Create GRUB2 Boot Configuration with 'rw' mode for read-write overlay
echo "==> [Stage 7/7] Packaging Bootable Hybrid ISO image..."

cat << 'EOF' > "${ISO_DIR}/boot/grub/grub.cfg"
set default="0"
set timeout=5

insmod font
if loadfont /boot/grub/font.pf2 ; then
    insmod gfxterm
    set gfxmode=auto
    terminal_output gfxterm
fi

menuentry "Start ApexOS 1.0 (Low-End Edition - 4GB RAM)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper username=apex hostname=apexos rw systemd.show_status=1 ---
    initrd /casper/initrd
}

menuentry "Start ApexOS 1.0 (Safe Graphics Mode)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper username=apex hostname=apexos rw nomodeset systemd.show_status=1 ---
    initrd /casper/initrd
}

menuentry "Check Media for Defects" {
    linux /casper/vmlinuz boot=casper checkfs ---
    initrd /casper/initrd
}
EOF

# Package bootable ISO with grub-mkrescue (supports both UEFI and Legacy BIOS)
grub-mkrescue -o "${OUTPUT_DIR}/${ISO_NAME}" "${ISO_DIR}" \
    -- -volid "ApexOS_1_0_LowEnd" 2>/dev/null || \
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "ApexOS_1_0_LowEnd" \
    -output "${OUTPUT_DIR}/${ISO_NAME}" \
    "${ISO_DIR}"

# Cleanup temporary workdir
rm -rf "${WORK_DIR}"

echo "======================================================================"
echo "  SUCCESS! ApexOS Low-End ISO generated."
echo "  ISO Path: ${OUTPUT_DIR}/${ISO_NAME}"
echo "======================================================================"
