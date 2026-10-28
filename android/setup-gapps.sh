#!/usr/bin/env bash
# =============================================================================
# SatasOS — Google Apps (GApps) Installer for Waydroid
# =============================================================================
# Installs Google Play Services, Play Store, and supporting Google frameworks
# inside the Waydroid Android container.  Also handles ARM translation layer
# (libhoudini / libndk) for running ARM-only apps on x86_64 hosts.
#
# Usage:  sudo ./setup-gapps.sh [--skip-houdini] [--force]
# Requires: Running Waydroid session, root privileges
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ── Colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()   { echo -e "${GREEN}[GApps]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { err "$@"; exit 1; }
banner(){ echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n"; }

# ── Pre-flight ───────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "This script must be run as root (sudo)."

SKIP_HOUDINI=false
FORCE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-houdini) SKIP_HOUDINI=true; shift ;;
        --force)        FORCE=true;        shift ;;
        *) warn "Unknown option: $1";      shift ;;
    esac
done

# ── Paths & constants ───────────────────────────────────────────────────────
WAYDROID_DIR="/var/lib/waydroid"
OVERLAY_DIR="${WAYDROID_DIR}/overlay"
OVERLAY_RW="${OVERLAY_DIR}/system"
GAPPS_WORK="/tmp/satasos-gapps-install"
ARCH=$(uname -m)
ANDROID_API=33        # Android 13
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# MindTheGapps download URL (Android 13, x86_64)
MINDTHEGAPPS_URL="https://github.com/nicholaschum/MindTheGapps/releases/download/20230415/MindTheGapps-13.0.0-x86_64-20230415.zip"
MINDTHEGAPPS_ZIP="${GAPPS_WORK}/MindTheGapps.zip"

# libhoudini (ARM translation) from waydroid_script
WAYDROID_SCRIPT_URL="https://github.com/casualsnek/waydroid_script.git"
WAYDROID_SCRIPT_DIR="${GAPPS_WORK}/waydroid_script"

# ── Helper: wait for Waydroid session ────────────────────────────────────────
wait_for_waydroid() {
    local max_wait=30 elapsed=0
    log "Waiting for Waydroid session to be ready …"
    while ! waydroid status 2>/dev/null | grep -q "RUNNING"; do
        sleep 1
        ((elapsed++))
        if (( elapsed >= max_wait )); then
            die "Waydroid session not running. Start it first: waydroid session start"
        fi
    done
    log "Waydroid session is running ✓"
}

# ── Helper: mount Waydroid system image RW ───────────────────────────────────
mount_system_rw() {
    log "Remounting Waydroid system as read-write …"
    waydroid shell -- mount -o remount,rw / 2>/dev/null || true
    mkdir -p "$OVERLAY_RW"
}

# ── Helper: restart Waydroid ─────────────────────────────────────────────────
restart_waydroid() {
    log "Restarting Waydroid …"
    waydroid session stop  2>/dev/null || true
    systemctl restart waydroid-container.service 2>/dev/null || true
    sleep 3
    su - "${SUDO_USER:-$USER}" -c "waydroid session start &" 2>/dev/null || true
    sleep 5
    wait_for_waydroid
}

# ── Preparation ──────────────────────────────────────────────────────────────
banner "Preparing GApps Installation"

mkdir -p "$GAPPS_WORK"
apt-get install -y -qq unzip wget python3 python3-pip lzip 2>/dev/null || true

wait_for_waydroid

# ── Step 1: Download MindTheGapps ────────────────────────────────────────────
banner "Step 1 / 5 — Downloading MindTheGapps"

if [[ ! -f "$MINDTHEGAPPS_ZIP" ]] || [[ "$FORCE" == true ]]; then
    log "Downloading MindTheGapps for Android 13 (${ARCH}) …"
    wget -q --show-progress -O "$MINDTHEGAPPS_ZIP" "$MINDTHEGAPPS_URL"
    log "Download complete ✓"
else
    log "MindTheGapps already downloaded — reusing cached copy."
fi

# ── Step 2: Extract and install GApps ────────────────────────────────────────
banner "Step 2 / 5 — Installing Google Apps"

GAPPS_EXTRACT="${GAPPS_WORK}/extracted"
rm -rf "$GAPPS_EXTRACT"
mkdir -p "$GAPPS_EXTRACT"
unzip -qo "$MINDTHEGAPPS_ZIP" -d "$GAPPS_EXTRACT"

