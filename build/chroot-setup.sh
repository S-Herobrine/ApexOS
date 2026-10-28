#!/bin/bash
###############################################################################
# SatasOS Chroot Setup Script
# Runs inside the chroot environment during ISO build to configure the system
# Sets up repos, user defaults, GNOME/desktop config, branding, and live session
###############################################################################
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export LANG=en_US.UTF-8

# =============================================================================
# Configuration Constants
# =============================================================================
SATASOS_VERSION="1.0"
SATASOS_CODENAME="Genesis"
SATASOS_USER="satasos"
SATASOS_HOSTNAME="satasos"
LIVE_USER="satasos"

# Brand Colors
PRIMARY_COLOR="#7C3AED"
DARK_BG="#1E1B2E"
ACCENT_COLOR="#A78BFA"

# =============================================================================
# Helper Functions
# =============================================================================
log_step() {
    echo ">>> [SatasOS Chroot] $1"
}

# =============================================================================
# Phase 1: Add PPAs and Third-Party Repositories
# =============================================================================
setup_repositories() {
    log_step "Setting up third-party repositories..."

    # Ensure prerequisites are installed
    apt-get update -qq
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        wget

    # --- Google Chrome ---
    log_step "Adding Google Chrome repository..."
    wget -qO- https://dl.google.com/linux/linux_signing_key.pub | \
        gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list

    # --- Microsoft Edge ---
    log_step "Adding Microsoft Edge repository..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
        gpg --dearmor -o /usr/share/keyrings/microsoft-edge-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge-keyring.gpg] https://packages.microsoft.com/repos/edge stable main" \
        > /etc/apt/sources.list.d/microsoft-edge.list

    # --- Opera Browser ---
    log_step "Adding Opera repository..."
    wget -qO- https://deb.opera.com/archive.key | \
        gpg --dearmor -o /usr/share/keyrings/opera-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/opera-keyring.gpg] https://deb.opera.com/opera-stable/ stable non-free" \
        > /etc/apt/sources.list.d/opera-stable.list

    # --- Mozilla Firefox (from Mozilla PPA for latest versions) ---
    log_step "Adding Mozilla Firefox PPA..."
    add-apt-repository -y ppa:mozillateam/ppa

    # Pin Firefox PPA over snap version
    cat > /etc/apt/preferences.d/mozilla-firefox << 'EOF'
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001

Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1
EOF

    # --- Visual Studio Code ---
    log_step "Adding Visual Studio Code repository..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
        gpg --dearmor -o /usr/share/keyrings/vscode-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/vscode-keyring.gpg] https://packages.microsoft.com/repos/code stable main" \
        > /etc/apt/sources.list.d/vscode.list

    # --- Waydroid ---
    log_step "Adding Waydroid repository..."
    curl -fsSL https://repo.waydro.id/waydroid.gpg | \
        gpg --dearmor -o /usr/share/keyrings/waydroid-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/waydroid-keyring.gpg] https://repo.waydro.id/ noble main" \
        > /etc/apt/sources.list.d/waydroid.list

    # --- Additional PPAs ---
    log_step "Adding additional PPAs..."
    # LibreOffice latest
    add-apt-repository -y ppa:libreoffice/ppa
    # GIMP latest
    add-apt-repository -y ppa:ubuntuhandbook1/gimp
    # OBS Studio
    add-apt-repository -y ppa:obsproject/obs-studio

    # Update package cache with all new repos
    apt-get update -qq

    log_step "Repository setup complete."
}

