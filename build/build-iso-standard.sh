#!/bin/bash
# ==============================================================================
# ApexOS Standard Edition ISO Builder (Full App & Multimedia Suite)
# Optimized for machines with 8GB+ RAM
# ==============================================================================

set -euo pipefail

DIST_NAME="ApexOS"
DIST_VERSION="1.0"
DIST_EDITION="Standard"
ARCH="amd64"
CODENAME="noble"

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="/tmp/apexos-build-std"
BUILD_DIR="${WORK_DIR}/chroot"
ISO_DIR="${WORK_DIR}/iso"
OUTPUT_DIR="${WORKSPACE_ROOT}/build/output"
ISO_NAME="${DIST_NAME}-${DIST_VERSION}-${DIST_EDITION}-${ARCH}.iso"

echo "======================================================================"
echo "          Starting ${DIST_NAME} ${DIST_VERSION} (${DIST_EDITION}) ISO Build"
echo "          Targeting Full Multimedia, Android Subsystem, and Dev Tools"
echo "======================================================================"

rm -rf "${WORK_DIR}"
mkdir -p "${OUTPUT_DIR}" "${BUILD_DIR}" "${ISO_DIR}/casper" "${ISO_DIR}/boot/grub"

# 1. Debootstrap base
echo "==> [Stage 1/7] Debootstrapping Ubuntu 24.04 LTS (Noble) base..."
debootstrap --arch="${ARCH}" "${CODENAME}" "${BUILD_DIR}" http://archive.ubuntu.com/ubuntu/

# 2. Configure Repositories & DNS
echo "==> [Stage 2/7] Configuring APT sources..."
cp /etc/resolv.conf "${BUILD_DIR}/etc/resolv.conf"

cat << 'EOF' > "${BUILD_DIR}/etc/apt/sources.list"
deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
EOF

# 3. Mount virtual filesystems
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

# 4. Install Full Package Suite
echo "==> [Stage 4/7] Installing full package suite..."
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
    gnome-shell \
    gnome-control-center \
    gdm3 \
    pipewire \
    pipewire-pulse \
    wireplumber \
    mesa-vulkan-drivers \
    papirus-icon-theme \
    fonts-inter \
    fonts-jetbrains-mono \
    vlc \
    gimp \
    firefox \
    calamares \
    zenity

# Initialize machine-id
systemd-machine-id-setup
touch /etc/machine-id

locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
echo "apexos" > /etc/hostname

# Pre-create live user 'apex' with password 'apex' and sudo
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

update-initramfs -u -k all

apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
CHROOT_EOF

# 5. Inject Themes and Custom Desktop files
echo "==> [Stage 5/7] Injecting ApexOS configurations..."
mkdir -p "${BUILD_DIR}/usr/share/backgrounds/apexos"
mkdir -p "${BUILD_DIR}/usr/share/themes/ApexOS-Dark"
mkdir -p "${BUILD_DIR}/usr/local/bin"

if [ -d "${WORKSPACE_ROOT}/themes/wallpapers" ]; then
    cp -r "${WORKSPACE_ROOT}/themes/wallpapers/"* "${BUILD_DIR}/usr/share/backgrounds/apexos/" 2>/dev/null || true
fi
if [ -d "${WORKSPACE_ROOT}/themes/gtk-3.0" ]; then
    cp -r "${WORKSPACE_ROOT}/themes/gtk-3.0" "${BUILD_DIR}/usr/share/themes/ApexOS-Dark/" 2>/dev/null || true
fi
if [ -d "${WORKSPACE_ROOT}/scripts" ]; then
    cp "${WORKSPACE_ROOT}/scripts/"*.sh "${BUILD_DIR}/usr/local/bin/" 2>/dev/null || true
    cp "${WORKSPACE_ROOT}/scripts/"*.py "${BUILD_DIR}/usr/local/bin/" 2>/dev/null || true
    chmod +x "${BUILD_DIR}/usr/local/bin/"* 2>/dev/null || true
fi

# Extract Kernel and Initrd
VMLINUZ=$(ls -1 "${BUILD_DIR}/boot/vmlinuz-"* | tail -n1)
INITRD=$(ls -1 "${BUILD_DIR}/boot/initrd.img-"* | tail -n1)
cp "${VMLINUZ}" "${ISO_DIR}/casper/vmlinuz"
cp "${INITRD}" "${ISO_DIR}/casper/initrd"

# 6. Unmount virtual filesystems BEFORE mksquashfs
unmount_chroot
trap - EXIT
rm -f "${BUILD_DIR}/etc/resolv.conf"

echo "==> [Stage 6/7] Generating compressed squashfs filesystem..."
mksquashfs "${BUILD_DIR}" "${ISO_DIR}/casper/filesystem.squashfs" \
    -comp zstd -Xcompression-level 3 -noappend \
    -e proc sys dev run tmp mnt media

# 7. Package ISO with 'rw' live mode
echo "==> [Stage 7/7] Generating bootable hybrid ISO..."
cat << 'EOF' > "${ISO_DIR}/boot/grub/grub.cfg"
set default="0"
set timeout=5

menuentry "Start ApexOS 1.0 (Standard Edition)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper username=apex hostname=apexos rw systemd.show_status=1 ---
    initrd /casper/initrd
}

menuentry "Start ApexOS 1.0 (Safe Graphics Mode)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper username=apex hostname=apexos rw nomodeset systemd.show_status=1 ---
    initrd /casper/initrd
}
EOF

grub-mkrescue -o "${OUTPUT_DIR}/${ISO_NAME}" "${ISO_DIR}" \
    -- -volid "ApexOS_1_0_Std" 2>/dev/null || \
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "ApexOS_1_0_Std" \
    -output "${OUTPUT_DIR}/${ISO_NAME}" \
    "${ISO_DIR}"

rm -rf "${WORK_DIR}"

echo "======================================================================"
echo "  Standard Edition ISO Build Complete!"
echo "  Output: ${OUTPUT_DIR}/${ISO_NAME}"
echo "======================================================================"