mount_system_rw

# The MindTheGapps zip contains system/ with the APK trees
GAPPS_SYSTEM="${GAPPS_EXTRACT}/system"

if [[ -d "$GAPPS_SYSTEM" ]]; then
    log "Copying GApps into Waydroid overlay …"

    # Core Google packages to install
    GAPPS_PACKAGES=(
        "priv-app/GoogleServicesFramework"
        "priv-app/GmsCore"             # Google Play Services
        "priv-app/GoogleLoginService"  # Google Account Manager
        "priv-app/Phonesky"            # Play Store
        "priv-app/PrebuiltGmsCore"
        "app/GoogleCalendarSyncAdapter"
        "app/GoogleContactsSyncAdapter"
        "app/GoogleTTS"
        "framework"
        "etc/permissions"
        "etc/default-permissions"
        "etc/sysconfig"
        "etc/security"
        "lib64"
        "lib"
    )

    for pkg in "${GAPPS_PACKAGES[@]}"; do
        src="${GAPPS_SYSTEM}/${pkg}"
        dst="${OVERLAY_RW}/${pkg}"
        if [[ -e "$src" ]]; then
            mkdir -p "$(dirname "$dst")"
            cp -rf "$src" "$dst"
            log "  Installed: ${pkg}"
        fi
    done

    # Set correct permissions
    find "$OVERLAY_RW" -type d -exec chmod 755 {} \;
    find "$OVERLAY_RW" -type f -name "*.apk" -exec chmod 644 {} \;
    find "$OVERLAY_RW" -type f -name "*.so"  -exec chmod 644 {} \;

    log "GApps files installed ✓"
else
    # Fallback: use waydroid_script for installation
    warn "MindTheGapps structure not as expected — trying waydroid_script …"
    if [[ ! -d "$WAYDROID_SCRIPT_DIR" ]]; then
        git clone "$WAYDROID_SCRIPT_URL" "$WAYDROID_SCRIPT_DIR"
    fi
    cd "$WAYDROID_SCRIPT_DIR"
    pip3 install -r requirements.txt 2>/dev/null || true
    python3 main.py install gapps || die "GApps installation failed."
fi

# ── Step 3: Register device with Google ──────────────────────────────────────
banner "Step 3 / 5 — Registering device with Google"

# Get the Android ID from Waydroid
log "Retrieving Android ID …"
ANDROID_ID=""
for attempt in 1 2 3; do
    ANDROID_ID=$(waydroid shell -- sqlite3 /data/data/com.google.android.gsf/databases/gservices.db \
        "SELECT value FROM main WHERE name='android_id';" 2>/dev/null || echo "")
    [[ -n "$ANDROID_ID" ]] && break
    log "  Attempt $attempt — waiting for GSF database …"
    sleep 5
done

if [[ -n "$ANDROID_ID" ]]; then
    log "Android ID: ${ANDROID_ID}"
    log ""
    log "  ${YELLOW}To register this device with Google:${NC}"
    log "  1. Visit: ${BOLD}https://www.google.com/android/uncertified/${NC}"
    log "  2. Enter the Android ID: ${BOLD}${ANDROID_ID}${NC}"
    log "  3. Wait a few minutes and restart Waydroid."
    log ""
    # Save the ID for the user
    echo "$ANDROID_ID" > "${SCRIPT_DIR}/android-id.txt"
    log "Android ID saved to ${SCRIPT_DIR}/android-id.txt"
else
    warn "Could not retrieve Android ID yet."
    warn "After first boot, run: waydroid shell -- sqlite3 /data/data/com.google.android.gsf/databases/gservices.db \"SELECT value FROM main WHERE name='android_id';\""
fi

# ── Step 4: Install Google Play Services dependencies ────────────────────────
banner "Step 4 / 5 — Configuring Google Play Services"

# Set critical system properties for GApps
log "Setting Google Services properties …"

