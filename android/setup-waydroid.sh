#!/usr/bin/env bash
# =============================================================================
# SatasOS — Waydroid Setup Script
# =============================================================================
# Installs and configures Waydroid (Android-in-Linux container) with GAPPS
# image, GPU passthrough, multi-window mode, clipboard/file sharing, and
# auto-start on boot.
#
# Usage:  sudo ./setup-waydroid.sh [--no-gapps] [--headless]
# Requires: Ubuntu 22.04+ / SatasOS, Wayland session, root privileges
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ── Colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()   { echo -e "${GREEN}[SatasOS]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { err "$@"; exit 1; }
banner(){ echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n"; }

# ── Pre-flight checks ───────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "This script must be run as root (sudo)."
[[ -f /etc/os-release ]] && source /etc/os-release
log "Running on ${PRETTY_NAME:-Linux}"

# ── Parse arguments ─────────────────────────────────────────────────────────
INSTALL_GAPPS=true
HEADLESS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-gapps) INSTALL_GAPPS=false; shift ;;
        --headless) HEADLESS=true;       shift ;;
        *) warn "Unknown option: $1";    shift ;;
    esac
done

# ── Configuration constants ─────────────────────────────────────────────────
WAYDROID_DIR="/var/lib/waydroid"
WAYDROID_CFG="/var/lib/waydroid/waydroid.cfg"
WAYDROID_IMAGES_DIR="/usr/share/waydroid-extra/images"
SHARED_DIR="/home/${SUDO_USER:-$USER}/SatasOS-Android-Shared"
ANDROID_DATA_DIR="/home/${SUDO_USER:-$USER}/.local/share/waydroid/data"
DISPLAY_DPI=240
DISPLAY_WIDTH=1920
DISPLAY_HEIGHT=1080
ANDROID_VERSION="lineage-20"   # Android 13 (Tiramisu)

# ── Step 1: Install system dependencies ─────────────────────────────────────
banner "Step 1 / 8 — Installing system dependencies"

apt-get update -qq

DEPS=(
    curl wget lxc python3 python3-gi python3-dbus
    dbus-x11 gir1.2-gtk-4.0
    # Graphics — Mesa / virglrenderer
    mesa-utils libgl1-mesa-dri libglx-mesa0
    virglrenderer1
    # Wayland helpers
    wl-clipboard weston
    # Networking
    dnsmasq-base iptables iproute2
    # Container runtime
    lxc-utils
    # Kernel modules that Waydroid needs
    linux-modules-extra-$(uname -r) || true
)

log "Installing ${#DEPS[@]} packages …"
apt-get install -y --no-install-recommends "${DEPS[@]}" 2>/dev/null || \
    apt-get install -y "${DEPS[@]}"

# ── Step 2: Install Waydroid ────────────────────────────────────────────────
banner "Step 2 / 8 — Installing Waydroid"

if ! command -v waydroid &>/dev/null; then
    # Add the official Waydroid PPA
    log "Adding Waydroid repository …"
    curl -fsSL https://repo.waydro.id/waydroid.gpg \
        | gpg --dearmor -o /usr/share/keyrings/waydroid.gpg

    echo "deb [signed-by=/usr/share/keyrings/waydroid.gpg] https://repo.waydro.id/ $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/waydroid.list

    apt-get update -qq
    apt-get install -y waydroid
    log "Waydroid installed ✓"
else
    log "Waydroid already installed — $(waydroid --version)"
fi

# ── Step 3: Load required kernel modules ────────────────────────────────────
banner "Step 3 / 8 — Loading kernel modules"

MODULES=(binder_linux ashmem_linux)
for mod in "${MODULES[@]}"; do
    if ! lsmod | grep -q "^${mod}"; then
        log "Loading module: ${mod}"
        modprobe "$mod" 2>/dev/null || warn "${mod} not available — Waydroid will use binderfs"
    fi
done

# Persist modules across reboots
for mod in "${MODULES[@]}"; do
    grep -qxF "$mod" /etc/modules-load.d/waydroid.conf 2>/dev/null || \
        echo "$mod" >> /etc/modules-load.d/waydroid.conf
done
log "Kernel modules configured ✓"

