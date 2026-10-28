// SatasOS Taskbar - Windows 11 Style
// GNOME 45+ ESM Import Style

import St from 'gi://St';
import Clutter from 'gi://Clutter';
import Shell from 'gi://Shell';
import Meta from 'gi://Meta';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Gio from 'gi://Gio';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const TASKBAR_HEIGHT = 48;
const ICON_SIZE = 32;
const BUTTON_SIZE = 44;
const PREVIEW_WIDTH = 240;
const PREVIEW_HEIGHT = 160;
const BRAND_PRIMARY = '#7C3AED';
const BRAND_HOVER = '#6D28D9';
const BRAND_ACTIVE = '#5B21B6';
const DARK_BG = '#1E1B2E';
const DARK_SURFACE = '#2D2640';
const LIGHT_TEXT = '#E8E0F0';
const BOUNCE_DURATION = 600;
const CLOCK_UPDATE_INTERVAL = 1000;

// ─── TaskbarButton ───────────────────────────────────────────────────────────

const TaskbarButton = GObject.registerClass(
{
    Signals: {
        'app-activated': {},
    },
},
class TaskbarButton extends St.Button {
    _init(app, window = null) {
        super._init({
            style_class: 'taskbar-button',
            reactive: true,
            can_focus: true,
            track_hover: true,
            style: `
                width: ${BUTTON_SIZE}px;
                height: ${BUTTON_SIZE}px;
                border-radius: 8px;
                margin: 0 2px;
                padding: 0;
                background-color: transparent;
                transition-duration: 150ms;
            `,
        });

        this._app = app;
        this._window = window;
        this._previewActor = null;
        this._previewTimeout = null;
        this._isBouncing = false;
        this._indicatorDot = null;

        this._icon = app.create_icon_texture(ICON_SIZE);
        this._icon.set({
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this.set_child(this._icon);

        this._buildIndicatorDot();

        this.connect('notify::hover', this._onHoverChanged.bind(this));
        this.connect('clicked', this._onClicked.bind(this));
        this.connect('destroy', this._onDestroy.bind(this));
    }

    _buildIndicatorDot() {
        this._indicatorDot = new St.Widget({
            style: `
                width: 6px;
                height: 6px;
                border-radius: 3px;
                background-color: ${BRAND_PRIMARY};
            `,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.END,
        });
        this.add_child(this._indicatorDot);
        this._updateIndicator();
    }

    _updateIndicator() {
        if (!this._indicatorDot) return;

        const tracker = Shell.WindowTracker.get_default();
        const isRunning = this._app.get_state() === Shell.AppState.RUNNING;
        const isFocused = tracker.focus_app === this._app;

        this._indicatorDot.visible = isRunning;
        if (isFocused) {
            this._indicatorDot.style = `
                width: 16px;
                height: 3px;
                border-radius: 2px;
                background-color: ${BRAND_PRIMARY};
            `;
            this.style = `
                width: ${BUTTON_SIZE}px;
                height: ${BUTTON_SIZE}px;
                border-radius: 8px;
                margin: 0 2px;
                padding: 0;
                background-color: ${DARK_SURFACE};
                transition-duration: 150ms;
            `;
        } else {
            this._indicatorDot.style = `
                width: 6px;
                height: 6px;
                border-radius: 3px;
                background-color: ${BRAND_PRIMARY};
            `;
            this.style = `
                width: ${BUTTON_SIZE}px;
                height: ${BUTTON_SIZE}px;
                border-radius: 8px;
                margin: 0 2px;
                padding: 0;
                background-color: transparent;
                transition-duration: 150ms;
            `;
        }
    }

    _onHoverChanged() {
        if (this.hover) {
            if (!this._isBouncing) {
                this.style = this.style.replace(
                    /background-color: [^;]+/,
                    `background-color: ${DARK_SURFACE}`
                );
            }
            this._previewTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 400, () => {
                this._showPreview();
                this._previewTimeout = null;
                return GLib.SOURCE_REMOVE;
            });
        } else {
            if (this._previewTimeout) {
                GLib.source_remove(this._previewTimeout);
                this._previewTimeout = null;
            }
            this._hidePreview();
            this._updateIndicator();
        }
    }

    _showPreview() {
        if (this._previewActor) return;

        const windows = this._app.get_windows();
        if (windows.length === 0) return;

        this._previewActor = new St.Widget({
            style: `
                background-color: ${DARK_SURFACE};
                border-radius: 12px;
                padding: 8px;
                border: 1px solid rgba(124, 58, 237, 0.3);
            `,
            reactive: true,
            layout_manager: new Clutter.BoxLayout({
                orientation: Clutter.Orientation.VERTICAL,
                spacing: 6,
            }),
        });

        for (const win of windows) {
            const previewContainer = new St.Widget({
                style: `
                    background-color: rgba(0, 0, 0, 0.2);
                    border-radius: 8px;
                    padding: 4px;
                `,
                layout_manager: new Clutter.BoxLayout({
                    orientation: Clutter.Orientation.VERTICAL,
                    spacing: 4,
                }),
            });

            const titleBar = new St.BoxLayout({
                style: 'padding: 4px 8px;',
            });

            const titleLabel = new St.Label({
                text: win.get_title() || this._app.get_name(),
                style: `
                    color: ${LIGHT_TEXT};
                    font-size: 11px;
                    font-weight: 500;
                `,
                x_expand: true,
                y_align: Clutter.ActorAlign.CENTER,
            });
            titleLabel.clutter_text.set_ellipsize(3); // PANGO_ELLIPSIZE_END

            const closeBtn = new St.Button({
                style: `
                    width: 18px;
                    height: 18px;
                    border-radius: 9px;
                    background-color: rgba(255, 255, 255, 0.1);
                `,
                label: '✕',
                reactive: true,
            });
            closeBtn.connect('clicked', () => {
                win.delete(global.get_current_time());
                this._hidePreview();
            });

            titleBar.add_child(titleLabel);
            titleBar.add_child(closeBtn);
            previewContainer.add_child(titleBar);

            const windowTexture = win.get_compositor_private();
            if (windowTexture) {
                const clone = new Clutter.Clone({
                    source: windowTexture,
                    width: PREVIEW_WIDTH,
                    height: PREVIEW_HEIGHT,
                    x_align: Clutter.ActorAlign.CENTER,
                });
                const cloneContainer = new St.Widget({
                    style: 'border-radius: 4px;',
                    width: PREVIEW_WIDTH,
                    height: PREVIEW_HEIGHT,
                });
                cloneContainer.add_child(clone);
                previewContainer.add_child(cloneContainer);
            }

            const clickAction = new Clutter.ClickAction();
            clickAction.connect('clicked', () => {
                this._activateWindow(win);
                this._hidePreview();
            });
            previewContainer.add_action(clickAction);

            this._previewActor.add_child(previewContainer);
        }

        Main.layoutManager.addTopChrome(this._previewActor);

        const [buttonX, buttonY] = this.get_transformed_position();
        const previewX = Math.max(0, buttonX - PREVIEW_WIDTH / 2 + BUTTON_SIZE / 2);
        const monitor = Main.layoutManager.primaryMonitor;
        const previewY = monitor.height - TASKBAR_HEIGHT - this._previewActor.height - 8;

        this._previewActor.set_position(previewX, previewY);
        this._previewActor.opacity = 0;
        this._previewActor.ease({
            opacity: 255,
            duration: 200,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
        });
    }

    _hidePreview() {
        if (!this._previewActor) return;

        const preview = this._previewActor;
        this._previewActor = null;
        preview.ease({
            opacity: 0,
            duration: 150,
            mode: Clutter.AnimationMode.EASE_IN_QUAD,
            onComplete: () => {
                Main.layoutManager.removeChrome(preview);
                preview.destroy();
            },
        });
    }

    _activateWindow(win) {
        if (win.has_focus()) {
            win.minimize();
        } else {
            win.activate(global.get_current_time());
        }
    }

    _onClicked() {
        const windows = this._app.get_windows();
        if (windows.length > 0) {
            const focused = windows.find(w => w.has_focus());
            if (focused) {
                focused.minimize();
            } else {
                windows[0].activate(global.get_current_time());
            }
        } else {
            this._app.open_new_window(-1);
            this.animateBounce();
        }
        this.emit('app-activated');
    }

    animateBounce() {
        if (this._isBouncing) return;
        this._isBouncing = true;

        const originalY = this._icon.translation_y;
        const bounceSteps = [
            { y: -8, duration: BOUNCE_DURATION / 4 },
            { y: 0, duration: BOUNCE_DURATION / 4 },
            { y: -4, duration: BOUNCE_DURATION / 4 },
            { y: 0, duration: BOUNCE_DURATION / 4 },
        ];

        let stepIndex = 0;
        const doStep = () => {
            if (stepIndex >= bounceSteps.length) {
                this._isBouncing = false;
                return;
            }
            const step = bounceSteps[stepIndex];
            stepIndex++;
            this._icon.ease({
                translation_y: step.y,
                duration: step.duration,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                onComplete: doStep,
            });
        };
        doStep();
    }

    refresh() {
        this._updateIndicator();
    }

    _onDestroy() {
        if (this._previewTimeout) {
            GLib.source_remove(this._previewTimeout);
            this._previewTimeout = null;
        }
        this._hidePreview();
    }
});

// ─── StartButton ─────────────────────────────────────────────────────────────

const StartButton = GObject.registerClass(
{
    Signals: {
        'start-menu-toggle': {},
    },
},
class StartButton extends St.Button {
    _init() {
        super._init({
            style_class: 'start-button',
            reactive: true,
            can_focus: true,
            track_hover: true,
            style: `
                width: ${BUTTON_SIZE}px;
                height: ${BUTTON_SIZE}px;
                border-radius: 8px;
                margin: 0 4px;
                padding: 0;
                background-color: transparent;
                transition-duration: 200ms;
            `,
        });

        this._icon = new St.Icon({
            icon_name: 'start-here-symbolic',
            icon_size: 24,
            style: `color: ${BRAND_PRIMARY};`,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this.set_child(this._icon);

        this.connect('notify::hover', () => {
            this.style = `
                width: ${BUTTON_SIZE}px;
                height: ${BUTTON_SIZE}px;
                border-radius: 8px;
                margin: 0 4px;
                padding: 0;
                background-color: ${this.hover ? DARK_SURFACE : 'transparent'};
                transition-duration: 200ms;
            `;
        });

        this.connect('clicked', () => {
            this.emit('start-menu-toggle');
        });
    }
});

// ─── SystemTray ──────────────────────────────────────────────────────────────

const SystemTray = GObject.registerClass(
class SystemTray extends St.BoxLayout {
    _init() {
        super._init({
            style_class: 'system-tray',
            style: `
                spacing: 4px;
                padding: 0 8px;
            `,
            x_align: Clutter.ActorAlign.END,
            y_align: Clutter.ActorAlign.CENTER,
        });

        this._clockSource = null;
        this._batteryProxy = null;

        this._buildWifiIndicator();
        this._buildVolumeIndicator();
        this._buildBatteryIndicator();
        this._buildNotificationBell();
        this._buildClock();

        this._startClockUpdates();
        this._monitorBattery();
        this._monitorNetwork();

        this.connect('destroy', this._onDestroy.bind(this));
    }

    _createTrayButton(iconName, tooltip) {
        const btn = new St.Button({
            reactive: true,
            can_focus: true,
            track_hover: true,
            style: `
                width: 36px;
                height: 36px;
                border-radius: 6px;
                padding: 0;
                background-color: transparent;
                transition-duration: 150ms;
            `,
        });

        const icon = new St.Icon({
            icon_name: iconName,
            icon_size: 16,
            style: `color: ${LIGHT_TEXT};`,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
        });
        btn.set_child(icon);
        btn._trayIcon = icon;

        btn.connect('notify::hover', () => {
            btn.style = `
                width: 36px;
                height: 36px;
                border-radius: 6px;
                padding: 0;
                background-color: ${btn.hover ? 'rgba(255,255,255,0.08)' : 'transparent'};
                transition-duration: 150ms;
            `;
        });

        return btn;
    }

    _buildWifiIndicator() {
        this._wifiButton = this._createTrayButton('network-wireless-symbolic', 'Network');
        this._wifiLabel = new St.Label({
            style: `color: ${LIGHT_TEXT}; font-size: 11px;`,
            y_align: Clutter.ActorAlign.CENTER,
            visible: false,
        });
        this.add_child(this._wifiButton);
        this.add_child(this._wifiLabel);
    }

    _buildVolumeIndicator() {
        this._volumeButton = this._createTrayButton('audio-volume-medium-symbolic', 'Volume');
        this._volumeButton.connect('clicked', () => {
            this._cycleVolumeIcon();
        });
        this.add_child(this._volumeButton);
    }

    _buildBatteryIndicator() {
        this._batteryBox = new St.BoxLayout({
            style: 'spacing: 2px;',
            y_align: Clutter.ActorAlign.CENTER,
        });

        this._batteryButton = this._createTrayButton('battery-good-symbolic', 'Battery');
        this._batteryLabel = new St.Label({
            text: '100%',
            style: `color: ${LIGHT_TEXT}; font-size: 11px;`,
            y_align: Clutter.ActorAlign.CENTER,
        });

        this._batteryBox.add_child(this._batteryButton);
        this._batteryBox.add_child(this._batteryLabel);
        this.add_child(this._batteryBox);
    }

    _buildNotificationBell() {
        this._bellButton = this._createTrayButton('preferences-system-notifications-symbolic', 'Notifications');
        this._notificationCount = 0;

        this._bellBadge = new St.Label({
            text: '',
            style: `
                background-color: #EF4444;
                color: white;
                font-size: 9px;
                font-weight: bold;
                border-radius: 8px;
                padding: 1px 4px;
                min-width: 14px;
                text-align: center;
            `,
            visible: false,
            x_align: Clutter.ActorAlign.END,
            y_align: Clutter.ActorAlign.START,
        });
        this._bellButton.add_child(this._bellBadge);

        this._bellButton.connect('clicked', () => {
            this._notificationCount = 0;
            this._bellBadge.visible = false;
            Main.panel.statusArea?.dateMenu?.menu?.toggle();
        });

        this.add_child(this._bellButton);

        this._notifSourceAddedId = Main.messageTray.connect('source-added', () => {
            this._notificationCount++;
            this._bellBadge.text = `${this._notificationCount}`;
            this._bellBadge.visible = true;
        });
    }

    _buildClock() {
        this._clockButton = new St.Button({
            reactive: true,
            can_focus: true,
            track_hover: true,
            style: `
                border-radius: 6px;
                padding: 4px 12px;
                background-color: transparent;
                transition-duration: 150ms;
            `,
        });

        this._clockBox = new St.BoxLayout({
            vertical: true,
            y_align: Clutter.ActorAlign.CENTER,
        });

        this._clockLabel = new St.Label({
            text: '',
            style: `
                color: ${LIGHT_TEXT};
                font-size: 12px;
                font-weight: 500;
                text-align: right;
            `,
            x_align: Clutter.ActorAlign.END,
        });

        this._dateLabel = new St.Label({
            text: '',
            style: `
                color: rgba(232, 224, 240, 0.7);
                font-size: 10px;
                text-align: right;
            `,
            x_align: Clutter.ActorAlign.END,
        });

        this._clockBox.add_child(this._clockLabel);
        this._clockBox.add_child(this._dateLabel);
        this._clockButton.set_child(this._clockBox);

        this._clockButton.connect('notify::hover', () => {
            this._clockButton.style = `
                border-radius: 6px;
                padding: 4px 12px;
                background-color: ${this._clockButton.hover ? 'rgba(255,255,255,0.08)' : 'transparent'};
                transition-duration: 150ms;
            `;
        });

        this._clockButton.connect('clicked', () => {
            Main.panel.statusArea?.dateMenu?.menu?.toggle();
        });

        this.add_child(this._clockButton);
        this._updateClock();
    }

    _startClockUpdates() {
        this._clockSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, CLOCK_UPDATE_INTERVAL, () => {
            this._updateClock();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _updateClock() {
        const now = GLib.DateTime.new_now_local();
        if (!now) return;
        this._clockLabel.text = now.format('%I:%M:%S %p');
        this._dateLabel.text = now.format('%m/%d/%Y');
    }

    _monitorBattery() {
        try {
            const BUS_NAME = 'org.freedesktop.UPower';
            const OBJECT_PATH = '/org/freedesktop/UPower/devices/DisplayDevice';
            const IFACE = 'org.freedesktop.UPower.Device';

            this._batteryProxy = Gio.DBusProxy.new_for_bus_sync(
                Gio.BusType.SYSTEM,
                Gio.DBusProxyFlags.NONE,
                null,
                BUS_NAME,
                OBJECT_PATH,
                IFACE,
                null
            );

            this._batteryProxy.connect('g-properties-changed', () => {
                this._updateBatteryDisplay();
            });
            this._updateBatteryDisplay();
        } catch (e) {
            this._batteryLabel.text = 'N/A';
        }
    }

    _updateBatteryDisplay() {
        if (!this._batteryProxy) return;

        try {
            const percentage = this._batteryProxy.get_cached_property('Percentage');
            const state = this._batteryProxy.get_cached_property('State');

            if (percentage) {
                const pct = percentage.unpack();
                this._batteryLabel.text = `${Math.round(pct)}%`;

                let iconName = 'battery-full-symbolic';
                if (pct <= 10) iconName = 'battery-empty-symbolic';
                else if (pct <= 25) iconName = 'battery-caution-symbolic';
                else if (pct <= 50) iconName = 'battery-low-symbolic';
                else if (pct <= 75) iconName = 'battery-good-symbolic';

                if (state && state.unpack() === 1) {
                    iconName = 'battery-full-charging-symbolic';
                }

                this._batteryButton._trayIcon.icon_name = iconName;
            }
        } catch (e) {
            // battery info unavailable
        }
    }

    _monitorNetwork() {
        try {
            const client = Shell.NetworkAgent?.get_default?.();
            if (client) {
                client.connect('notify::primary-connection', () => {
                    this._updateNetworkIcon();
                });
            }
        } catch (e) {
            // network monitoring unavailable
        }
    }

    _updateNetworkIcon() {
        // Default to wireless connected icon
        this._wifiButton._trayIcon.icon_name = 'network-wireless-symbolic';
    }

    _cycleVolumeIcon() {
        const icons = [
            'audio-volume-muted-symbolic',
            'audio-volume-low-symbolic',
            'audio-volume-medium-symbolic',
            'audio-volume-high-symbolic',
        ];
        const current = this._volumeButton._trayIcon.icon_name;
        const idx = icons.indexOf(current);
        const next = (idx + 1) % icons.length;
        this._volumeButton._trayIcon.icon_name = icons[next];
    }

    addNotification() {
        this._notificationCount++;
        this._bellBadge.text = `${this._notificationCount}`;
        this._bellBadge.visible = true;
    }

    _onDestroy() {
        if (this._clockSource) {
            GLib.source_remove(this._clockSource);
            this._clockSource = null;
        }
        if (this._notifSourceAddedId) {
            Main.messageTray.disconnect(this._notifSourceAddedId);
            this._notifSourceAddedId = null;
        }
    }
});

// ─── TaskbarPanel ────────────────────────────────────────────────────────────

export const TaskbarPanel = GObject.registerClass(
{
    Signals: {
        'start-menu-toggle': {},
    },
},
class TaskbarPanel extends St.Widget {
    _init() {
        const monitor = Main.layoutManager.primaryMonitor;

        super._init({
            name: 'satas-taskbar',
            reactive: true,
            width: monitor.width,
            height: TASKBAR_HEIGHT,
            x: monitor.x,
            y: monitor.y + monitor.height - TASKBAR_HEIGHT,
            style: `
                background-color: ${DARK_BG};
                border-top: 1px solid rgba(124, 58, 237, 0.15);
            `,
        });

        this._appButtons = new Map();
        this._signalIds = [];
        this._pinnedAppIds = [
            'org.gnome.Nautilus.desktop',
            'firefox.desktop',
            'org.gnome.Terminal.desktop',
            'org.gnome.Settings.desktop',
            'org.gnome.TextEditor.desktop',
            'org.gnome.Calculator.desktop',
            'org.gnome.Software.desktop',
            'org.gnome.Evince.desktop',
        ];

        this._buildLayout();
        this._populatePinnedApps();
        this._trackWindows();
        this._connectWorkspaceSignals();

        Main.layoutManager.addTopChrome(this, {
            affectsStruts: true,
            trackFullscreen: true,
        });

        this.connect('destroy', this._onDestroy.bind(this));
    }

    _buildLayout() {
        this._mainBox = new St.BoxLayout({
            style: 'padding: 0 4px;',
            x_expand: true,
            y_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this.add_child(this._mainBox);

        // Left section - Start button
        this._leftSection = new St.BoxLayout({
            style: 'padding: 0 4px;',
            y_align: Clutter.ActorAlign.CENTER,
        });

        this._startButton = new StartButton();
        this._startButton.connect('start-menu-toggle', () => {
            this.emit('start-menu-toggle');
        });
        this._leftSection.add_child(this._startButton);

        // Separator
        const leftSep = new St.Widget({
            style: `
                width: 1px;
                height: 24px;
                background-color: rgba(232, 224, 240, 0.15);
                margin: 0 8px;
            `,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._leftSection.add_child(leftSep);

        // Center section - App buttons
        this._centerSection = new St.BoxLayout({
            style: 'spacing: 2px;',
            x_expand: true,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
        });

        // Right section - System tray
        this._rightSection = new St.BoxLayout({
            y_align: Clutter.ActorAlign.CENTER,
        });

        this._systemTray = new SystemTray();
        this._rightSection.add_child(this._systemTray);

        // Show desktop button at far right
        this._showDesktopBtn = new St.Button({
            style: `
                width: 6px;
                height: ${TASKBAR_HEIGHT}px;
                background-color: rgba(232, 224, 240, 0.15);
                border-radius: 0;
                transition-duration: 150ms;
            `,
            reactive: true,
            track_hover: true,
        });
        this._showDesktopBtn.connect('notify::hover', () => {
            this._showDesktopBtn.style = `
                width: 6px;
                height: ${TASKBAR_HEIGHT}px;
                background-color: ${this._showDesktopBtn.hover ? BRAND_PRIMARY : 'rgba(232, 224, 240, 0.15)'};
                border-radius: 0;
                transition-duration: 150ms;
            `;
        });
        this._showDesktopBtn.connect('clicked', () => {
            this._toggleShowDesktop();
        });

        this._mainBox.add_child(this._leftSection);
        this._mainBox.add_child(this._centerSection);
        this._mainBox.add_child(this._rightSection);
        this._mainBox.add_child(this._showDesktopBtn);
    }

    _populatePinnedApps() {
        const appSystem = Shell.AppSystem.get_default();

        for (const appId of this._pinnedAppIds) {
            const app = appSystem.lookup_app(appId);
            if (app) {
                this._addAppButton(app, true);
            }
        }
    }

    _addAppButton(app, pinned = false) {
        const appId = app.get_id();
        if (this._appButtons.has(appId)) return;

        const button = new TaskbarButton(app);
        button._isPinned = pinned;
        this._centerSection.add_child(button);
        this._appButtons.set(appId, button);
    }

    _removeAppButton(appId) {
        const button = this._appButtons.get(appId);
        if (!button) return;
        if (button._isPinned) {
            button.refresh();
            return;
        }
        this._appButtons.delete(appId);
        button.destroy();
    }

    _trackWindows() {
        const tracker = Shell.WindowTracker.get_default();

        const focusId = tracker.connect('notify::focus-app', () => {
            this._refreshAllButtons();
        });
        this._signalIds.push({ obj: tracker, id: focusId });

        const display = global.display;

        const windowCreatedId = display.connect('window-created', (_display, window) => {
            if (window.get_window_type() !== Meta.WindowType.NORMAL) return;

            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
                const app = tracker.get_window_app(window);
                if (app) {
                    this._addAppButton(app, false);
                    const btn = this._appButtons.get(app.get_id());
                    if (btn) btn.animateBounce();
                }
                this._refreshAllButtons();
                return GLib.SOURCE_REMOVE;
            });
        });
        this._signalIds.push({ obj: display, id: windowCreatedId });

        const unmanagedId = display.connect('window-demands-attention', () => {
            this._refreshAllButtons();
        });
        this._signalIds.push({ obj: display, id: unmanagedId });
    }

    _connectWorkspaceSignals() {
        const workspaceManager = global.workspace_manager;

        const wsChangedId = workspaceManager.connect('active-workspace-changed', () => {
            this._rebuildRunningApps();
        });
        this._signalIds.push({ obj: workspaceManager, id: wsChangedId });

        const nWsId = workspaceManager.connect('notify::n-workspaces', () => {
            this._rebuildRunningApps();
        });
        this._signalIds.push({ obj: workspaceManager, id: nWsId });
    }

    _rebuildRunningApps() {
        const tracker = Shell.WindowTracker.get_default();
        const runningApps = Shell.AppSystem.get_default().get_running();
        const runningIds = new Set(runningApps.map(a => a.get_id()));

        // Remove buttons for apps no longer running (unless pinned)
        for (const [appId, button] of this._appButtons) {
            if (!runningIds.has(appId) && !button._isPinned) {
                this._appButtons.delete(appId);
                button.destroy();
            }
        }

        // Add buttons for newly running apps
        for (const app of runningApps) {
            this._addAppButton(app, false);
        }

        this._refreshAllButtons();
    }

    _refreshAllButtons() {
        for (const [, button] of this._appButtons) {
            button.refresh();
        }
    }

    _toggleShowDesktop() {
        const workspace = global.workspace_manager.get_active_workspace();
        const windows = workspace.list_windows().filter(
            w => w.get_window_type() === Meta.WindowType.NORMAL && !w.is_hidden()
        );

        if (this._desktopShown) {
            for (const win of workspace.list_windows()) {
                if (win.get_window_type() === Meta.WindowType.NORMAL && win.minimized) {
                    win.unminimize();
                }
            }
            this._desktopShown = false;
        } else {
            for (const win of windows) {
                win.minimize();
            }
            this._desktopShown = true;
        }
    }

    _onDestroy() {
        for (const { obj, id } of this._signalIds) {
            try {
                obj.disconnect(id);
            } catch (e) {
                // already disconnected
            }
        }
        this._signalIds = [];

        for (const [, button] of this._appButtons) {
            button.destroy();
        }
        this._appButtons.clear();

        if (this._systemTray) {
            this._systemTray.destroy();
            this._systemTray = null;
        }
    }
});

// ─── Extension Entry Points ──────────────────────────────────────────────────

let _taskbarPanel = null;

export function enable() {
    _taskbarPanel = new TaskbarPanel();
}

export function disable() {
    if (_taskbarPanel) {
        Main.layoutManager.removeChrome(_taskbarPanel);
        _taskbarPanel.destroy();
        _taskbarPanel = null;
    }
}

export function getTaskbar() {
    return _taskbarPanel;
}
