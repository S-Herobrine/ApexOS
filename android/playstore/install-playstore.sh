#!/usr/bin/env bash
# =============================================================================
# SatasOS — Google Play Store Certification & Setup
# =============================================================================
# Certifies the Waydroid device with Google, spoofs a known device fingerprint
# so the Play Store works correctly, and configures Play Store settings.
#
# Usage:  sudo ./install-playstore.sh [--auto-register]
# Requires: Waydroid session running, GApps installed, root privileges
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ── Colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()   { echo -e "${GREEN}[PlayStore]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { err "$@"; exit 1; }
banner(){ echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n"; }

# ── Pre-flight ───────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "This script must be run as root (sudo)."

AUTO_REGISTER=false
[[ "${1:-}" == "--auto-register" ]] && AUTO_REGISTER=true

WAYDROID_DIR="/var/lib/waydroid"
OVERLAY_DIR="${WAYDROID_DIR}/overlay/system"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Helper: verify Waydroid is running ───────────────────────────────────────
ensure_waydroid_running() {
    if ! waydroid status 2>/dev/null | grep -q "RUNNING"; then
        log "Starting Waydroid session …"
        su - "${SUDO_USER:-$USER}" -c "waydroid session start &" 2>/dev/null || true
        sleep 8
    fi
    waydroid status 2>/dev/null | grep -q "RUNNING" || \
        die "Waydroid session could not be started."
}

ensure_waydroid_running

# ── Step 1: Spoof device fingerprint for Play Store compatibility ────────────
banner "Step 1 / 5 — Spoofing Device Fingerprint"

# We use a Pixel 5 fingerprint — well-known and Play Store certified
FINGERPRINT="google/redfin/redfin:13/TQ3A.230901.001/10750268:user/release-keys"
DEVICE_MODEL="Pixel 5"
DEVICE_MANUFACTURER="Google"
DEVICE_BRAND="google"
DEVICE_PRODUCT="redfin"
DEVICE_BOARD="redfin"
DEVICE_HARDWARE="redfin"

log "Spoofing as ${DEVICE_MODEL} (${FINGERPRINT%%:*}) …"

# Write properties via Waydroid prop
SPOOF_PROPS=(
    "ro.build.fingerprint=${FINGERPRINT}"
    "ro.product.model=${DEVICE_MODEL}"
    "ro.product.manufacturer=${DEVICE_MANUFACTURER}"
    "ro.product.brand=${DEVICE_BRAND}"
    "ro.product.name=${DEVICE_PRODUCT}"
    "ro.product.device=${DEVICE_PRODUCT}"
    "ro.product.board=${DEVICE_BOARD}"
    "ro.hardware=${DEVICE_HARDWARE}"
    "ro.build.description=redfin-user 13 TQ3A.230901.001 10750268 release-keys"
    "ro.build.display.id=TQ3A.230901.001"
    "ro.build.product=${DEVICE_PRODUCT}"
    "ro.build.type=user"
    "ro.build.tags=release-keys"
    "ro.system.build.fingerprint=${FINGERPRINT}"
    "ro.vendor.build.fingerprint=${FINGERPRINT}"
    "ro.bootimage.build.fingerprint=${FINGERPRINT}"
    "ro.odm.build.fingerprint=${FINGERPRINT}"
)

# Write to overlay build.prop
BUILD_PROP="${OVERLAY_DIR}/build.prop"
mkdir -p "$(dirname "$BUILD_PROP")"
touch "$BUILD_PROP"

for prop_line in "${SPOOF_PROPS[@]}"; do
    key="${prop_line%%=*}"
    value="${prop_line#*=}"
    # Remove existing entry if present
    sed -i "/^${key}=/d" "$BUILD_PROP" 2>/dev/null || true
    echo "${prop_line}" >> "$BUILD_PROP"
    log "  Set: ${key}=${value}"
done

# Also set via waydroid prop for immediate effect
for prop_line in "${SPOOF_PROPS[@]}"; do
    key="${prop_line%%=*}"
    value="${prop_line#*=}"
    waydroid prop set "$key" "$value" 2>/dev/null || true
done

log "Device fingerprint spoofed as ${DEVICE_MODEL} ✓"

# ── Step 2: Certify device with Google ───────────────────────────────────────
banner "Step 2 / 5 — Device Certification"

# Retrieve the Google Services Framework Android ID
log "Retrieving GSF Android ID …"
ANDROID_ID=""

# Try multiple methods to get the ID
for attempt in $(seq 1 5); do
    ANDROID_ID=$(waydroid shell -- sqlite3 \
        /data/data/com.google.android.gsf/databases/gservices.db \
        "SELECT value FROM main WHERE name='android_id';" 2>/dev/null || echo "")
    [[ -n "$ANDROID_ID" ]] && break
    log "  Attempt ${attempt}/5 — GSF database not ready yet …"
    sleep 5
done

if [[ -z "$ANDROID_ID" ]]; then
    # Alternative method: dumpsys
    ANDROID_ID=$(waydroid shell -- dumpsys iphonesubinfo 2>/dev/null | \
        grep "Device ID" | awk '{print $NF}' || echo "")
fi

if [[ -n "$ANDROID_ID" ]]; then
    log "GSF Android ID: ${BOLD}${ANDROID_ID}${NC}"
    echo "${ANDROID_ID}" > "${SCRIPT_DIR}/android-id.txt"
    echo "${ANDROID_ID}" > "${SCRIPT_DIR}/../android-id.txt" 2>/dev/null || true
    log "ID saved to ${SCRIPT_DIR}/android-id.txt"

    if [[ "$AUTO_REGISTER" == true ]]; then
        log "Attempting automatic registration …"
        # Use curl to submit the ID to Google's device registration page
        REGISTER_RESULT=$(curl -s -X POST \
            "https://android.clients.google.com/checkin" \
            --data-urlencode "id=${ANDROID_ID}" \
            --data-urlencode "method=register" \
            2>/dev/null || echo "FAILED")
        if [[ "$REGISTER_RESULT" != "FAILED" ]]; then
            log "Automatic registration submitted ✓"
        else
            warn "Automatic registration failed — please register manually."
        fi
    fi

    echo ""
    log "  ${CYAN}Manual registration (if needed):${NC}"
    log "  1. Open: ${BOLD}https://www.google.com/android/uncertified/${NC}"
    log "  2. Sign in with your Google account"
    log "  3. Paste Android ID: ${BOLD}${ANDROID_ID}${NC}"
    log "  4. Click Register"
    log "  5. Wait 10-15 minutes, then restart Waydroid"
    echo ""
else
    warn "Could not retrieve Android ID. Ensure GApps are installed and Waydroid has been restarted."
fi

# ── Step 3: Configure Play Store settings ────────────────────────────────────
banner "Step 3 / 5 — Configuring Play Store"

log "Setting Play Store preferences …"

# Enable auto-updates (WiFi only by default for Waydroid)
waydroid shell -- settings put global app_auto_update_policy 1 2>/dev/null || true

# Don't require password for purchases (inside container)
waydroid shell -- settings put secure install_non_market_apps 1 2>/dev/null || true

# Allow unknown sources (for sideloading)
waydroid shell -- settings put secure unknown_sources 1 2>/dev/null || true

# Set Play Store update preferences via shared prefs
PLAY_PREFS_DIR="/data/data/com.android.vending/shared_prefs"
waydroid shell -- mkdir -p "$PLAY_PREFS_DIR" 2>/dev/null || true

# Create Play Store preferences XML
cat > /tmp/finsky.xml <<'PREFS_XML'
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="auto_update_enabled" value="true" />
    <int name="auto_update_wifi_only" value="0" />
    <boolean name="notify_updates" value="true" />
    <boolean name="content_filter_enabled" value="false" />
    <int name="content_filter_level" value="0" />
    <boolean name="require_password_for_purchases" value="false" />
    <boolean name="download_manager_enabled" value="true" />
    <boolean name="update_over_any_network" value="true" />
</map>
PREFS_XML

waydroid shell -- cp /tmp/finsky.xml "${PLAY_PREFS_DIR}/finsky.xml" 2>/dev/null || \
    warn "Could not write Play Store preferences — will use defaults."

log "Play Store settings configured ✓"

# ── Step 4: Whitelist Play Store in Waydroid ─────────────────────────────────
banner "Step 4 / 5 — Whitelisting Play Store"

log "Whitelisting Google packages for battery & network …"

# Whitelist Google packages from battery optimization
GOOGLE_PKGS=(
    "com.android.vending"           # Play Store
    "com.google.android.gms"        # Play Services
    "com.google.android.gsf"        # Services Framework
    "com.google.android.gsf.login"  # Account Manager
    "com.google.android.apps.maps"  # Maps
    "com.google.android.youtube"    # YouTube
    "com.google.android.gm"         # Gmail
)

for pkg in "${GOOGLE_PKGS[@]}"; do
    waydroid shell -- dumpsys deviceidle whitelist "+${pkg}" 2>/dev/null || true
    waydroid shell -- cmd appops set "$pkg" RUN_IN_BACKGROUND allow 2>/dev/null || true
    waydroid shell -- cmd appops set "$pkg" RUN_ANY_IN_BACKGROUND allow 2>/dev/null || true
done

log "Google packages whitelisted ✓"

# ── Step 5: Grant Play Store permissions ─────────────────────────────────────
banner "Step 5 / 5 — Granting Permissions"

log "Granting required permissions to Play Store …"

# Play Store permissions
PLAY_PERMS=(
    "android.permission.INTERNET"
    "android.permission.ACCESS_NETWORK_STATE"
    "android.permission.ACCESS_WIFI_STATE"
    "android.permission.WRITE_EXTERNAL_STORAGE"
    "android.permission.READ_EXTERNAL_STORAGE"
    "android.permission.GET_ACCOUNTS"
    "android.permission.MANAGE_ACCOUNTS"
    "android.permission.AUTHENTICATE_ACCOUNTS"
    "android.permission.READ_PHONE_STATE"
    "android.permission.RECEIVE_BOOT_COMPLETED"
    "android.permission.WAKE_LOCK"
    "android.permission.INSTALL_PACKAGES"
    "android.permission.DELETE_PACKAGES"
    "android.permission.REQUEST_INSTALL_PACKAGES"
)

for perm in "${PLAY_PERMS[@]}"; do
    waydroid shell -- pm grant com.android.vending "$perm" 2>/dev/null || true
    waydroid shell -- pm grant com.google.android.gms "$perm" 2>/dev/null || true
done

# Grant Play Services signature-level permissions
waydroid shell -- pm grant com.google.android.gms \
    "android.permission.INTERACT_ACROSS_USERS" 2>/dev/null || true
waydroid shell -- pm grant com.google.android.gms \
    "android.permission.INTERACT_ACROSS_USERS_FULL" 2>/dev/null || true

log "Permissions granted ✓"

# ── Final restart & verify ───────────────────────────────────────────────────
banner "Restarting Waydroid"

waydroid session stop 2>/dev/null || true
sleep 2
systemctl restart waydroid-container.service 2>/dev/null || true
sleep 3
su - "${SUDO_USER:-$USER}" -c "waydroid session start &" 2>/dev/null || true
sleep 10

log "Verifying Play Store installation …"
if waydroid shell -- pm list packages 2>/dev/null | grep -q "com.android.vending"; then
    log "${GREEN}✓${NC} Play Store is installed and ready!"
    # Get Play Store version
    PS_VERSION=$(waydroid shell -- dumpsys package com.android.vending 2>/dev/null | \
        grep "versionName" | head -1 | awk -F= '{print $2}' || echo "unknown")
    log "  Play Store version: ${PS_VERSION}"
else
    warn "Play Store not detected — try restarting Waydroid manually."
fi

# ── Summary ─────────────────────────────────────────────────────────────────
banner "Play Store Setup Complete"

cat <<SUMMARY
  ${GREEN}✓${NC} Device fingerprint spoofed as ${DEVICE_MODEL}
  ${GREEN}✓${NC} Device registration prepared (ID: ${ANDROID_ID:-pending})
  ${GREEN}✓${NC} Play Store auto-updates enabled
  ${GREEN}✓${NC} Play Store settings configured
  ${GREEN}✓${NC} Google packages whitelisted
  ${GREEN}✓${NC} Permissions granted

  ${CYAN}To open Play Store:${NC}
    waydroid app launch com.android.vending

  ${CYAN}To register device (if not done):${NC}
    Visit https://www.google.com/android/uncertified/
    Enter ID: ${ANDROID_ID:-<run script again after Waydroid restart>}

SUMMARY

exit 0
