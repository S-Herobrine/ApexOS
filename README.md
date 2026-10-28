# ApexOS (Low-End PC Edition)

<p align="center">
  <img src="branding/logo.svg" alt="ApexOS Logo" width="140" height="140">
</p>

<h3 align="center">
  <b>The Unified Operating System for Everyone</b><br>
  Ubuntu Linux Stability + Windows 11 Fluent Desktop + Android 14 App Ecosystem
</h3>

<p align="center">
  <b>Specially Optimized for Low-End PCs: 4 GB RAM & 14-16 GB Storage</b><br>
  <i>Sub-450MB Idle RAM &bull; Compressed zRAM Memory &bull; Sub-2GB ISO Image &bull; 100% Free & Open Source</i>
</p>

---

## ⚡ What is ApexOS?

**ApexOS** (formerly SatanOS/SatasOS) combines the best capabilities of three distinct software universes into a single, cohesive, ultra-lightweight operating system:

1. **Windows 11 Experience**:
   - Centered fluent taskbar with live running indicators, thumbnail previews, and system tray.
   - Acrylic/flat Start Menu with universal search (apps, files, Android APKs, web).
   - **ApexOS Files** (Explorer) featuring familiar `C:\` and `D:\` drive paths and dual-pane navigation.
   - Windows 11 window snapping (`Super + Arrow Keys`).
   - Personalization tools: **ApexOS Tweaks** (Windhawk-style) & **ApexOS Widgets** (Rainmeter-style).

2. **Android 14 Experience**:
   - Native containerized Android subsystem powered by **Waydroid** with GPU acceleration.
   - **Google Play Store**, Google Play Services (GMS), and MicroG low-memory architecture.
   - Android-style full-screen **App Drawer** with categorized tabs.
   - Slide-down **Quick Settings & Notification Shade** with interactive pills.
   - Android-style ambient **Lock Screen** with PIN and swipe unlock.

3. **Ubuntu Linux Enterprise Core**:
   - Modern Ubuntu 24.04 LTS (Noble Numbat) foundation with 5+ years of security updates.
   - Dual terminal experience: Linux Bash/Zsh power terminal + PowerShell console compatibility.
   - Native APT, Snap, Flatpak, and direct Android APK sideloading.
   - PipeWire audio and low-latency Wayland compositor.

---

## 🚀 Low-End PC Special Optimizations

ApexOS is meticulously engineered to run smoothly on budget laptops and older desktops with **4 GB RAM** and **14–16 GB of storage**:

| Feature | Standard OS (Ubuntu/Win11) | ApexOS Low-End Edition |
|---|---|---|
| **Idle RAM Consumption** | 1,500 MB – 2,800 MB | **~380 MB – 450 MB** |
| **Usable Free RAM on 4GB** | Less than 1.5 GB | **Over 3.5 GB free for apps** |
| **Virtual Memory Technology** | Slow disk swap paging | **zRAM (LZ4 compressed RAM swap)** |
| **Minimum Disk Install Size** | 25 GB – 40 GB | **4.8 GB – 6.0 GB** |
| **Download ISO Size** | 4.5 GB – 6.0 GB | **~1.8 GB – 2.1 GB** |
| **Storage Remaining on 16GB Drive** | 0 GB (Full/Failure) | **~10 GB free space for user files** |
| **Browser Memory Saver** | Default memory consumption | Aggressive idle tab suspension |

---

## 📦 Selectable Web Browsers & Pre-Installed Apps

During setup via the Calamares installer, you can choose your preferred browser:
- **Google Chrome** (Google ecosystem sync)
- **Mozilla Firefox** (Enhanced tracking protection & privacy)
- **Microsoft Edge** (Vertical tabs & Copilot integration)
- **Opera** (Built-in free VPN & sidebar messengers)

### Key Pre-Installed Applications:
- **Android Subsystem**: Google Play Store, Play Services, ApexOS Android Manager, APK Installer.
- **Productivity**: LibreOffice Suite (Writer, Calc, Impress), ApexOS Files, PDF Viewer.
- **Creativity & Media**: VLC Media Player, GIMP Photo Retouching, Amberol Audio Player.
- **Development**: Visual Studio Code, GNOME Terminal, Tilix Tiling Shell, Git, Python 3, Node.js.
- **Customization**: ApexOS Widgets (Rainmeter-like), ApexOS Tweaks (Windhawk-like), Dark/Light Theme Switcher.

---

## 🎨 Brand & Design System

- **Primary Accent**: `#7C3AED` (Apex Royal Purple)
- **Primary Hover**: `#6D28D9`
- **Dark Mode Background**: `#1E1B2E` (Obsidian Purple)
- **Dark Mode Surface**: `#2D2640`
- **Light Mode Background**: `#F5F0FF` (Lavender Mist)
- **Light Mode Surface**: `#FFFFFF`
- **Typography**: Inter (UI font), JetBrains Mono (Terminal font)

---

## 🛠️ Building the ISO (For Low-End Hardware)

The build system is designed to build inside modest resources:

```bash
# Clone the repository
git clone https://github.com/ApexOS/ApexOS.git
cd ApexOS

# Install minimal build dependencies
sudo make install-deps

# Build the ultra-compact Low-End PC ISO
sudo bash build/build-iso-lowend.sh
```

Output:
```
build/output/ApexOS-1.0-lowend-amd64.iso (approx. 1.9 GB)
```

---

## 📄 License

ApexOS is free software licensed under the **GNU General Public License v3 (GPL-3.0)**.
