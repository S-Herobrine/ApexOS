#!/bin/bash
set -euo pipefail

echo "==> [01/05] SatasOS: Setting up external repositories and GPG keys..."

export DEBIAN_FRONTEND=noninteractive

apt update
apt install -y curl wget gnupg ca-certificates lsb-release

# Google Chrome Key
if [ ! -f /etc/apt/trusted.gpg.d/google.gpg ]; then
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/trusted.gpg.d/google.gpg
fi

# Microsoft Edge & VS Code Key
if [ ! -f /etc/apt/trusted.gpg.d/microsoft.gpg ]; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg
fi

# Opera Browser Key
if [ ! -f /etc/apt/trusted.gpg.d/opera.gpg ]; then
    curl -fsSL https://deb.opera.com/archive.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/opera.gpg
fi

# Waydroid Key
if [ ! -f /usr/share/keyrings/waydroid.gpg ]; then
    curl -fsSL https://repo.waydro.id/waydroid.gpg | gpg --dearmor -o /usr/share/keyrings/waydroid.gpg
fi

echo "==> Repositories and keys configured successfully."
