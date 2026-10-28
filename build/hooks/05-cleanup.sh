#!/bin/bash
set -euo pipefail

echo "==> [05/05] SatasOS: Cleaning package caches and temporary files..."

export DEBIAN_FRONTEND=noninteractive

apt clean
apt autoclean
apt autoremove -y

rm -rf /tmp/* /var/tmp/*
rm -rf /var/lib/apt/lists/*
rm -f /etc/resolv.conf
ln -s ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf || true

echo "==> Cleanup complete. Ready for ISO image generation."
