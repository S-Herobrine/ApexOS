#!/bin/bash
# ==============================================================================
# ApexOS Cloud ISO Web Runner
# Runs inside GitHub Codespaces (100% in your browser - zero local download)
# ==============================================================================

set -euo pipefail

echo "=========================================================="
echo "    ApexOS Cloud ISO Browser Runner (Zero Local Download)"
echo "=========================================================="

# 1. Ask which ISO to test if not passed as an argument
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
    RAM_ALLOC=4096
    EDITION="standard"
    echo "==> Selected: ApexOS Standard Edition"
else
    ARTIFACT_NAME="ApexOS-1.0-LowEnd-amd64-iso"
    ISO_PATTERN="*LowEnd*.iso"
    RAM_ALLOC=3072
    EDITION="lowend"
    echo "==> Selected: ApexOS Low-End Edition"
fi

# 2. Install QEMU and noVNC web viewer
sudo apt-get update -qq
sudo apt-get install -y -qq qemu-system-x86 novnc websockify curl gh

sudo ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html 2>/dev/null || true

# 3. Clean any old cached ISOs from /tmp so we always run the newest build
echo "==> Cleaning old cached ISOs..."
rm -rf "/tmp/iso-download/${EDITION}"
mkdir -p "/tmp/iso-download/${EDITION}"

# 4. Fetch the latest successfully built ISO from GitHub Actions
echo "==> Fetching latest ${ARTIFACT_NAME} from GitHub Actions..."
gh run download -R S-Herobrine/ApexOS --name "${ARTIFACT_NAME}" --dir "/tmp/iso-download/${EDITION}"

ISO_PATH=$(find "/tmp/iso-download/${EDITION}" -name "*.iso" | head -n1)

if [ -z "${ISO_PATH}" ]; then
    echo "Error: Could not locate downloaded ISO."
    exit 1
fi

echo "==> Successfully downloaded: ${ISO_PATH}"
ls -lh "${ISO_PATH}"

# 5. Create a 10GB virtual hard drive for testing the installation
qemu-img create -f qcow2 /tmp/apexos-test-disk.qcow2 10G 2>/dev/null || true

# 6. Kill any existing instances on ports 6080 and 5900
sudo fuser -k 6080/tcp 5900/tcp 2>/dev/null || true
pkill -f websockify 2>/dev/null || true
pkill -f qemu-system-x86 2>/dev/null || true
sleep 1

# 7. Start noVNC web server on port 6080
echo "==> Starting web display on port 6080..."
websockify -D --web=/usr/share/novnc/ 6080 localhost:5900

# 8. Check CPU virtualization support
CPU_FLAGS="-cpu max"
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    CPU_FLAGS="-enable-kvm -cpu host"
    echo "==> Hardware KVM acceleration enabled!"
else
    echo "==> Emulating modern x86_64 CPU with -cpu max..."
fi

echo "=========================================================="
echo "  APEXOS ${EDITION^^} IS NOW BOOTING!"
echo "  Open Port 6080 in your browser to view the screen."
echo "=========================================================="

# 9. Launch QEMU virtual machine
qemu-system-x86_64 \
    ${CPU_FLAGS} \
    -m "${RAM_ALLOC}" \
    -smp 2 \
    -vga virtio \
    -vnc :0 \
    -cdrom "${ISO_PATH}" \
    -hda /tmp/apexos-test-disk.qcow2 \
    -boot d
