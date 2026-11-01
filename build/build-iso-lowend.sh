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
WORK_DIR="/tmp/apexos-build-lowend"
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
mkdir -p "${OUTPUT_DIR}" "${BUILD_DIR}" "${ISO_DIR}/casper" "${ISO_DIR}/boot/grub" "${ISO_DIR}/.disk"

# 1. Debootstrap base Ubuntu 24.04 LTS (Noble)
echo "==> [Stage 1/8] Debootstrapping Ubuntu minimal base..."
debootstrap --arch="${ARCH}" "${CODENAME}" "${BUILD_DIR}" http://archive.ubuntu.com/ubuntu/

# 2. Configure Repositories & DNS inside chroot
echo "==> [Stage 2/8] Configuring APT sources and networking..."
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
echo "==> [Stage 3/8] Mounting chroot virtual filesystems..."
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
echo "==> [Stage 4/8] Installing kernel, casper, and desktop packages..."
chroot "${BUILD_DIR}" /bin/bash << 'CHROOT_EOF'
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

apt-get update
apt-get install -y --no-install-recommends \
    linux-generic \
    casper \
    user-setup \
    discover \
    laptop-detect \
    os-prober \
    systemd-sysv \
    systemd \
    dbus \
    dbus-x11 \
    libpam-systemd \
    polkitd \
    accountsservice \
    network-manager \
    locales \
    sudo \
    xorg \
    xserver-xorg-video-all \
    xserver-xorg-input-all \
    zram-tools \
    mutter \
    gnome-session \
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

# 1. Configure initramfs-tools explicitly for Casper Live Boot and generic hardware
mkdir -p /etc/initramfs-tools
touch /etc/initramfs-tools/initramfs.conf
grep -q '^BOOT=' /etc/initramfs-tools/initramfs.conf && sed -i 's/^BOOT=.*/BOOT=casper/' /etc/initramfs-tools/initramfs.conf || echo 'BOOT=casper' >> /etc/initramfs-tools/initramfs.conf
grep -q '^MODULES=' /etc/initramfs-tools/initramfs.conf && sed -i 's/^MODULES=.*/MODULES=most/' /etc/initramfs-tools/initramfs.conf || echo 'MODULES=most' >> /etc/initramfs-tools/initramfs.conf

# Configure casper user & host identity
mkdir -p /etc/casper.conf.d
cat << 'CASPER_EOF' > /etc/casper.conf
export USERNAME="apex"
export USERFULLNAME="ApexOS User"
export HOST="apexos"
export BUILD_SYSTEM="Ubuntu"
export FLAVOUR="ApexOS"
CASPER_EOF

# 2. Add all storage, CD-ROM, and virtualization drivers to initramfs
cat << 'MOD_EOF' >> /etc/initramfs-tools/modules
sr_mod
cdrom
ata_piix
ahci
sd_mod
virtio_blk
virtio_pci
overlay
squashfs
isofs
loop
MOD_EOF

# 3. Initialize machine-id (critical: prevents systemd PID 1 exit failure)
systemd-machine-id-setup
dbus-uuidgen --ensure=/etc/machine-id

# 4. Configure default locale and hostname
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
echo "apexos" > /etc/hostname

# 5. Pre-create live user 'apex' with password 'apex' and passwordless sudo
if ! id -u apex &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,adm,audio,video,plugdev,netdev,cdrom,dip apex
    echo "apex:apex" | chpasswd
    echo "root:apexos" | chpasswd
    mkdir -p /etc/sudoers.d
    echo "apex ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/apex
    chmod 0440 /etc/sudoers.d/apex
fi

# 6. Configure GDM3 autologin with X11 fallback (prevents Wayland black-screen in QEMU/VMs)
mkdir -p /etc/gdm3
cat << 'GDM_EOF' > /etc/gdm3/custom.conf
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=apex
TimedLoginEnable=true
TimedLogin=apex
TimedLoginDelay=0
WaylandEnable=false
GDM_EOF

# Enable zram
systemctl enable zramswap.service || true

# 7. Update initramfs with casper live hooks
update-initramfs -u -k all

# Clean APT caches to keep image small
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
CHROOT_EOF

# 5. Inject ApexOS Themes, Wallpapers, and Shell configs
echo "==> [Stage 5/8] Injecting ApexOS desktop customizations..."
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

# 6. Unmount virtual filesystems BEFORE mksquashfs!
unmount_chroot
trap - EXIT
rm -f "${BUILD_DIR}/etc/resolv.conf"

# 7. Write Casper identification files (.disk/info, filesystem.size)
echo "==> [Stage 6/8] Writing Casper Live CD identification markers..."
echo "ApexOS 1.0 (Noble Numbat) - Release amd64" > "${ISO_DIR}/.disk/info"
touch "${ISO_DIR}/.disk/base_installable"
echo "full_cd/single" > "${ISO_DIR}/.disk/cd_type"

# Write filesystem uncompressed size for casper overlay RAM calculation
printf $(du -sx --block-size=1 "${BUILD_DIR}" | cut -f1) > "${ISO_DIR}/casper/filesystem.size"

# Generate Squashfs with fast zstd compression (Level 3 for fast build)
echo "==> [Stage 7/8] Creating compressed squashfs filesystem (~3-5 mins)..."
mksquashfs "${BUILD_DIR}" "${ISO_DIR}/casper/filesystem.squashfs" \
    -comp zstd -Xcompression-level 3 -noappend \
    -e proc sys dev run tmp mnt media

# 8. Create GRUB2 Boot Configuration with serial console logging
echo "==> [Stage 8/8] Packaging Bootable Hybrid ISO image..."

cat << 'EOF' > "${ISO_DIR}/boot/grub/grub.cfg"
set default="0"
set timeout=3

insmod font
if loadfont /boot/grub/font.pf2 ; then
    insmod gfxterm
    set gfxmode=auto
    terminal_output gfxterm
fi

menuentry "Start ApexOS 1.0 (Low-End Edition - 4GB RAM)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper username=apex hostname=apexos rw ignore_uuid noprompt console=tty0 console=ttyS0 systemd.show_status=1 ---
    initrd /casper/initrd
}

menuentry "Start ApexOS 1.0 (Safe Graphics / Compatibility Mode)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper username=apex hostname=apexos rw ignore_uuid nomodeset noprompt console=tty0 console=ttyS0 systemd.show_status=1 ---
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

rm -rf "${WORK_DIR}"

echo "======================================================================"
echo "  SUCCESS! ApexOS Low-End ISO generated."
echo "  ISO Path: ${OUTPUT_DIR}/${ISO_NAME}"
echo "======================================================================"
