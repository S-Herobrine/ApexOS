#!/bin/bash
set -euo pipefail

echo "==> [04/05] SatasOS: Applying themes, icons, Plymouth boot splash & branding..."

# Copy themes to system
mkdir -p /usr/share/themes/SatasOS-Dark
mkdir -p /usr/share/themes/SatasOS-Light
mkdir -p /usr/share/icons/SatasOS-Icons
mkdir -p /usr/share/backgrounds/satasos
mkdir -p /usr/share/plymouth/themes/satasos
mkdir -p /boot/grub/themes/satasos

# Set default Plymouth theme
if [ -d /usr/share/plymouth/themes/satasos ]; then
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/satasos/satasos.plymouth 100 || true
    update-alternatives --set default.plymouth /usr/share/plymouth/themes/satasos/satasos.plymouth || true
fi

# Set default GNOME dconf profile for SatasOS
mkdir -p /etc/dconf/db/local.d
cat << 'EOF' > /etc/dconf/db/local.d/01-satasos
[org/gnome/desktop/interface]
gtk-theme='SatasOS-Dark'
icon-theme='SatasOS-Icons'
cursor-theme='SatasOS-Cursors'
font-name='Inter 11'
monospace-font-name='JetBrains Mono 10'
color-scheme='prefer-dark'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/satasos/satasos-default-dark.svg'
picture-uri-dark='file:///usr/share/backgrounds/satasos/satasos-default-dark.svg'
primary-color='#1E1B2E'

[org/gnome/shell]
favorite-apps=['satasos-files.desktop', 'google-chrome.desktop', 'firefox.desktop', 'org.gnome.Terminal.desktop', 'satasos-android-manager.desktop', 'satasos-settings.desktop']
enabled-extensions=['satasos-shell@satasos.org']
EOF

dconf update || true

echo "==> Branding applied successfully."
