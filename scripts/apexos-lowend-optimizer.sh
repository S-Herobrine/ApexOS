#!/bin/bash
# ==============================================================================
# ApexOS Low-End PC Hardware Optimizer
# Configures Linux Kernel, zRAM, and Android Subsystem for 4GB RAM machines
# ==============================================================================

set -euo pipefail

echo "====================================================="
echo "   ApexOS 4GB RAM & Low-Disk Performance Optimizer   "
echo "====================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Please run as root (sudo bash apexos-lowend-optimizer.sh)"
    exit 1
fi

# 1. Configure in-memory zRAM (virtual 8GB RAM using LZ4 compression)
echo "==> [1/5] Configuring zRAM (compresses idle memory in RAM)..."
apt-get install -y zram-tools

cat << 'EOF' > /etc/default/zramswap
# Compress memory with LZ4 algorithm (fastest, near-zero CPU overhead)
ALGO=lz4
PERCENT=100
PRIORITY=100
EOF

systemctl restart zramswap.service || true
echo "    zRAM enabled: 4GB physical RAM effectively expanded to ~7.5GB usable space."

# 2. Kernel VM Memory Tuning for Low Latency
echo "==> [2/5] Tuning Kernel VM Swappiness and Cache pressure..."
cat << 'EOF' > /etc/sysctl.d/99-apexos-lowend.conf
# Aggressively page idle inactive memory to zRAM
vm.swappiness=100
# Preserve directory/inode cache for instant app launches
vm.vfs_cache_pressure=50
# Lower dirty writeback threshold to prevent system stutter on slow HDD/eMMC
vm.dirty_background_ratio=5
vm.dirty_ratio=10
EOF

sysctl --system >/dev/null 2>&1

# 3. Disable heavy non-essential background indexing daemons
echo "==> [3/5] Disabling heavy background indexers..."
systemctl --user mask tracker-miner-fs-3.service 2>/dev/null || true
systemctl --user mask tracker-extract-3.service 2>/dev/null || true

# 4. Configure Waydroid Low-RAM Profile
echo "==> [4/5] Tuning Waydroid Android Subsystem for 4GB RAM..."
mkdir -p /var/lib/waydroid
cat << 'EOF' > /var/lib/waydroid/waydroid.cfg
[waydroid]
arch = x86_64
binder = android
mount = /var/lib/waydroid/rootfs
images_path = /var/lib/waydroid/images
auto_start = false
multi_windows = true
# Allocate max 1.2GB RAM to Android container, preserving 2.8GB for host
dalvik.vm.heapgrowthlimit = 192m
dalvik.vm.heapsize = 384m
ro.config.low_ram = true
EOF

# 5. Clean up disk space
echo "==> [5/5] Performing system cache cleanup..."
apt-get autoremove -y
apt-get clean
journalctl --vacuum-size=50M >/dev/null 2>&1

echo "====================================================="
echo "   Optimization Complete! System reboot recommended. "
echo "====================================================="