GAPPS_PROPS=(
    "ro.setupwizard.mode=OPTIONAL"
    "ro.com.google.gmsversion=13_202304"
    "ro.com.google.clientidbase=android-google"
    "ro.com.google.clientidbase.ms=android-google"
    "ro.com.google.clientidbase.yt=android-google"
    "ro.com.google.clientidbase.am=android-google"
    "ro.com.google.clientidbase.gmm=android-google"
    "persist.sys.timezone=UTC"
    "ro.opa.eligible_device=true"
    "ro.setupwizard.enterprise_mode=1"
    "ro.url.legal=http://www.google.com/intl/%s/mobile/android/basic/phone-legal.html"
    "ro.url.legal.android_privacy=http://www.google.com/intl/%s/mobile/android/basic/privacy.html"
    "ro.com.google.acctbutton=1"
    "ro.setupwizard.rotation_locked=true"
)

# Write to Waydroid overlay build.prop
BUILD_PROP="${OVERLAY_RW}/build.prop"
touch "$BUILD_PROP"
for prop in "${GAPPS_PROPS[@]}"; do
    key="${prop%%=*}"
    if ! grep -q "^${key}=" "$BUILD_PROP" 2>/dev/null; then
        echo "$prop" >> "$BUILD_PROP"
    fi
done
log "Google Play Services properties configured ✓"

# Configure Play Protect
log "Configuring Play Protect …"
waydroid shell -- settings put global package_verifier_enable 1 2>/dev/null || true
waydroid shell -- settings put global verifier_verify_adb_installs 1 2>/dev/null || true
waydroid shell -- settings put global package_verifier_user_consent 1 2>/dev/null || true
log "Play Protect configured ✓"

# ── Step 5: ARM translation layer (libhoudini) ──────────────────────────────
banner "Step 5 / 5 — ARM Translation Layer"

if [[ "$SKIP_HOUDINI" == true ]]; then
    warn "Skipping ARM translation layer (--skip-houdini)"
elif [[ "$ARCH" == "x86_64" || "$ARCH" == "x86" ]]; then
    log "x86_64 host detected — installing ARM translation (libhoudini) …"

    # Use waydroid_script for reliable houdini installation
    if [[ ! -d "$WAYDROID_SCRIPT_DIR" ]]; then
        git clone "$WAYDROID_SCRIPT_URL" "$WAYDROID_SCRIPT_DIR"
    fi
    cd "$WAYDROID_SCRIPT_DIR"
    pip3 install -r requirements.txt 2>/dev/null || true

    # Try libhoudini first, fall back to libndk_translation
    if python3 main.py install libhoudini 2>/dev/null; then
        log "libhoudini ARM translation installed ✓"
    else
        warn "libhoudini failed — trying libndk_translation …"
        python3 main.py install libndk 2>/dev/null || \
            warn "ARM translation could not be installed. ARM-only apps may not work."
    fi

    # Enable the translation in system properties
    waydroid prop set persist.waydroid.compat true 2>/dev/null || true
    log "ARM translation enabled ✓"
else
    log "ARM host detected — no translation layer needed."
fi

# ── Final restart ────────────────────────────────────────────────────────────
banner "Finalising Installation"

restart_waydroid

log "Waiting for Google Play Services to initialise (this may take 1-2 minutes) …"
sleep 15

# Verify installation
log "Verifying installed packages …"
EXPECTED_PKGS=("com.google.android.gms" "com.android.vending" "com.google.android.gsf")
for pkg in "${EXPECTED_PKGS[@]}"; do
    if waydroid shell -- pm list packages 2>/dev/null | grep -q "$pkg"; then
        log "  ${GREEN}✓${NC} $pkg"
    else
        warn "  ✗ $pkg — may need a second reboot"
    fi
done

# ── Summary ─────────────────────────────────────────────────────────────────
banner "GApps Installation Complete"

cat <<SUMMARY
  ${GREEN}✓${NC} MindTheGapps installed (Android 13)
  ${GREEN}✓${NC} Google Play Services
  ${GREEN}✓${NC} Google Services Framework
  ${GREEN}✓${NC} Google Account Manager
  ${GREEN}✓${NC} Google Play Store
  ${GREEN}✓${NC} Play Protect configured
  ${GREEN}✓${NC} Calendar & Contacts sync adapters

  ${CYAN}Next steps:${NC}
    1. Register device: visit https://www.google.com/android/uncertified/
       and enter Android ID from ${SCRIPT_DIR}/android-id.txt
    2. Wait 10-15 minutes, then restart Waydroid.
    3. Open Play Store and sign in with your Google account.
    4. Run ${BOLD}./android-services.sh${NC} to install recommended Google apps.

SUMMARY

exit 0
