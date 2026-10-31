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
    echo "  1) ApexOS Low-End Edition (< 2GB, 4GB RAM optimized)"
    echo "  2) ApexOS Standard Edition (Full App & Multimedia Suite)"
    read -rp "Enter choice [1 or 2, default is 1]: " CHOICE
    if [ "$CHOICE" = "2" ] || [ "$CHOICE" = "standard" ]; then
        EDITION="standard"
    else
        EDITION="lowend"
    fi
fi

if [ "$EDITION" = "standard" ] || [ "$EDITION" = "2" ]; then
    ARTIFACT_NAME="ApexOS-1.0-Standard-amd64-iso"
    ISO_PATTERN="*Standard*.iso"
    RAM_ALLOC=4096
    echo "==> Selected: ApexOS Standard Edition"
else
    ARTIFACT_NAME="ApexOS-1.0-LowEnd-amd64-iso"
    ISO_PATTERN="*LowEnd*.iso"
    RAM_ALLOC=3072
    echo "==> Selected: ApexOS Low-End Edition"
fi

# 2. Install QEMU and noVNC web viewer
sudo apt-get update -qq
sudo apt-get install -y -qq qemu-system-x86 novnc websockify curl gh

sudo ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html 2>/dev/null || true

# 3. Locate built ISO or fetch from GitHub Actions
ISO_PATH=$(find build/output /tmp -name "${ISO_PATTERN}" 2>/dev/null | head -n1 || true)

if [ -z "${ISO_PATH}" ]; then
    echo "==> Fetching ${ARTIFACT_NAME} from GitHub Artifacts..."
    mkdir -p "/tmp/iso-download/${EDITION}"
    gh run download -R S-Herobrine/ApexOS --name "${ARTIFACT_NAME}" --dir "/tmp/iso-download/${EDITION}" || true
    ISO_PATH=$(find "/tmp/iso-download/${EDITION}" -name "*.iso" 2>/dev/null | head -n1 || true)
fi

if [ -z "${ISO_PATH}" ]; then
    echo "==> Building ${EDITION} ISO now in cloud container..."
    if [ "$EDITION" = "standard" ]; then
        sudo bash build/build-iso-standard.sh
    else
        sudo bash build/build-iso-lowend.sh
    fi
    ISO_PATH=$(find build/output -name "${ISO_PATTERN}" | head -n1)
fi

echo "==> Booting ISO: ${ISO_PATH}"

# 4. Create a 10GB virtual hard drive for testing the installation
qemu-img create -f qcow2 /tmp/apexos-test-disk.qcow2 10G 2>/dev/null || true

# 5. Start noVNC web server on port 6080
echo "==> Starting web display on port 6080..."
websockify -D --web=/usr/share/novnc/ 6080 localhost:5900 2>/dev/null || true

echo "=========================================================="
echo "  ${EDITION^^} ISO IS NOW BOOTING!"
echo "  Click the 'Open in Browser' pop-up in Codespaces (Port 6080)"
echo "=========================================================="

# 6. Launch QEMU with VNC display
qemu-system-x86_64 \
    -m "${RAM_ALLOC}" \
    -smp 2 \
    -vga virtio \
    -vnc :0 \
    -cdrom "${ISO_PATH}" \
    -hda /tmp/apexos-test-disk.qcow2 \
    -boot d
