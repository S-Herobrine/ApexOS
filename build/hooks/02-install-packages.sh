#!/bin/bash
set -euo pipefail

echo "==> [02/05] SatasOS: Installing system packages..."

export DEBIAN_FRONTEND=noninteractive

apt update

PKG_DIR="/etc/satasos/package-lists"

if [ -d "$PKG_DIR" ]; then
    for list_file in "$PKG_DIR"/*.list; do
        if [ -f "$list_file" ]; then
            echo "Installing packages from $list_file..."
            grep -v '^#' "$list_file" | grep -v '^[[:space:]]*$' | xargs -r apt install -y --no-install-recommends
        fi
    done
fi

echo "==> Package installation stage completed."
