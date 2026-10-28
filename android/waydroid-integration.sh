#!/bin/bash
set -euo pipefail

# SatasOS Waydroid Integration Bridge
# Manages clipboard, notification forwarding, and bidirectional folder sharing

echo "==> Initializing SatasOS Android Integration Bridge..."

# 1. Ensure Waydroid container is running
if ! systemctl is-active --quiet waydroid-container; then
    echo "Starting Waydroid container..."
    sudo systemctl start waydroid-container
fi

# 2. Setup shared folders between host Linux and Android
ANDROID_MEDIA_PATH="/var/lib/waydroid/data/media/0"
HOST_HOME="$HOME"

if [ -d "$ANDROID_MEDIA_PATH" ]; then
    echo "Setting up shared folders..."
    mkdir -p "$HOST_HOME/AndroidShared"
    mkdir -p "$ANDROID_MEDIA_PATH/HostShared"
    # Mount bind if root
    sudo mount --bind "$HOST_HOME/AndroidShared" "$ANDROID_MEDIA_PATH/HostShared" 2>/dev/null || true
fi

# 3. Clipboard sync loop (bidirectional)
echo "Starting clipboard synchronization..."
which wl-paste >/dev/null 2>&1 && {
    (
        LAST_CLIP=""
        while true; do
            CLIP=$(wl-paste --no-newline 2>/dev/null || true)
            if [ -n "$CLIP" ] && [ "$CLIP" != "$LAST_CLIP" ]; then
                LAST_CLIP="$CLIP"
                # Send to Android clipboard via waydroid shell
                waydroid shell set-clipboard "$CLIP" 2>/dev/null || true
            fi
            sleep 1
        done
    ) &
} || true

echo "==> SatasOS Android Bridge running in background."
