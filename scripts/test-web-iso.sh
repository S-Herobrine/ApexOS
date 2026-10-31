#!/bin/bash
# ==============================================================================
# ApexOS Cloud ISO Web Runner
# Runs inside GitHub Codespaces (100% in your browser - zero local download)
# ==============================================================================

set -euo pipefail

echo "=========================================================="
echo "    ApexOS Cloud ISO Browser Runner (Zero Local Download)"
echo "=========================================================="

# 1. Install QEMU and noVNC web viewer
sudo apt-get update -qq
sudo apt-get install -y -qq qemu-system-x86 novnc websockify curl gh

# Make sure novnc index opens directly
sudo ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html 2>/dev/null || true

# 2. Locate built ISO or download from GitHub Actions
ISO_PATH=$(find build/output /tmp -name "ApexOS-*.iso" 2>/dev/null | head -n1 || true)

if [ -z "${ISO_PATH}" ]; then
    echo "==> Fetching latest built ISO from GitHub Artifacts..."
    mkdir -p /tmp/iso-download
    gh run download -R S-Herobrine/ApexOS --name ApexOS-1.0-LowEnd-amd64-iso --dir /tmp/iso-download || true
    ISO_PATH=$(find /tmp/iso-download -name "*.iso" 2>/dev/null | head -n1 || true)
fi

if [ -z "${ISO_PATH}" ]; then
    echo "==> No pre-built ISO found. Building Low-End ISO now in cloud..."
    sudo bash build/build-iso-lowend.sh
    ISO_PATH=$(find build/output -name "ApexOS-*.iso" | head -n1)
fi

echo "==> Booting ISO: ${ISO_PATH}"

# 3. Create a 10GB virtual drive for test installation
qemu-img create -f qcow2 /tmp/apexos-virtual-drive.qcow2 10G

# 4. Start web display bridge (noVNC on port 6080)
echo "==> Starting web display on port 6080..."
websockify -D --web=/usr/share/novnc/ 6080 localhost:5900

echo "=========================================================="
echo "  APEXOS ISO IS NOW RUNNING!"
echo "  Click the 'Open in Browser' pop-up in Codespaces (Port 6080)"
echo "=========================================================="

# 5. Boot QEMU virtual machine
qemu-system-x86_64 \
    -m 3072 \
    -smp 2 \
    -vga virtio \
    -vnc :0 \
    -cdrom "${ISO_PATH}" \
    -hda /tmp/apexos-virtual-drive.qcow2 \
    -boot d
