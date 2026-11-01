#!/bin/bash
# ==============================================================================
# ApexOS Cloud ISO Web Runner
# Runs inside GitHub Codespaces (100% in your browser - zero local download)
# ==============================================================================

set -euo pipefail

echo "=========================================================="
echo "    ApexOS Cloud ISO Browser Runner (Zero Local Download)"
echo "=========================================================="

EDITION="${1:-}"

if [ -z "$EDITION" ]; then
    echo "There are 2 ISO editions available. Which one do you want to test?"
    echo "  1) ApexOS Standard Edition (Full App Suite - Recommended)"
    echo "  2) ApexOS Low-End Edition (< 2GB, 4GB RAM optimized)"
    read -rp "Enter choice [1 or 2, default is 1]: " CHOICE
    if [ "$CHOICE" = "2" ] || [ "$CHOICE" = "lowend" ]; then
        EDITION="lowend"
    else
        EDITION="standard"
    fi
fi

if [ "$EDITION" = "standard" ] || [ "$EDITION" = "1" ]; then
    ARTIFACT_NAME="ApexOS-1.0-Standard-amd64-iso"
    ISO_PATTERN="*Standard*.iso"
    EDITION="standard"
    echo "==> Selected: ApexOS Standard Edition"
else
    ARTIFACT_NAME="ApexOS-1.0-LowEnd-amd64-iso"
    ISO_PATTERN="*LowEnd*.iso"
    EDITION="lowend"
    echo "==> Selected: ApexOS Low-End Edition"
fi

# 1. Install QEMU and noVNC web viewer
sudo apt-get update -qq
sudo apt-get install -y -qq qemu-system-x86 novnc websockify curl gh

sudo ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html 2>/dev/null || true

# 2. Clean old downloaded ISOs to ensure latest build is fetched
rm -rf "/tmp/iso-download/${EDITION}"
mkdir -p "/tmp/iso-download/${EDITION}"

# 3. Fetch latest built ISO from GitHub Actions
echo "==> Downloading latest ${ARTIFACT_NAME} from GitHub Actions..."
gh run download -R S-Herobrine/ApexOS --name "${ARTIFACT_NAME}" --dir "/tmp/iso-download/${EDITION}"

ISO_PATH=$(find "/tmp/iso-download/${EDITION}" -name "*.iso" | head -n1)

if [ -z "${ISO_PATH}" ]; then
    echo "Error: Could not locate downloaded ISO."
    exit 1
fi

echo "==> Successfully downloaded: ${ISO_PATH}"
ls -lh "${ISO_PATH}"

# 4. Clean up any existing instances on ports 6080 and 5900
sudo fuser -k 6080/tcp 5900/tcp 2>/dev/null || true
pkill -9 -f websockify 2>/dev/null || true
pkill -9 -f qemu-system-x86 2>/dev/null || true
sleep 1

# 5. Start noVNC web bridge with explicit IPv4 binding (127.0.0.1:5900)
echo "==> Starting web display bridge on port 6080..."
websockify -D --web=/usr/share/novnc/ 6080 127.0.0.1:5900

# 6. Check CPU virtualization support
CPU_FLAGS="-cpu max"
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    CPU_FLAGS="-enable-kvm -cpu host"
    echo "==> Hardware KVM acceleration enabled!"
else
    echo "==> Emulating modern x86_64 CPU with -cpu max..."
fi

# 7. Create virtual drive for installer testing
rm -f /tmp/apexos-virtual-drive.qcow2
qemu-img create -f qcow2 /tmp/apexos-virtual-drive.qcow2 10G

echo "=========================================================="
echo "  APEXOS ${EDITION^^} IS STARTING!"
echo "  Open Port 6080 in your browser to view the screen."
echo "=========================================================="

# 8. Launch QEMU with safe 2048MB memory allocation (prevents Codespaces OOM crash)
# Explicit 127.0.0.1:0 ensures matching IPv4 VNC port
exec qemu-system-x86_64 \
    ${CPU_FLAGS} \
    -m 2048 \
    -smp 2 \
    -vga std \
    -device usb-tablet \
    -vnc 127.0.0.1:0 \
    -cdrom "${ISO_PATH}" \
    -hda /tmp/apexos-virtual-drive.qcow2 \
    -boot d
