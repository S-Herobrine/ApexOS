#!/bin/bash
# ==============================================================================
# ApexOS Automated System Diagnostics & Repair Tool
# Fixes broken packages, restores desktop settings, and restarts Waydroid/PipeWire
# ==============================================================================

set -euo pipefail

echo "=========================================================="
echo "          ApexOS Diagnostics & Repair Wizard             "
echo "=========================================================="

echo "==> [1/5] Fixing interrupted package installations..."
sudo dpkg --configure -a
sudo apt --fix-broken install -y

echo "==> [2/5] Resetting PipeWire and Audio routing..."
systemctl --user restart pipewire pipewire-pulse wireplumber || true

echo "==> [3/5] Re-enabling ApexOS GNOME Shell Extensions..."
gnome-extensions enable satasos-shell@satasos.org 2>/dev/null || true

echo "==> [4/5] Repairing Waydroid Android Container..."
sudo systemctl restart waydroid-container || true

echo "==> [5/5] Re-applying low-end RAM optimizations..."
sudo sysctl --system >/dev/null 2>&1 || true

echo "=========================================================="
echo "           ApexOS Repair Process Completed!              "
echo "=========================================================="
