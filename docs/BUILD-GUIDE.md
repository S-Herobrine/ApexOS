# SatasOS ISO Build Guide

This document describes how to build the bootable **SatasOS** installation ISO image from source.

---

## 1. System Requirements

To build the SatasOS ISO, you need an Ubuntu or Debian-based Linux environment (physical machine, dual-boot, or KVM/VMware virtual machine).

- **Host OS**: Ubuntu 22.04 LTS, Ubuntu 24.04 LTS, or Debian 12
- **CPU**: 4 cores or higher (x86_64 architecture)
- **RAM**: Minimum 8 GB (16 GB recommended for faster squashfs compression)
- **Disk Space**: At least 50 GB free disk space on an ext4/btrfs filesystem
- **Network**: Fast internet connection (downloads base Ubuntu packages, kernel, browsers, and Android images)

---

## 2. Installing Build Dependencies

Run the following commands on your host Linux machine to prepare the build environment:

```bash
sudo apt update
sudo apt install -y \
    live-build \
    debootstrap \
    xorriso \
    squashfs-tools \
    mtools \
    dosfstools \
    grub-pc-bin \
    grub-efi-amd64-bin \
    isolinux \
    syslinux-utils \
    git \
    make \
    curl \
    wget \
    gnupg \
    coreutils
```

---

## 3. Cloning & Repository Setup

Clone or copy the SatasOS repository to your workspace:

```bash
cd ~
git clone https://github.com/SatasOS/SatasOS.git satasos
cd satasos
```

Ensure build scripts have executable permissions:

```bash
chmod +x build/build-iso.sh
chmod +x build/chroot-setup.sh
chmod +x build/hooks/*.sh
chmod +x android/*.sh
chmod +x scripts/*.sh
```

---

## 4. Building the ISO

### Option A: Using the Automated Makefile

```bash
# Build complete ISO
sudo make build-iso

# Or clean and rebuild
sudo make clean
sudo make build-iso
```

### Option B: Running the Build Script Directly

```bash
sudo bash build/build-iso.sh
```

The build script will execute the following stages:
1. **Config Validation**: Checks for required dependencies and directories.
2. **Debootstrap Base**: Bootstraps Ubuntu 24.04 (Noble) base packages.
3. **Repository Injection**: Configures official Ubuntu mirrors and external software repositories (Google Chrome, Microsoft Edge, Opera, Waydroid, VS Code).
4. **Chroot Customization**:
   - Installs desktop environments, GNOME Shell, PipeWire, Mesa 3D drivers.
   - Installs pre-selected web browsers, multimedia tools, and office suites.
   - Configures Waydroid, Android LXC containers, and Google Play Services integration.
   - Applies the SatasOS custom purple theme, icons, wallpapers, Plymouth boot splash, and GRUB theme.
5. **Calamares Installer Configuration**: Embeds the graphical installer with custom branding and multi-browser selection.
6. **Kernel & Initramfs Generation**: Builds the live kernel initramfs with overlayfs and casper support.
7. **Squashfs Compression**: Compresses the chroot filesystem with high-efficiency `xz` or `zstd` compression.
8. **ISO Generation**: Packages the EFI and BIOS bootable ISO image with `xorriso`.

The output ISO will be saved as:
```
build/output/SatasOS-1.0-amd64.iso
```

---

## 5. Testing the ISO in a Virtual Machine (QEMU / KVM)

You can immediately test the generated ISO without burning it to physical media:

```bash
# Create a 30GB virtual disk
qemu-img create -f qcow2 satasos-test.qcow2 30G

# Boot with UEFI, 8GB RAM, 4 CPU cores, and 3D acceleration
qemu-system-x86_64 \
    -enable-kvm \
    -m 8192 \
    -smp 4 \
    -cpu host \
    -vga virtio \
    -display gtk,gl=on \
    -bios /usr/share/ovmf/OVMF.fd \
    -cdrom build/output/SatasOS-1.0-amd64.iso \
    -hda satasos-test.qcow2 \
    -boot d
```

---

## 6. Creating a Bootable USB Drive

Once verified, write the ISO to a physical USB thumb drive (8 GB or larger):

### On Linux:
```bash
# Identify your USB drive (e.g., /dev/sdb)
lsblk

# Write ISO directly (replace /dev/sdX with your actual USB device, NOT a partition like /dev/sdX1)
sudo dd if=build/output/SatasOS-1.0-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

### On Windows:
- Use **Rufus** (https://rufus.ie):
  - Select your USB Drive.
  - Choose `SatasOS-1.0-amd64.iso`.
  - Partition scheme: `GPT` or `MBR`.
  - Target system: `UEFI (non CSM)`.
  - Write mode: `ISO Image mode` or `DD Image mode`.

---

## 7. Troubleshooting

- **Out of disk space during build**:
  Make sure `/tmp` or the build partition has at least 50 GB free space. You can redirect the temporary build directory by setting `export TMPDIR=/path/to/large/drive`.
- **GPG Key errors during package fetching**:
  Check `build/hooks/01-setup-repos.sh` to ensure network access is unrestricted and proxy configurations (if any) are exported.
- **Waydroid fails inside VM**:
  Waydroid requires hardware graphics acceleration or software Mesa llvmpipe. Ensure KVM hardware virtualization (`-enable-kvm`) is enabled in your VM settings.