# =============================================================================
# Phase 2: Set Up User Defaults
# =============================================================================
setup_user_defaults() {
    log_step "Setting up user defaults..."

    # Create skel directory structure for new users
    local skel="/etc/skel"
    mkdir -p "${skel}/.config/autostart"
    mkdir -p "${skel}/.config/gtk-3.0"
    mkdir -p "${skel}/.config/gtk-4.0"
    mkdir -p "${skel}/.local/share/applications"
    mkdir -p "${skel}/.local/share/icons"
    mkdir -p "${skel}/.local/share/fonts"
    mkdir -p "${skel}/Desktop"
    mkdir -p "${skel}/Documents"
    mkdir -p "${skel}/Downloads"
    mkdir -p "${skel}/Music"
    mkdir -p "${skel}/Pictures"
    mkdir -p "${skel}/Videos"
    mkdir -p "${skel}/Projects"
    mkdir -p "${skel}/Android"

    # GTK-3 settings
    cat > "${skel}/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=SatasOS-Dark
gtk-icon-theme-name=SatasOS-Icons
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-font-name=Inter 11
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-decoration-layout=close,minimize,maximize:menu
gtk-enable-animations=1
EOF

    # GTK-4 settings
    cat > "${skel}/.config/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=SatasOS-Dark
gtk-icon-theme-name=SatasOS-Icons
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-font-name=Inter 11
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-decoration-layout=close,minimize,maximize:menu
gtk-enable-animations=1
EOF

    # Default terminal profile
    mkdir -p "${skel}/.config/satasos"
    cat > "${skel}/.config/satasos/terminal.conf" << 'EOF'
[Terminal]
font=JetBrains Mono 12
background-color=#1E1B2E
foreground-color=#E2E8F0
cursor-color=#7C3AED
palette=#1E1B2E:#FF6B6B:#4ADE80:#FBBF24:#7C3AED:#A78BFA:#22D3EE:#E2E8F0:#4A4458:#FF8A8A:#6EE7A0:#FCD34D:#9F67FF:#C4B5FD:#67E8F9:#F8FAFC
scrollback-lines=10000
EOF

    # Bookmarks for file manager
    cat > "${skel}/.config/gtk-3.0/bookmarks" << 'EOF'
file:///home/%u/Documents Documents
file:///home/%u/Downloads Downloads
file:///home/%u/Music Music
file:///home/%u/Pictures Pictures
file:///home/%u/Videos Videos
file:///home/%u/Projects Projects
file:///home/%u/Android Android
EOF

    # Desktop shortcut for installer
    cat > "${skel}/Desktop/install-satasos.desktop" << 'EOF'
[Desktop Entry]
Name=Install SatasOS
Comment=Install SatasOS to your hard drive
Exec=calamares-pkexec
Icon=calamares
Terminal=false
Type=Application
Categories=System;
StartupNotify=true
EOF
    chmod +x "${skel}/Desktop/install-satasos.desktop"

    log_step "User defaults configured."
}