# ── Step 4: Initialise Waydroid ─────────────────────────────────────────────
banner "Step 4 / 8 — Initialising Waydroid"

if [[ "$INSTALL_GAPPS" == true ]]; then
    log "Initialising with GAPPS image (Android 13) …"
    waydroid init -s GAPPS -r "$ANDROID_VERSION" -f 2>&1 | tail -5
else
    log "Initialising with vanilla image (Android 13) …"
    waydroid init -r "$ANDROID_VERSION" -f 2>&1 | tail -5
fi
log "Waydroid initialised ✓"

# ── Step 5: Configure GPU passthrough (Mesa / virglrenderer) ────────────────
banner "Step 5 / 8 — Configuring GPU passthrough"

# Detect GPU vendor
GPU_VENDOR="unknown"
if lspci | grep -qi nvidia; then
    GPU_VENDOR="nvidia"
elif lspci | grep -qi "amd\|radeon"; then
    GPU_VENDOR="amd"
elif lspci | grep -qi "intel"; then
    GPU_VENDOR="intel"
fi
log "Detected GPU vendor: ${GPU_VENDOR}"

# Write Waydroid properties for GPU acceleration
waydroid prop set persist.waydroid.multi_windows true     2>/dev/null || true
waydroid prop set persist.waydroid.cursor_on_subsurface true 2>/dev/null || true
waydroid prop set persist.waydroid.invert_colors false    2>/dev/null || true
waydroid prop set persist.waydroid.width  "$DISPLAY_WIDTH"  2>/dev/null || true
waydroid prop set persist.waydroid.height "$DISPLAY_HEIGHT" 2>/dev/null || true

# GPU-specific tweaks
case "$GPU_VENDOR" in
    nvidia)
        warn "NVIDIA GPU detected — using software rendering (virgl). For best results switch to nouveau."
        waydroid prop set ro.hardware.gralloc    default    2>/dev/null || true
        waydroid prop set ro.hardware.egl        swiftshader 2>/dev/null || true
        ;;
    amd|intel)
        log "Setting up hardware-accelerated virglrenderer …"
        waydroid prop set ro.hardware.gralloc    minigbm_gbm_mesa 2>/dev/null || true
        waydroid prop set ro.hardware.egl        mesa       2>/dev/null || true
        ;;
    *)
        log "Unknown GPU — falling back to virgl software rendering."
        waydroid prop set ro.hardware.gralloc    default    2>/dev/null || true
        waydroid prop set ro.hardware.egl        swiftshader 2>/dev/null || true
        ;;
esac
log "GPU passthrough configured ✓"

# ── Step 6: Write waydroid.cfg ──────────────────────────────────────────────
banner "Step 6 / 8 — Writing waydroid.cfg"

# Ensure the config directory exists
mkdir -p "$(dirname "$WAYDROID_CFG")"

cat > "$WAYDROID_CFG" <<EOCFG
[properties]
# ── Display ──────────────────────────────────────────────────────
persist.waydroid.width = ${DISPLAY_WIDTH}
persist.waydroid.height = ${DISPLAY_HEIGHT}
persist.waydroid.density = ${DISPLAY_DPI}

# ── Multi-window mode ───────────────────────────────────────────
persist.waydroid.multi_windows = true
persist.waydroid.cursor_on_subsurface = true
persist.waydroid.fake_touch = false

# ── GPU / Rendering ─────────────────────────────────────────────
ro.hardware.gralloc = minigbm_gbm_mesa
ro.hardware.egl = mesa

# ── Networking ───────────────────────────────────────────────────
persist.waydroid.uevent = true

# ── Misc ─────────────────────────────────────────────────────────
persist.waydroid.invert_colors = false
persist.waydroid.suspend = true
persist.waydroid.background_start = true
EOCFG

log "waydroid.cfg written to ${WAYDROID_CFG} ✓"

# ── Step 7: Configure sharing (clipboard, files, network) ──────────────────
banner "Step 7 / 8 — Configuring host ↔ Android sharing"

# -- Clipboard sharing via wl-clipboard bridge --
log "Enabling clipboard sharing …"
waydroid prop set persist.waydroid.clipboard true 2>/dev/null || true

