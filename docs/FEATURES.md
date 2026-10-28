# SatasOS Comprehensive Feature Reference

SatasOS brings together the best user interface, productivity tools, and operating paradigms from Windows, Android, and Ubuntu Linux into a unified experience.

---

## 1. Windows 11 Inspired Features

### Centered Modern Taskbar
- Centered application dock featuring quick pin/unpin toggles.
- Dynamic indicator dots showing running instances.
- Hover window thumbnail previews with close buttons.
- System tray on the bottom right:
  - Network & Wi-Fi indicator with interactive connection popup.
  - PipeWire audio volume slider and output selector.
  - Battery percentage and power management profile switch.
  - Digital clock with integrated calendar flyout.
  - Notification counter pill.

### Windows-Style Start Menu
- Centered floating modal accessible via `Super` (Windows) key or Start button.
- Instant universal search:
  - Searches native Linux desktop apps.
  - Searches installed Android APKs.
  - Searches local files and documents.
  - Web query shortcuts.
- "Pinned Apps" grid with drag-and-drop customization.
- "Recent Files & Activity" feed.
- User profile banner with quick switch, lock screen, and power controls.

### SatasOS Files (Explorer)
- Familiar drive letters:
  - `C:\` maps directly to Root filesystem (`/`).
  - `D:\` maps to secondary partitions or mounted disks (`/mnt`, `/media`).
  - `Home:\` maps to user directory (`/home/username`).
- Windows-style navigation sidebar with standard directories: Desktop, Downloads, Documents, Pictures, Music, Videos.
- Ribbon toolbar with Cut, Copy, Paste, Delete, Properties, Share, and New Folder buttons.
- Tabbed browsing for multiple open directories.
- Full right-click context menu (Open With, Extract, Compress, Run in Terminal).

### Windows Productivity & Tweaking
- **Window Snapping**: Snap windows to Left 50%, Right 50%, Top 50%, or 4 corner quadrants using `Super + Arrow Keys` or dragging to screen edges.
- **SatasOS Tweaks (Windhawk counterpart)**: Fine-grained personalization app allowing custom animation curves, taskbar height adjustments, transparency blur levels, and custom titlebar styling.
- **SatasOS Widgets (Rainmeter counterpart)**: Desktop widget manager providing sleek, floating desktop clocks, live system monitors, weather forecasts, and calendar feeds.

---

## 2. Android 14 Inspired Features

### Material You & Purple Accent Theme
- Responsive color palette based on SatasOS Royal Purple (`#7C3AED`) and deep obsidian tones (`#1E1B2E`).
- Unified light and dark modes with a single toggle switch in the quick panel.

### Android App Drawer
- Full-screen or floating grid containing all installed Linux and Android applications.
- Swipe up from the bottom taskbar or click the App Drawer icon to trigger.
- Categorized view tabs:
  - All Apps
  - Internet & Communication
  - Media & Graphics
  - Developer Tools
  - Android APKs & Games

### Android Quick Settings & Notification Shade
- Slide-down notification center from top or top-right click.
- Tactile quick setting pills:
  - Wi-Fi, Bluetooth, Airplane Mode.
  - Dark / Light Mode instant switch.
  - Do Not Disturb (DND) toggle.
  - Night Light (blue light filter) slider.
  - Master volume and brightness sliders.
- Interactive notification cards with inline reply, dismissal swipe, and action triggers.

### Native Android Subsystem (Waydroid)
- Native container execution of Android 13/14 without emulation penalty.
- Direct 3D hardware acceleration via Mesa/virgl GPU passthrough.
- Pre-installed **Google Play Store**, **Google Play Services**, and GMS Framework.
- Multi-window mode: Android apps run as native desktop windows alongside Linux apps.
- Full clipboard synchronization and bidirectional file sharing between Linux and Android containers.

### Android-Style Lock Screen
- Large ambient typography displaying time, day, and weather.
- Dual unlock options: PIN keypad numpad or password.
- Quick lock screen shortcuts for emergency contact and camera.

---

## 3. Ubuntu Linux Core Features

### Enterprise Stability & Kernel Power
- Built on Ubuntu 24.04 LTS (Noble Numbat) with Linux 6.8+ generic kernel.
- Extensive driver compatibility for Intel, AMD, NVIDIA, and Realtek hardware.
- Native Secure Boot and UEFI firmware support.

### Ultimate Developer Terminal Experience
- Dual terminal options:
  - **Linux Terminal (`gnome-terminal` / `tilix`)**: Pre-configured with Zsh, Oh-My-Zsh styling, syntax highlighting, autocompletion, and Git status prompt.
  - **PowerShell / Windows-style console command support**: Supports cross-platform PowerShell (`pwsh`) alongside standard Bash.
- Pre-loaded developer toolchain: Git, Python 3, Node.js, Build Essential (gcc, g++, make), Docker, and VS Code.

### Universal Package Management
- Native **APT** package manager (`apt install ...`).
- **Snap** support for sandboxed modern desktop software.
- **Flatpak & Flathub** out of the box.
- Direct **APK sideloading** via SatasOS Android Manager.

---

## 4. Keyboard Shortcuts & Gestures

| Action | Shortcut / Gesture |
|---|---|
| Open Start Menu | `Super` (Windows Key) |
| Open Android App Drawer | `Super + A` or Swipe Up from Taskbar |
| Open Notification Shade / Quick Settings | `Super + N` or Pull down from top edge |
| Open SatasOS Files (Explorer) | `Super + E` |
| Open Terminal | `Ctrl + Alt + T` or `Super + T` |
| Open SatasOS Settings | `Super + I` |
| Open SatasOS Tweaks | `Super + Shift + T` |
| Open SatasOS Widgets Gallery | `Super + W` |
| Lock Screen | `Super + L` |
| Snap Window Left / Right | `Super + Left Arrow` / `Super + Right Arrow` |
| Maximize / Restore Window | `Super + Up Arrow` / `Super + Down Arrow` |
| Switch Open Apps | `Alt + Tab` |
| Toggle Dark / Light Mode | `Super + Shift + D` |
