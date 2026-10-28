#!/bin/bash
# ==============================================================================
# ApexOS First-Run Welcome Experience & Setup
# ==============================================================================

set -euo pipefail

MARKER="${HOME}/.config/apexos-firstrun-completed"

# Check if autostart and already completed
if [ "${1:-}" = "--autostart" ] && [ -f "$MARKER" ]; then
    exit 0
fi

if which zenity >/dev/null 2>&1; then
    zenity --info \
        --title="Welcome to ApexOS!" \
        --width=450 \
        --text="<b>Welcome to ApexOS 1.0!</b>\n\nExperience the power of Ubuntu Linux, the intuitive familiarity of Windows 11, and the mobile agility of Android 14.\n\n<b>Quick Tips:</b>\n• <b>Super</b>: Open Windows-style Start Menu\n• <b>Super+A</b>: Open Android App Drawer\n• <b>Super+E</b>: Open ApexOS Files Explorer\n• <b>Super+N</b>: Open Android Quick Settings Shade"

    # Offer to optimize for low-end PC
    if zenity --question --title="Performance Optimization" --text="Would you like to enable the 4GB RAM Low-End PC Performance Profile (zRAM memory compression)?"; then
        sudo /usr/local/bin/apexos-lowend-optimizer.sh 2>/dev/null || true
    fi
fi

mkdir -p "$(dirname "$MARKER")"
touch "$MARKER"
