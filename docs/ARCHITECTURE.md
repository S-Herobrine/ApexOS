# SatasOS System Architecture

## 1. Overview & Vision
**SatasOS** is a revolutionary operating system designed to eliminate platform boundaries by combining the power, stability, and command-line versatility of **Ubuntu Linux**, the intuitive productivity, window management, and familiar desktop layout of **Microsoft Windows 11**, and the mobile agility, notifications, touch interaction, and Android app ecosystem powered by **Android 14 / Waydroid**.

```
+-------------------------------------------------------------------------------+
|                                  USER SPACE                                   |
|                                                                               |
|  +--------------------+  +----------------------+  +-----------------------+  |
|  | Windows Ecosystem  |  | Ubuntu Linux System  |  |   Android Subsystem   |  |
|  | - Start Menu       |  | - GNOME Core Stack   |  | - Waydroid LXC Envr   |  |
|  | - Centered Taskbar |  | - APT / DPKG         |  | - Google Play Store   |  |
|  | - SatasOS Files    |  | - Bash / Zsh / Tilix |  | - Play Services (GMS) |  |
|  | - Windows Tweaks   |  | - Snap / Flatpak     |  | - APK Sideloading     |  |
|  | - Rainmeter Widgets|  | - Systemd Services   |  | - Notification Sync   |  |
|  +--------------------+  +----------------------+  +-----------------------+  |
|                                                                               |
|  +-------------------------------------------------------------------------+  |
|  |                       SatasOS Shell & Desktop                           |  |
|  |   * GNOME 45/46 Custom Extensions (Taskbar, App Drawer, Quick Settings) |  |
|  |   * SatasOS Purple Modern Flat Theme (GTK3 / GTK4 / Libadwaita)        |  |
|  |   * Android Status Bar & Pull-down Shade Integration                    |  |
|  +-------------------------------------------------------------------------+  |
+-------------------------------------------------------------------------------+
|                               COMPOSITOR & DISPLAY                            |
|       Mutter (Wayland / XWayland Compositor) + PipeWire Audio + Mesa 3D       |
+-------------------------------------------------------------------------------+
|                                 KERNEL & HARDWARE                             |
|       Linux Generic Kernel (6.8+) + Android Ashmem/Binder IPC Modules        |
|       Intel / AMD / NVIDIA DRI GPU drivers + UEFI/SecureBoot Firmware         |
+-------------------------------------------------------------------------------+
```

---

## 2. Platform Blend Architecture

### A. Windows 11 Elements
1. **Centered Taskbar with Fluent Controls (`desktop/taskbar/taskbar.js`)**:
   - Centered pinned and running application icons.
   - Pinned system launchers: Start menu, SatasOS Files (Explorer), Browsers, Android App Drawer, Terminal.
   - Dynamic running badges, active application indicators, thumbnail previews on hover.
   - System tray on the right with network status, battery level, audio volume slider, clock, and quick notification counter.

2. **Start Menu (`desktop/start-menu/startmenu.js`)**:
   - Modern acrylic/flat floating panel with rounded corners.
   - Top universal search bar (searching apps, files, web queries, and Android apps).
   - "Pinned" grid section for favorite apps.
   - "Recommended" section displaying recently opened files and installed apps.
   - Bottom profile panel with username, avatar, settings shortcut, lock screen trigger, and power menu (Sleep, Restart, Shut Down).