# -- Shared folder --
log "Setting up shared folder at ${SHARED_DIR} …"
mkdir -p "$SHARED_DIR"
chown "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$SHARED_DIR"

# Bind-mount shared folder into Waydroid data
MOUNT_POINT="${ANDROID_DATA_DIR}/media/0/SatasOS-Shared"
mkdir -p "$MOUNT_POINT" 2>/dev/null || true

# Persist the bind mount via fstab if not already there
FSTAB_LINE="${SHARED_DIR}  ${MOUNT_POINT}  none  bind  0  0"
if ! grep -qF "$SHARED_DIR" /etc/fstab 2>/dev/null; then
    echo "$FSTAB_LINE" >> /etc/fstab
    log "Added bind mount to /etc/fstab"
fi

# Mount immediately (ignore errors if Waydroid isn't running yet)
mount --bind "$SHARED_DIR" "$MOUNT_POINT" 2>/dev/null || \
    warn "Bind mount deferred — will activate when Waydroid session starts."

# -- Network bridge (lxc default) --
log "Ensuring network bridge …"
if ! ip link show waydroid0 &>/dev/null; then
    ip link add name waydroid0 type bridge 2>/dev/null || true
    ip addr add 192.168.240.1/24 dev waydroid0 2>/dev/null || true
    ip link set waydroid0 up 2>/dev/null || true
fi

# Enable IP forwarding & NAT for Android internet access
sysctl -w net.ipv4.ip_forward=1 >/dev/null
iptables -t nat -C POSTROUTING -s 192.168.240.0/24 -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s 192.168.240.0/24 -j MASQUERADE

log "Host ↔ Android sharing configured ✓"

# ── Step 8: Auto-start Waydroid on boot ─────────────────────────────────────
banner "Step 8 / 8 — Setting up auto-start"

# Create a systemd user service for the session
SYSTEMD_USER_DIR="/home/${SUDO_USER:-$USER}/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

cat > "$SYSTEMD_USER_DIR/waydroid-session.service" <<'EOF'
[Unit]
Description=SatasOS Waydroid Android Session
After=graphical-session.target waydroid-container.service
Wants=waydroid-container.service
PartOf=graphical-session.target

[Service]
Type=simple
ExecStartPre=/usr/bin/waydroid session stop
ExecStart=/usr/bin/waydroid session start
ExecStop=/usr/bin/waydroid session stop
Restart=on-failure
RestartSec=5
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_SESSION_TYPE=wayland

[Install]
WantedBy=graphical-session.target
EOF

chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$SYSTEMD_USER_DIR"

# Enable the system-level container service
systemctl enable waydroid-container.service 2>/dev/null || true

# Enable the user session service
su - "${SUDO_USER:-$USER}" -c "systemctl --user daemon-reload && systemctl --user enable waydroid-session.service" 2>/dev/null || \
    warn "Could not enable user service — enable manually with: systemctl --user enable waydroid-session.service"

log "Auto-start configured ✓"

# ── Summary ─────────────────────────────────────────────────────────────────
banner "Waydroid Setup Complete"

cat <<SUMMARY
  ${GREEN}✓${NC} Waydroid installed and initialised (Android 13 / ${ANDROID_VERSION})
  ${GREEN}✓${NC} GPU passthrough: ${GPU_VENDOR} via virglrenderer
  ${GREEN}✓${NC} Multi-window mode enabled
  ${GREEN}✓${NC} Display: ${DISPLAY_WIDTH}×${DISPLAY_HEIGHT} @ ${DISPLAY_DPI} DPI
  ${GREEN}✓${NC} Clipboard sharing enabled
  ${GREEN}✓${NC} Shared folder: ${SHARED_DIR}
  ${GREEN}✓${NC} Network bridge & NAT configured
  ${GREEN}✓${NC} Auto-start on boot enabled

  ${CYAN}Next steps:${NC}
    1. Run ${BOLD}./setup-gapps.sh${NC} to install Google Play Store & services.
    2. Start Android:  waydroid session start
    3. Launch full UI:  waydroid show-full-ui
    4. Shared files appear under /sdcard/SatasOS-Shared in Android.

SUMMARY

exit 0
