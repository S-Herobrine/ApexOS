# Contributing to SatasOS

Thank you for your interest in contributing to **SatasOS**! We welcome community contributions to build the ultimate unified OS experience combining Ubuntu Linux, Windows, and Android.

---

## 1. Code of Conduct
SatasOS is dedicated to providing a welcoming, inclusive, and harassment-free environment for everyone, regardless of background, gender, sexual orientation, disability, physical appearance, race, or religion.

---

## 2. Ways to Contribute

- **Desktop Shell & Extensions**: Improve the GNOME Shell extension (`desktop/shell/satasos-shell/`), taskbar, start menu, or notification center.
- **Themes & UI Polish**: Refine GTK3, GTK4, Libadwaita, and GNOME Shell CSS styling to maintain consistent modern purple-dark and light palettes.
- **Android Integration**: Enhance Waydroid container stability, hardware GPU passthrough, Google Play Services setup scripts, and app lifecycle managers.
- **App Development**: Contribute to SatasOS Files (Explorer), SatasOS Settings, SatasOS Widgets, or SatasOS Tweaks.
- **Testing & ISO Verification**: Test ISO builds on diverse hardware (Intel, AMD, NVIDIA, ARM64) and report bugs.
- **Documentation & Localization**: Translate SatasOS into multiple languages and expand user guides.

---

## 3. Development Workflow

1. **Fork the Repository**:
   Fork the repository on GitHub and clone it locally:
   ```bash
   git clone https://github.com/your-username/SatasOS.git
   cd SatasOS
   ```

2. **Create a Feature Branch**:
   Use descriptive branch names:
   ```bash
   git checkout -b feature/android-intent-bridge
   # or
   git checkout -b fix/taskbar-centering-glitch
   ```

3. **Coding Standards**:
   - **Shell Scripts**: Must include `#!/bin/bash` and `set -euo pipefail` where applicable. Use 4-space indentation.
   - **Python Scripts (GTK4)**: Follow PEP 8 guidelines. Type hints are encouraged.
   - **JavaScript / GJS**: Use modern ECMAScript standard supported by GNOME 45/46. Follow camelCase naming conventions.
   - **CSS / Themes**: Keep selectors modular and document color variables at the top of the file.

4. **Testing Your Changes**:
   - Run localized tests or scripts.
   - Test extensions locally by symlinking to `~/.local/share/gnome-shell/extensions/satasos-shell@satasos.org`.
   - Re-run `make test` before submitting.

5. **Commit Messages**:
   Follow conventional commits format:
   ```
   feat(taskbar): add multi-monitor indicator support
   fix(waydroid): resolve audio latency on PipeWire bridge
   docs(build): update QEMU boot flags for hardware GL
   ```

6. **Submit a Pull Request**:
   Push your branch and open a PR against `main`. Provide a clear description of the problem solved and test results.