# =============================================================================
# Phase 3: Configure GNOME/Desktop Defaults via dconf
# =============================================================================
configure_desktop_defaults() {
    log_step "Configuring GNOME/Desktop defaults via dconf..."

    # Create dconf profile
    mkdir -p /etc/dconf/profile
    cat > /etc/dconf/profile/user << 'EOF'
user-db:user
system-db:satasos
EOF

    # Create dconf database directory
    mkdir -p /etc/dconf/db/satasos.d
    mkdir -p /etc/dconf/db/satasos.d/locks

    # --- Desktop Interface Settings ---
    cat > /etc/dconf/db/satasos.d/00-interface << 'EOF'
[org/gnome/desktop/interface]
gtk-theme='SatasOS-Dark'
icon-theme='SatasOS-Icons'
cursor-theme='Bibata-Modern-Classic'
font-name='Inter 11'
document-font-name='Inter 11'
monospace-font-name='JetBrains Mono 12'
clock-show-weekday=true
clock-show-seconds=false
clock-format='12h'
enable-animations=true
show-battery-percentage=true
color-scheme='prefer-dark'
accent-color='purple'
toolkit-accessibility=false
EOF

    # --- Window Manager / Mutter ---
    cat > /etc/dconf/db/satasos.d/01-wm << 'EOF'
[org/gnome/desktop/wm/preferences]
button-layout='close,minimize,maximize:appmenu'
titlebar-font='Inter Bold 11'
action-double-click-titlebar='toggle-maximize'
action-middle-click-titlebar='minimize'
focus-mode='click'
num-workspaces=4

[org/gnome/mutter]
center-new-windows=true
dynamic-workspaces=true
edge-tiling=true
workspaces-only-on-primary=true
experimental-features=['scale-monitor-framebuffer']
EOF

    # --- Shell / Panel ---
    cat > /etc/dconf/db/satasos.d/02-shell << 'EOF'
[org/gnome/shell]
enabled-extensions=['dash-to-panel@jderose9.github.com', 'arcmenu@arcmenu.com', 'appindicatorsupport@rgcjonas.gmail.com', 'clipboard-indicator@tudmotu.com', 'blur-my-shell@aunetx', 'just-perfection-desktop@just-perfection', 'user-theme@gnome-shell-extensions.gcampax.github.com']
favorite-apps=['org.gnome.Nautilus.desktop', 'google-chrome.desktop', 'firefox.desktop', 'org.gnome.Terminal.desktop', 'code.desktop', 'org.gnome.Settings.desktop', 'calamares.desktop']
welcome-dialog-last-shown-version='99.0'

[org/gnome/shell/extensions/dash-to-panel]
panel-positions='{"0":"BOTTOM"}'
panel-sizes='{"0":48}'
panel-element-positions='{"0":[{"element":"showAppsButton","visible":false,"position":"stackedTL"},{"element":"activitiesButton","visible":false,"position":"stackedTL"},{"element":"leftBox","visible":true,"position":"stackedTL"},{"element":"taskbar","visible":true,"position":"centerMonitor"},{"element":"centerBox","visible":true,"position":"stackedBR"},{"element":"rightBox","visible":true,"position":"stackedBR"},{"element":"dateMenu","visible":true,"position":"stackedBR"},{"element":"systemMenu","visible":true,"position":"stackedBR"},{"element":"desktopButton","visible":true,"position":"stackedBR"}]}'
dot-style-focused='DASHES'
dot-style-unfocused='DOTS'
dot-color-dominant=false
dot-color-override=true
dot-color-1='#7C3AED'
dot-color-2='#7C3AED'
dot-color-3='#7C3AED'
dot-color-4='#7C3AED'
dot-color-unfocused-1='#A78BFA'
dot-color-unfocused-2='#A78BFA'
dot-color-unfocused-3='#A78BFA'
dot-color-unfocused-4='#A78BFA'
trans-use-custom-bg=true
trans-bg-color='#1E1B2E'
trans-use-custom-opacity=true
trans-panel-opacity=0.85
animate-appicon-hover=true
animate-appicon-hover-animation-extent={'RIPPLE': 4, 'PLANK': 4, 'SIMPLE': 1}

[org/gnome/shell/extensions/arcmenu]
menu-button-appearance='Icon'
menu-button-icon='Custom_Icon'
custom-menu-button-icon='/usr/share/satasos/icons/satasos-menu-icon.svg'
menu-layout='Windows'
menu-width=680
menu-height=750
enable-activities-shortcut=false
highlight-color='rgba(124, 58, 237, 0.15)'
highlight-foreground-color='rgba(167, 139, 250, 1)'
border-color='rgba(124, 58, 237, 0.3)'

[org/gnome/shell/extensions/blur-my-shell]
brightness=0.75
sigma=30
EOF

    # --- Background / Wallpaper ---
    cat > /etc/dconf/db/satasos.d/03-background << 'EOF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/satasos/default.png'
picture-uri-dark='file:///usr/share/backgrounds/satasos/default-dark.png'
picture-options='zoom'
primary-color='#1E1B2E'
secondary-color='#7C3AED'
color-shading-type='solid'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/satasos/lock-screen.png'
picture-options='zoom'
primary-color='#1E1B2E'
lock-delay=uint32 300
EOF

    # --- Power / Session ---
    cat > /etc/dconf/db/satasos.d/04-power << 'EOF'
[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-timeout=1800
ambient-enabled=true
idle-dim=true

[org/gnome/desktop/session]
idle-delay=uint32 600

[org/gnome/desktop/notifications]
show-in-lock-screen=false

[org/gnome/desktop/privacy]
remove-old-trash-files=true
remove-old-temp-files=true
old-files-age=uint32 30
remember-recent-files=true
recent-files-max-age=30
EOF

    # --- Input / Keybindings ---
    cat > /etc/dconf/db/satasos.d/05-input << 'EOF'
[org/gnome/desktop/input-sources]
sources=[('xkb', 'us')]
xkb-options=['caps:escape']

[org/gnome/settings-daemon/plugins/media-keys]
home=['<Super>e']
www=['<Super>b']
terminal=['<Super>t']
calculator=['<Super>c']
screensaver=['<Super>l']
area-screenshot=['<Shift><Super>s']

[org/gnome/desktop/wm/keybindings]
switch-applications=['<Alt>Tab']
switch-windows=['<Super>Tab']
show-desktop=['<Super>d']
maximize=['<Super>Up']
unmaximize=['<Super>Down']
move-to-workspace-left=['<Shift><Super>Left']
move-to-workspace-right=['<Shift><Super>Right']
switch-to-workspace-left=['<Super>Left']
switch-to-workspace-right=['<Super>Right']
close=['<Alt>F4']
toggle-fullscreen=['<Super>F11']
EOF

    # --- Touchpad ---
    cat > /etc/dconf/db/satasos.d/06-peripherals << 'EOF'
[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
two-finger-scrolling-enabled=true
natural-scroll=true
speed=0.3

[org/gnome/desktop/peripherals/mouse]
natural-scroll=false
speed=0.0
EOF

    # --- Night Light ---
    cat > /etc/dconf/db/satasos.d/07-nightlight << 'EOF'
[org/gnome/settings-daemon/plugins/color]
night-light-enabled=true
night-light-schedule-automatic=true
night-light-temperature=uint32 3500
EOF

    # --- File Manager ---
    cat > /etc/dconf/db/satasos.d/08-nautilus << 'EOF'
[org/gnome/nautilus/preferences]
default-folder-viewer='icon-view'
show-hidden-files=false
show-delete-permanently=true
show-create-link=true

[org/gnome/nautilus/icon-view]
default-zoom-level='medium'

[org/gnome/nautilus/list-view]
default-zoom-level='small'
use-tree-view=true

[org/gtk/settings/file-chooser]
sort-directories-first=true
show-hidden=false
EOF

    # --- Terminal ---
    cat > /etc/dconf/db/satasos.d/09-terminal << 'EOF'
[org/gnome/terminal/legacy]
theme-variant='dark'
default-show-menubar=false

[org/gnome/terminal/legacy/profiles:/:satasos-default]
visible-name='SatasOS Default'
use-theme-colors=false
background-color='#1E1B2E'
foreground-color='#E2E8F0'
cursor-background-color='#7C3AED'
cursor-foreground-color='#FFFFFF'
highlight-background-color='#7C3AED'
highlight-foreground-color='#FFFFFF'
palette=['#1E1B2E', '#FF6B6B', '#4ADE80', '#FBBF24', '#7C3AED', '#A78BFA', '#22D3EE', '#E2E8F0', '#4A4458', '#FF8A8A', '#6EE7A0', '#FCD34D', '#9F67FF', '#C4B5FD', '#67E8F9', '#F8FAFC']
font='JetBrains Mono 12'
use-system-font=false
audible-bell=false
scrollback-unlimited=true
cursor-shape='ibeam'
cursor-blink-mode='on'
bold-is-bright=true
EOF

    # Lock critical settings that define the SatasOS brand
    cat > /etc/dconf/db/satasos.d/locks/00-satasos-locks << 'EOF'
/org/gnome/desktop/interface/gtk-theme
/org/gnome/desktop/interface/icon-theme
/org/gnome/shell/enabled-extensions
EOF

    # Compile dconf database
    dconf update

    log_step "GNOME/Desktop defaults configured."
}

# =============================================================================
# Phase 4: Set SatasOS Branding
# =============================================================================
setup_branding() {
    log_step "Setting up SatasOS branding..."

    # Create SatasOS system directories
    mkdir -p /usr/share/satasos/icons
    mkdir -p /usr/share/satasos/logos
    mkdir -p /usr/share/satasos/sounds
    mkdir -p /usr/share/backgrounds/satasos
    mkdir -p /usr/share/pixmaps

    # OS Release information
    cat > /etc/os-release << EOF
PRETTY_NAME="SatasOS ${SATASOS_VERSION} (${SATASOS_CODENAME})"
NAME="SatasOS"
VERSION_ID="${SATASOS_VERSION}"
VERSION="${SATASOS_VERSION} (${SATASOS_CODENAME})"
VERSION_CODENAME=${SATASOS_CODENAME,,}
ID=satasos
ID_LIKE=ubuntu debian
HOME_URL="https://satasos.org"
SUPPORT_URL="https://satasos.org/support"
BUG_REPORT_URL="https://satasos.org/bugs"
PRIVACY_POLICY_URL="https://satasos.org/privacy"
UBUNTU_CODENAME=noble
LOGO=satasos-logo
EOF

    # LSB Release
    cat > /etc/lsb-release << EOF
DISTRIB_ID=SatasOS
DISTRIB_RELEASE=${SATASOS_VERSION}
DISTRIB_CODENAME=${SATASOS_CODENAME,,}
DISTRIB_DESCRIPTION="SatasOS ${SATASOS_VERSION} (${SATASOS_CODENAME})"
EOF

    # Hostname
    echo "$SATASOS_HOSTNAME" > /etc/hostname

    # Hosts file
    cat > /etc/hosts << EOF
127.0.0.1       localhost
127.0.1.1       ${SATASOS_HOSTNAME}

# IPv6
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

    # Issue / login banner
    cat > /etc/issue << 'EOF'
SatasOS 1.0 (Genesis) \n \l

EOF
    cat > /etc/issue.net << 'EOF'
SatasOS 1.0 (Genesis)
EOF

    # Legal notice
    cat > /etc/legal << 'EOF'
SatasOS is a free and open-source operating system.
Built on Ubuntu 24.04 LTS with love.
https://satasos.org
EOF

    # MOTD (Message of the Day)
    mkdir -p /etc/update-motd.d
    cat > /etc/update-motd.d/00-satasos-header << 'MOTD_EOF'
#!/bin/bash
echo ""
echo "  ____        _           ___  ____  "
echo " / ___|  __ _| |_ __ _ __/ _ \/ ___| "
echo " \___ \ / _\` | __/ _\` / __| | \___ \ "
echo "  ___) | (_| | || (_| \__ \ |_|___) |"
echo " |____/ \__,_|\__\__,_|___/\___/____/ "
echo ""
echo "  Version 1.0 (Genesis) | Ubuntu + Windows + Android"
echo "  https://satasos.org"
echo ""
MOTD_EOF
    chmod +x /etc/update-motd.d/00-satasos-header

    # Remove default Ubuntu MOTD scripts
    chmod -x /etc/update-motd.d/10-help-text 2>/dev/null || true
    chmod -x /etc/update-motd.d/50-motd-news 2>/dev/null || true
    chmod -x /etc/update-motd.d/88-esm-announce 2>/dev/null || true
    chmod -x /etc/update-motd.d/91-contract-ua-esm-status 2>/dev/null || true

    # Plymouth boot splash configuration
    mkdir -p /usr/share/plymouth/themes/satasos
    cat > /usr/share/plymouth/themes/satasos/satasos.plymouth << 'EOF'
[Plymouth Theme]
Name=SatasOS
Description=SatasOS Boot Splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/satasos
ScriptFile=/usr/share/plymouth/themes/satasos/satasos.script
EOF

    cat > /usr/share/plymouth/themes/satasos/satasos.script << 'SCRIPT_EOF'
# SatasOS Plymouth Boot Splash Script
# Displays animated logo with purple gradient background

# Background
Window.SetBackgroundTopColor(0.12, 0.11, 0.18);   # #1E1B2E
Window.SetBackgroundBottomColor(0.12, 0.11, 0.18); # #1E1B2E

# Logo
logo.image = Image("satasos-logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetX(Window.GetWidth() / 2 - logo.image.GetWidth() / 2);
logo.sprite.SetY(Window.GetHeight() / 2 - logo.image.GetHeight() / 2 - 40);
logo.sprite.SetOpacity(1);

# Progress bar
progress_box.image = Image("progress-box.png");
progress_box.sprite = Sprite(progress_box.image);
progress_box.x = Window.GetWidth() / 2 - progress_box.image.GetWidth() / 2;
progress_box.y = Window.GetHeight() / 2 + logo.image.GetHeight() / 2 + 20;
progress_box.sprite.SetPosition(progress_box.x, progress_box.y, 0);

progress_bar.original_image = Image("progress-bar.png");
progress_bar.sprite = Sprite();
progress_bar.x = progress_box.x + 2;
progress_bar.y = progress_box.y + 2;

fun progress_callback(duration, progress) {
    if (progress_bar.original_image.GetWidth() > 0) {
        progress_bar.image = progress_bar.original_image.Scale(
            progress_bar.original_image.GetWidth() * progress,
            progress_bar.original_image.GetHeight()
        );
        progress_bar.sprite.SetImage(progress_bar.image);
        progress_bar.sprite.SetPosition(progress_bar.x, progress_bar.y, 1);
    }
}
Plymouth.SetBootProgressFunction(progress_callback);

# Spinner animation
spinner_count = 0;
fun refresh_callback() {
    spinner_count++;
}
Plymouth.SetRefreshFunction(refresh_callback);

# Password prompt for encrypted disks
fun display_password_callback(prompt, bullets) {
    # Minimal password prompt implementation
    global.password_prompt;
    password_prompt.image = Image.Text(prompt, 0.89, 0.89, 0.94); # #E2E8F0
    password_prompt.sprite = Sprite(password_prompt.image);
    password_prompt.sprite.SetX(Window.GetWidth() / 2 - password_prompt.image.GetWidth() / 2);
    password_prompt.sprite.SetY(Window.GetHeight() / 2 + 100);
}
Plymouth.SetDisplayPasswordFunction(display_password_callback);

# Message display
fun message_callback(text) {
    global.message;
    message.image = Image.Text(text, 0.89, 0.89, 0.94); # #E2E8F0
    message.sprite = Sprite(message.image);
    message.sprite.SetX(Window.GetWidth() / 2 - message.image.GetWidth() / 2);
    message.sprite.SetY(Window.GetHeight() - 50);
}
Plymouth.SetMessageFunction(message_callback);

# Quit callback
fun quit_callback() {
    logo.sprite.SetOpacity(0);
}
Plymouth.SetQuitFunction(quit_callback);
SCRIPT_EOF

    # Set Plymouth theme
    if command -v plymouth-set-default-theme &>/dev/null; then
        plymouth-set-default-theme satasos
    fi
    if command -v update-alternatives &>/dev/null; then
        update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
            /usr/share/plymouth/themes/satasos/satasos.plymouth 200 2>/dev/null || true
    fi

    # GRUB configuration
    cat > /etc/default/grub << 'EOF'
# SatasOS GRUB Configuration
GRUB_DEFAULT=0
GRUB_TIMEOUT=10
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR="SatasOS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD=keep
GRUB_BACKGROUND="/usr/share/satasos/grub-bg.png"
GRUB_THEME="/usr/share/grub/themes/satasos/theme.txt"
GRUB_DISABLE_OS_PROBER=false
EOF

    # GRUB theme directory
    mkdir -p /usr/share/grub/themes/satasos
    cat > /usr/share/grub/themes/satasos/theme.txt << 'EOF'
# SatasOS GRUB Theme
title-text: ""
desktop-image: "background.png"
desktop-color: "#1E1B2E"
terminal-font: "Unifont Regular 16"
terminal-left: "0"
terminal-top: "0"
terminal-width: "100%"
terminal-height: "100%"

+ boot_menu {
    left = 30%
    top = 30%
    width = 40%
    height = 40%
    item_font = "Unifont Regular 16"
    item_color = "#E2E8F0"
    selected_item_font = "Unifont Regular 16"
    selected_item_color = "#FFFFFF"
    item_height = 32
    item_padding = 8
    item_spacing = 4
    selected_item_pixmap_style = "select_*.png"
    icon_width = 32
    icon_height = 32
}

+ label {
    left = 30%
    top = 75%
    width = 40%
    align = "center"
    id = "__timeout__"
    text = "Booting in %d seconds..."
    color = "#A78BFA"
    font = "Unifont Regular 14"
}
EOF

    # GDM custom configuration
    mkdir -p /etc/gdm3
    cat > /etc/gdm3/custom.conf << 'EOF'
# SatasOS GDM Configuration
[daemon]
WaylandEnable=true
AutomaticLoginEnable=false

[security]

[xdmcp]

[chooser]

[debug]
EOF

    # GDM CSS theme
    mkdir -p /usr/share/gnome-shell/theme
    cat > /usr/share/gnome-shell/theme/gdm-satasos.css << 'EOF'
/* SatasOS GDM Login Screen Theme */
#lockDialogGroup {
    background: #1E1B2E;
    background-size: cover;
}

.login-dialog {
    background-color: rgba(30, 27, 46, 0.85);
    border: 1px solid rgba(124, 58, 237, 0.3);
    border-radius: 16px;
    padding: 24px;
}

.login-dialog .modal-dialog-button {
    background-color: #7C3AED;
    color: #FFFFFF;
    border-radius: 8px;
    padding: 8px 16px;
}

.login-dialog .modal-dialog-button:hover {
    background-color: #6D28D9;
}

.login-dialog .modal-dialog-button:active {
    background-color: #5B21B6;
}

.login-dialog-prompt-entry {
    background-color: rgba(255, 255, 255, 0.1);
    color: #E2E8F0;
    border: 1px solid rgba(124, 58, 237, 0.5);
    border-radius: 8px;
    padding: 8px 12px;
}
EOF

    log_step "Branding setup complete."
}

# =============================================================================
# Phase 5: Configure Auto-Login for Live Session
# =============================================================================
configure_live_session() {
    log_step "Configuring live session..."

    # Casper configuration for live session
    mkdir -p /etc/casper.conf.d
    cat > /etc/casper.conf << 'EOF'
# SatasOS Casper Configuration
export USERNAME="satasos"
export USERFULLNAME="SatasOS Live User"
export HOST="satasos"
export BUILD_SYSTEM="Ubuntu"
export FLAVOUR="SatasOS"

# Disable hibernation in live mode
export DISABLE_HIBERNATION="yes"
EOF

    # Auto-login configuration for live session (GDM)
    mkdir -p /etc/gdm3
    cat > /etc/gdm3/custom.conf << 'EOF'
# SatasOS GDM Configuration (Live Session)
[daemon]
WaylandEnable=true
AutomaticLoginEnable=true
AutomaticLogin=satasos
TimedLoginEnable=true
TimedLogin=satasos
TimedLoginDelay=5

[security]

[xdmcp]

[chooser]

[debug]
EOF

    # Create live session autostart entries
    mkdir -p /etc/skel/.config/autostart

    # Welcome app autostart
    cat > /etc/skel/.config/autostart/satasos-welcome.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=SatasOS Welcome
Comment=Welcome to SatasOS
Exec=/usr/bin/satasos-welcome
Icon=satasos-logo
Terminal=false
StartupNotify=true
X-GNOME-Autostart-enabled=true
OnlyShowIn=GNOME;
EOF

    # NetworkManager autostart
    cat > /etc/skel/.config/autostart/nm-applet.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Network Manager Applet
Exec=nm-applet
Icon=network-wireless
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF

    # Create a simple welcome script
    mkdir -p /usr/bin
    cat > /usr/bin/satasos-welcome << 'WELCOME_EOF'
#!/bin/bash
# SatasOS Welcome Dialog
# Shows a simple welcome message using zenity for the live session

if command -v zenity &>/dev/null; then
    zenity --info \
        --title="Welcome to SatasOS 1.0" \
        --text="<big><b>Welcome to SatasOS!</b></big>\n\nSatasOS combines the best of Ubuntu, Windows, and Android into one beautiful desktop experience.\n\n• <b>Browse the web</b> with Chrome, Firefox, Edge, or Opera\n• <b>Run Android apps</b> via Waydroid\n• <b>Develop</b> with VS Code and built-in dev tools\n• <b>Create</b> with GIMP, Inkscape, and OBS Studio\n\nTo install SatasOS permanently, click the <b>Install SatasOS</b> icon on your desktop.\n\nEnjoy!" \
        --width=500 \
        --ok-label="Get Started" \
        --window-icon=/usr/share/satasos/icons/satasos-logo.png 2>/dev/null
fi
WELCOME_EOF
    chmod +x /usr/bin/satasos-welcome

    # Set up PolicyKit rules for live session
    mkdir -p /etc/polkit-1/localauthority/50-local.d
    cat > /etc/polkit-1/localauthority/50-local.d/satasos-live.pkla << 'EOF'
[SatasOS Live Session Permissions]
Identity=unix-user:satasos
Action=*
ResultActive=yes
ResultInactive=no
ResultAny=no
EOF

    # Sudoers for live user (passwordless sudo)
    cat > /etc/sudoers.d/satasos-live << 'EOF'
# SatasOS live session - allow passwordless sudo
satasos ALL=(ALL) NOPASSWD: ALL
EOF
    chmod 440 /etc/sudoers.d/satasos-live

    # Configure locale
    locale-gen en_US.UTF-8 || true
    update-locale LANG=en_US.UTF-8 || true

    # Set timezone to UTC for live session (user will set during install)
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime || true

    log_step "Live session configuration complete."
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    log_step "Starting SatasOS chroot setup..."
    log_step "Version: ${SATASOS_VERSION} (${SATASOS_CODENAME})"

    setup_repositories
    setup_user_defaults
    configure_desktop_defaults
    setup_branding
    configure_live_session

    log_step "Chroot setup complete!"
}

main "$@"
