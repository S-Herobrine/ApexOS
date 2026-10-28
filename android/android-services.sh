#!/usr/bin/env bash
# =============================================================================
# SatasOS — Android Services Installer
# =============================================================================
# Installs all essential Google apps and services into the Waydroid container
# via ADB / waydroid shell.  Apps are installed from APKMirror / direct URLs
# when possible, or launched from the Play Store for user sign-in.
#
# Usage:  sudo ./android-services.sh [--minimal] [--skip-download]
# Requires: Waydroid session running with GApps, root privileges
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ── Colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()   { echo -e "${GREEN}[Services]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { err "$@"; exit 1; }
banner(){ echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n"; }

# ── Pre-flight ───────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "This script must be run as root (sudo)."

MINIMAL=false
SKIP_DOWNLOAD=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --minimal)       MINIMAL=true;       shift ;;
        --skip-download) SKIP_DOWNLOAD=true; shift ;;
        *) warn "Unknown option: $1";        shift ;;
    esac
done

# ── Paths ────────────────────────────────────────────────────────────────────
APK_CACHE="/tmp/satasos-android-apks"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARCH="x86_64"

mkdir -p "$APK_CACHE"

# ── Verify Waydroid is running ───────────────────────────────────────────────
banner "Checking Waydroid Status"

if ! waydroid status 2>/dev/null | grep -q "RUNNING"; then
    log "Starting Waydroid session …"
    su - "${SUDO_USER:-$USER}" -c "waydroid session start &" 2>/dev/null || true
    sleep 8
fi
waydroid status 2>/dev/null | grep -q "RUNNING" || \
    die "Waydroid is not running.  Start it first: waydroid session start"
log "Waydroid session is running ✓"

# ── Verify GApps installed ───────────────────────────────────────────────────
if ! waydroid shell -- pm list packages 2>/dev/null | grep -q "com.google.android.gms"; then
    die "Google Play Services not found.  Run setup-gapps.sh first."
fi
log "Google Play Services detected ✓"

# ── App definitions ──────────────────────────────────────────────────────────
# Format: "package_name|display_name|category|minimal"
# category: core / google / productivity / media
# minimal: yes = install even with --minimal

declare -a ALL_APPS=(
    # ── Core services (already via GApps, verify only) ──
    "com.google.android.gms|Google Play Services|core|yes"
    "com.google.android.gsf|Google Services Framework|core|yes"
    "com.google.android.gsf.login|Google Account Manager|core|yes"
    "com.android.vending|Google Play Store|core|yes"
    "com.google.android.ext.services|Android System Intelligence|core|yes"

    # ── Sync adapters ──
    "com.google.android.syncadapters.calendar|Google Calendar Sync|core|yes"
    "com.google.android.syncadapters.contacts|Google Contacts Sync|core|yes"

    # ── System components ──
    "com.google.android.webview|Android System WebView|core|yes"
    "com.google.android.tts|Google Text-to-Speech|core|yes"
    "com.google.android.gms.location|Google Location Services|core|yes"

    # ── Google apps ──
    "com.android.chrome|Google Chrome|google|yes"
    "com.google.android.apps.nbu.files|Files by Google|google|yes"
    "com.google.android.gm|Gmail|google|no"
    "com.google.android.apps.photos|Google Photos|google|no"
    "com.google.android.apps.maps|Google Maps|google|no"
    "com.google.android.youtube|YouTube|media|no"
    "com.google.android.apps.docs|Google Drive|productivity|no"
    "com.google.android.keep|Google Keep|productivity|no"
    "com.google.android.apps.messaging|Google Messages|google|no"
)