3. **SatasOS Files Explorer (`desktop/filemanager/satasos-files.py`)**:
   - Emulates Windows File Explorer with quick access to `C:\` (Root Filesystem `/`), `D:\` (Secondary Drives / `/mnt`), and User Directories (Documents, Downloads, Music, Pictures, Videos).
   - Ribbon/command bar with Cut, Copy, Paste, Rename, Share, Delete, Properties, and New Folder actions.
   - Dual-pane navigation tree with drives and favorites on the left and directory contents on the right.
   - Contextual right-click menus mimicking Windows 11 styling.

4. **Widgets & Tweaks (`scripts/satasos-widgets.py` & `scripts/satasos-tweaks.py`)**:
   - **SatasOS Widgets (Rainmeter-like)**: Floating desktop gadgets showing live CPU/RAM usage, clock/calendar, weather forecast, quick notes, and media playback controls.
   - **SatasOS Tweaks (Windhawk-like)**: In-depth UI personalization allowing users to change taskbar heights, icon centering, blur effects, animation speeds, and window snapping physics.

---

### B. Android 14 Elements
1. **Waydroid Container Architecture (`android/`)**:
   - Native containerized Android environment executing without emulation overhead using LXC (Linux Containers).
   - Direct hardware acceleration via Mesa/virgl and host GPU passthrough.
   - Real-time Android Binder IPC kernel modules loaded dynamically.
   - Full integration with **Google Play Store**, **Google Play Services (GMS)**, and Google Services Framework.

2. **Android App Drawer (`desktop/app-drawer/appdrawer.js`)**:
   - Full-screen or overlay app grid styled after Android 14 Material You.
   - Smooth gesture support: swipe up or click the launcher icon to access all installed Linux desktop applications and native Android APKs.
   - Categorized tabs: *All Apps*, *Productivity*, *Internet*, *Multimedia*, *Games*, *Android Apps*.

3. **Android Quick Settings & Notification Shade (`desktop/notification-center/notifications.js`)**:
   - Top-down pull shade or top-right click trigger.
   - Large pill-shaped quick setting toggles for Wi-Fi, Bluetooth, Airplane Mode, Dark/Light Mode, Do Not Disturb, Screen Recording, and Hotspot.
   - Brightness and volume sliders with interactive tactile feedback.
   - Unified notification stream grouping Linux desktop notifications and Android system notifications with interactive action buttons (Reply, Dismiss, Mark Read).

4. **Android Lock Screen (`desktop/lockscreen/lockscreen.js`)**:
   - Clean lock interface featuring large ambient digital clock and date typography.
   - Support for PIN numpad entry, swipe-to-unlock, or password authentication.
   - Quick bottom shortcuts for emergency calls, camera, and flashlight.

---

### C. Ubuntu Linux Foundation
1. **Reliability and Package Management**:
   - Ubuntu 24.04 LTS (Noble Numbat) core with 5+ years of enterprise security maintenance.
   - Hybrid package management: Native APT/DPKG, Snap support, Flatpak/Flathub support, and Android APK installation via Waydroid.
2. **Terminal & Developer Experience**:
   - Pre-configured `gnome-terminal` and `tilix` with Zsh/Bash, syntax highlighting, autocompletion, and JetBrains Mono fonts.
   - Pre-installed developer toolchains: Git, Python 3, Node.js, GCC/G++, Make, Docker, and Visual Studio Code.
3. **Audio, Video & Hardware Support**:
   - PipeWire and WirePlumber for low-latency unified audio management between Linux and Android containers.
   - Modern Wayland compositor (Mutter) with fallback to XWayland for legacy Windows and Linux applications.

---

## 3. Theming & Design System

- **Color Palette**:
  - `Accent Primary`: `#7C3AED` (SatasOS Royal Purple)
  - `Accent Hover`: `#6D28D9`
  - `Accent Active`: `#5B21B6`
  - `Dark Background`: `#1E1B2E`
  - `Dark Surface / Panel`: `#2D2640`
  - `Dark Cards`: `#362E50`
  - `Light Background`: `#F5F0FF`
  - `Light Surface`: `#FFFFFF`
  - `Light Cards`: `#EDE5FF`
  - `Status Success`: `#10B981`
  - `Status Danger`: `#EF4444`
  - `Status Warning`: `#F59E0B`
  - `Status Info`: `#3B82F6`

- **Typography**:
  - UI Font: *Inter*, *Segoe UI*, or *Roboto*
  - Monospace Font: *JetBrains Mono* / *Ubuntu Mono*

- **Visual Physics**:
  - Border radius: 12px for standard cards and popups, 24px for pills and quick toggles.
  - Backdrop blur filter on acrylic surfaces.
  - Soft drop shadows: `0 8px 32px rgba(0, 0, 0, 0.35)`.
