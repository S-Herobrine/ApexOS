#!/bin/bash
set -euo pipefail

echo "==> [03/05] SatasOS: Configuring Waydroid container & Android integration..."

systemctl enable waydroid-container.service || true

# Pre-create config paths
mkdir -p /var/lib/waydroid
mkdir -p /etc/waydroid

if [ -f /etc/satasos/android/waydroid.cfg ]; then
    cp /etc/satasos/android/waydroid.cfg /var/lib/waydroid/waydroid.cfg || true
fi

echo "==> Waydroid service prepared."