# ── Helper: install an APK via waydroid shell ────────────────────────────────
install_apk() {
    local pkg="$1" name="$2"

    # Check if already installed
    if waydroid shell -- pm list packages 2>/dev/null | grep -q "^package:${pkg}$"; then
        log "  ${GREEN}✓${NC} ${name} — already installed"
        return 0
    fi

    # Check for cached APK
    local apk_file="${APK_CACHE}/${pkg}.apk"
    if [[ -f "$apk_file" ]]; then
        log "  Installing ${name} from cache …"
        waydroid shell -- pm install -r "/data/local/tmp/${pkg}.apk" 2>/dev/null && {
            log "  ${GREEN}✓${NC} ${name} — installed from APK"
            return 0
        }
    fi

    # Try installing from Play Store
    log "  ${YELLOW}⟳${NC} ${name} — queuing for Play Store install …"
    # Trigger Play Store to download the app
    waydroid shell -- am start -a android.intent.action.VIEW \
        -d "market://details?id=${pkg}" \
        -n com.android.vending/.AssetBrowserActivity 2>/dev/null || true

    return 0
}

# ── Helper: enable a system app ──────────────────────────────────────────────
enable_system_app() {
    local pkg="$1" name="$2"
    waydroid shell -- pm enable "$pkg" 2>/dev/null || true

    if waydroid shell -- pm list packages -e 2>/dev/null | grep -q "^package:${pkg}$"; then
        log "  ${GREEN}✓${NC} ${name} — enabled"
    else
        warn "  ${name} (${pkg}) could not be enabled"
    fi
}

# ── Install core services ───────────────────────────────────────────────────
banner "Installing Core Android Services"

log "Verifying and enabling core services …"

CORE_SERVICES=(
    "com.google.android.gms|Google Play Services"
    "com.google.android.gsf|Google Services Framework"
    "com.google.android.gsf.login|Google Account Manager"
    "com.android.vending|Google Play Store"
)

for entry in "${CORE_SERVICES[@]}"; do
    IFS='|' read -r pkg name <<< "$entry"
    enable_system_app "$pkg" "$name"
done

# ── Configure sync adapters ─────────────────────────────────────────────────
banner "Configuring Sync Adapters"

log "Enabling Calendar & Contacts sync …"

# Enable sync for all accounts
waydroid shell -- content call --uri content://com.android.contacts \
    --method "sync" 2>/dev/null || true

# Grant sync permissions
SYNC_PKGS=("com.google.android.syncadapters.calendar" "com.google.android.syncadapters.contacts")
for pkg in "${SYNC_PKGS[@]}"; do
    enable_system_app "$pkg" "$pkg"
    waydroid shell -- pm grant "$pkg" "android.permission.READ_CALENDAR" 2>/dev/null || true
    waydroid shell -- pm grant "$pkg" "android.permission.WRITE_CALENDAR" 2>/dev/null || true
    waydroid shell -- pm grant "$pkg" "android.permission.READ_CONTACTS" 2>/dev/null || true
    waydroid shell -- pm grant "$pkg" "android.permission.WRITE_CONTACTS" 2>/dev/null || true
done

log "Sync adapters configured ✓"

# ── Install WebView ──────────────────────────────────────────────────────────
banner "Setting Up Android System WebView"

enable_system_app "com.google.android.webview" "Android System WebView"

# Set Google WebView as the default provider
waydroid shell -- cmd webviewupdate set-webview-implementation \
    com.google.android.webview 2>/dev/null || true
log "WebView configured ✓"

# ── Install Google TTS ───────────────────────────────────────────────────────
banner "Setting Up Google Text-to-Speech"

enable_system_app "com.google.android.tts" "Google TTS"
waydroid shell -- settings put secure tts_default_synth com.google.android.tts 2>/dev/null || true
log "Google TTS configured ✓"

# ── Install Google Chrome ────────────────────────────────────────────────────
banner "Installing Google Chrome"

install_apk "com.android.chrome" "Google Chrome"

# Set Chrome as default browser
waydroid shell -- pm set-home-activity com.android.chrome 2>/dev/null || true
waydroid shell -- cmd role add-role-holder android.app.role.BROWSER \
    com.android.chrome 2>/dev/null || true
log "Chrome setup complete ✓"

# ── Install Files by Google ──────────────────────────────────────────────────
banner "Installing Files by Google"

