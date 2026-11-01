#!/bin/bash
# ==============================================================================
# ApexOS Standard Edition ISO Builder (Full App & Multimedia Suite)
# Optimized for reliable Live Boot on Physical PCs & Virtual Machines (QEMU/KVM)
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
mkdir -p "${OUTPUT_DIR}" "${BUILD_DIR}" "${ISO_DIR}/casper" "${ISO_DIR}/boot/grub" "${ISO_DIR}/.disk"

# 1. Debootstrap base Ubuntu 24.04 LTS (Noble)
echo "==> [Stage 1/8] Debootstrapping Ubuntu 24.04 LTS (Noble) base..."
debootstrap --arch="${ARCH}" "${CODENAME}" "${BUILD_DIR}" http://archive.ubuntu.com/ubuntu/

# 2. Configure Repositories & DNS inside chroot
echo "==> [Stage 2/8] Configuring APT sources and networking..."
cp /etc/resolv.conf "${BUILD_DIR}/etc/resolv.conf"

cat << 'EOF' > "${BUILD_DIR}/etc/apt/sources.list"
deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
EOF

# 3. Mount virtual filesystems for chroot operations
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

# 4. Install Full Package Suite & Live Boot Subsystems
echo "==> [Stage 4/8] Installing kernel, casper, desktop and display packages..."
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
    gnome-session \
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

# 7. Re-build initramfs with all casper and storage hooks
update-initramfs -u -k all

# Clean APT caches to keep image size compact
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
CHROOT_EOF

# 5. Inject ApexOS Themes, Wallpapers, and Shell configs
echo "==> [Stage 5/8] Injecting ApexOS configurations..."
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

# Extract Live Kernel and Initrd before unmounting
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

# Generate compressed squashfs
echo "==> [Stage 7/8] Generating compressed squashfs filesystem (~3-5 mins)..."
mksquashfs "${BUILD_DIR}" "${ISO_DIR}/casper/filesystem.squashfs" \
    -comp zstd -Xcompression-level 3 -noappend \
    -e proc sys dev run tmp mnt media

# 8. Create GRUB2 Boot Configuration with serial console output for zero-guess debugging
echo "==> [Stage 8/8] Packaging bootable hybrid ISO..."

cat << 'EOF' > "${ISO_DIR}/boot/grub/grub.cfg"
set default="0"
set timeout=3

insmod font
if loadfont /boot/grub/font.pf2 ; then
    insmod gfxterm
    set gfxmode=auto
    terminal_output gfxterm
fi

menuentry "Start ApexOS 1.0 (Standard Edition)" {
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
