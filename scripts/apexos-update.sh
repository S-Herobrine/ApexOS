#!/bin/bash
# ==============================================================================
# ApexOS Universal System Updater
# Updates APT packages, Snaps, Flatpaks, and Waydroid Android subsystem
# ==============================================================================

set -euo pipefail

echo "=========================================================="
echo "               ApexOS System Updater                      "
echo "=========================================================="

echo "==> [1/4] Updating Ubuntu/ApexOS APT packages..."
sudo apt update && sudo apt upgrade -y

echo "==> [2/4] Refreshing Snap applications..."
which snap >/dev/null 2>&1 && sudo snap refresh || true

echo "==> [3/4] Updating Flatpak packages..."
which flatpak >/dev/null 2>&1 && flatpak update -y || true

echo "==> [4/4] Updating Waydroid Android Subsystem..."
which waydroid >/dev/null 2>&1 && sudo waydroid upgrade || true

echo "==> Cleaning unneeded package dependencies..."
sudo apt autoremove -y && sudo apt clean

echo "=========================================================="
echo "         ApexOS is fully up-to-date!                      "
echo "=========================================================="