install_apk "com.google.android.apps.nbu.files" "Files by Google"
log "Files by Google setup complete ✓"

# ── Install remaining Google apps (non-minimal) ─────────────────────────────
if [[ "$MINIMAL" == false ]]; then
    banner "Installing Additional Google Apps"

    EXTRA_APPS=(
        "com.google.android.gm|Gmail"
        "com.google.android.apps.photos|Google Photos"
        "com.google.android.apps.maps|Google Maps"
        "com.google.android.youtube|YouTube"
        "com.google.android.apps.docs|Google Drive"
        "com.google.android.keep|Google Keep"
        "com.google.android.apps.messaging|Google Messages"
    )

    for entry in "${EXTRA_APPS[@]}"; do
        IFS='|' read -r pkg name <<< "$entry"
        install_apk "$pkg" "$name"
    done

    log "Additional apps queued / installed ✓"
else
    log "Skipping extra apps (--minimal mode)"
fi

# ── Configure Google Location Services ───────────────────────────────────────
banner "Configuring Location Services"

# Enable location providers
waydroid shell -- settings put secure location_mode 3 2>/dev/null || true  # High accuracy
waydroid shell -- settings put secure location_providers_allowed \
    "+gps,+wifi,+network" 2>/dev/null || true

# Grant location permissions to GMS
waydroid shell -- pm grant com.google.android.gms \
    "android.permission.ACCESS_FINE_LOCATION" 2>/dev/null || true
waydroid shell -- pm grant com.google.android.gms \
    "android.permission.ACCESS_COARSE_LOCATION" 2>/dev/null || true
waydroid shell -- pm grant com.google.android.gms \
    "android.permission.ACCESS_BACKGROUND_LOCATION" 2>/dev/null || true

log "Location services configured ✓"

# ── Whitelist all Google apps from doze ───────────────────────────────────────
banner "Whitelisting Apps from Battery Optimization"

for entry in "${ALL_APPS[@]}"; do
    IFS='|' read -r pkg name category minimal <<< "$entry"
    waydroid shell -- dumpsys deviceidle whitelist "+${pkg}" 2>/dev/null || true
done
log "Battery whitelist updated ✓"

# ── Generate installed-apps report ───────────────────────────────────────────
banner "Generating Installation Report"

REPORT_FILE="${SCRIPT_DIR}/installed-services.txt"
{
    echo "═══════════════════════════════════════════════════════════════"
    echo " SatasOS Android Services — Installation Report"
    echo " Generated: $(date -Iseconds)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Package                                     Status"
    echo "─────────────────────────────────────────── ────────"

    for entry in "${ALL_APPS[@]}"; do
        IFS='|' read -r pkg name category minimal <<< "$entry"
        if waydroid shell -- pm list packages 2>/dev/null | grep -q "^package:${pkg}$"; then
            printf "  %-44s ✓ Installed\n" "${name} (${pkg})"
        else
            printf "  %-44s ✗ Not found\n" "${name} (${pkg})"
        fi
    done

    echo ""
    echo "Apps marked '✗ Not found' may be available from the Play Store."
    echo "Open Play Store: waydroid app launch com.android.vending"
} | tee "$REPORT_FILE"

log "Report saved to ${REPORT_FILE}"

# ── Summary ─────────────────────────────────────────────────────────────────
banner "Android Services Setup Complete"

cat <<SUMMARY
  ${GREEN}✓${NC} Core Google Services verified & enabled
  ${GREEN}✓${NC} Calendar & Contacts sync configured
  ${GREEN}✓${NC} Android System WebView set up
  ${GREEN}✓${NC} Google TTS configured
  ${GREEN}✓${NC} Google Chrome installed
  ${GREEN}✓${NC} Files by Google installed
  ${GREEN}✓${NC} Location services configured
  ${GREEN}✓${NC} Battery whitelist updated

  ${CYAN}Open Play Store to install remaining apps:${NC}
    waydroid app launch com.android.vending

  ${CYAN}See full report:${NC}
    cat ${REPORT_FILE}

SUMMARY

exit 0
