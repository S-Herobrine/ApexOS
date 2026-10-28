// SatasOS Notification Center - Android 14-style notification shade
// GNOME 45+ ESM import style

import St from 'gi://St';
import Clutter from 'gi://Clutter';
import Shell from 'gi://Shell';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Gio from 'gi://Gio';
import Meta from 'gi://Meta';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as MessageTray from 'resource:///org/gnome/shell/ui/messageTray.js';

const BRAND_PRIMARY = '#7C3AED';
const BRAND_HOVER = '#6D28D9';
const BRAND_ACTIVE = '#5B21B6';
const BRAND_DARK_BG = '#1E1B2E';
const BRAND_DARK_SURFACE = '#2D2640';
const BRAND_LIGHT_TEXT = '#E8E0F0';

const SHADE_ANIMATION_MS = 400;
const QUICK_TOGGLE_SIZE = 64;
const QUICK_TOGGLE_COLUMNS = 3;

// ─── Notification Card ───────────────────────────────────────────

export const NotificationCard = GObject.registerClass(
class NotificationCard extends St.BoxLayout {
    _init(params) {
        super._init({
            vertical: true,
            style: `background-color: ${BRAND_DARK_SURFACE};
                    border-radius: 20px;
                    padding: 16px 20px;
                    margin: 4px 0;
                    spacing: 6px;`,
            reactive: true,
            x_expand: true,
        });

        this._source = params.source || 'Unknown';
        this._title = params.title || '';
        this._body = params.body || '';
        this._timestamp = params.timestamp || GLib.DateTime.new_now_local();
        this._icon = params.icon || null;
        this._actions = params.actions || [];
        this._notification = params.notification || null;
        this._onDismiss = params.onDismiss || null;

        this._buildCard();
        this._setupSwipeDismiss();
    }

    _buildCard() {
        // Top row: icon, source, timestamp
        const topRow = new St.BoxLayout({ style: 'spacing: 8px;', x_expand: true });

        const appIcon = new St.Icon({
            icon_name: this._icon || 'dialog-information-symbolic',
            icon_size: 18,
            style: `color: ${BRAND_PRIMARY};`,
        });
        topRow.add_child(appIcon);

        const sourceLabel = new St.Label({
            text: this._source,
            style: `color: rgba(232,224,240,0.6); font-size: 12px; font-weight: bold;`,
            x_expand: true,
        });
        topRow.add_child(sourceLabel);

        const timeStr = this._timestamp.format('%H:%M') || '';
        const timeLabel = new St.Label({
            text: timeStr,
            style: `color: rgba(232,224,240,0.4); font-size: 11px;`,
        });
        topRow.add_child(timeLabel);

        this.add_child(topRow);

        // Title
        if (this._title) {
            const titleLabel = new St.Label({
                text: this._title,
                style: `color: white; font-size: 15px; font-weight: bold;`,
            });
            titleLabel.clutter_text.set_ellipsize(3);
            this.add_child(titleLabel);
        }

        // Body
        if (this._body) {
            const bodyLabel = new St.Label({
                text: this._body,
                style: `color: ${BRAND_LIGHT_TEXT}; font-size: 13px;`,
            });
            bodyLabel.clutter_text.set_line_wrap(true);
            bodyLabel.clutter_text.set_ellipsize(3);
            this.add_child(bodyLabel);
        }

        // Action buttons
        if (this._actions.length > 0) {
            const actionsRow = new St.BoxLayout({
                style: 'spacing: 10px; padding-top: 6px;',
                x_align: Clutter.ActorAlign.END,
            });
            for (const action of this._actions) {
                const actionBtn = new St.Button({
                    label: action.label || 'Action',
                    style: `color: ${BRAND_PRIMARY};
                            font-size: 13px;
                            font-weight: bold;
                            padding: 4px 14px;
                            border-radius: 12px;
                            background-color: rgba(124,58,237,0.12);`,
                });
                actionBtn.connect('clicked', () => {
                    if (action.callback) action.callback();
                });
                actionsRow.add_child(actionBtn);
            }
            this.add_child(actionsRow);
        }
    }

    _setupSwipeDismiss() {
        let dragStartX = 0;
        let dragging = false;

        this.connect('button-press-event', (_actor, event) => {
            dragStartX = event.get_coords()[0];
            dragging = true;
            return Clutter.EVENT_PROPAGATE;
        });

        this.connect('motion-event', (_actor, event) => {
            if (!dragging) return Clutter.EVENT_PROPAGATE;
            const [cx] = event.get_coords();
            const dx = cx - dragStartX;
            this.set_translation(dx, 0, 0);
            this.opacity = Math.max(0, 255 - Math.abs(dx) * 1.8);
            return Clutter.EVENT_PROPAGATE;
        });

        this.connect('button-release-event', (_actor, event) => {
            if (!dragging) return Clutter.EVENT_PROPAGATE;
            dragging = false;
            const [cx] = event.get_coords();
            const dx = cx - dragStartX;
            if (Math.abs(dx) > 120) {
                // Dismiss
                const direction = dx > 0 ? 500 : -500;
                this.ease({
                    translation_x: direction,
                    opacity: 0,
                    duration: 200,
                    mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                    onComplete: () => {
                        if (this._onDismiss) this._onDismiss(this);
                        this.destroy();
                    },
                });
            } else {
                // Snap back
                this.ease({
                    translation_x: 0,
                    opacity: 255,
                    duration: 150,
                    mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                });
            }
            return Clutter.EVENT_PROPAGATE;
        });

        // Touch events for mobile
        this.connect('touch-event', (_actor, event) => {
            const type = event.type();
            if (type === Clutter.EventType.TOUCH_BEGIN) {
                dragStartX = event.get_coords()[0];
                dragging = true;
            } else if (type === Clutter.EventType.TOUCH_UPDATE && dragging) {
                const [cx] = event.get_coords();
                const dx = cx - dragStartX;
                this.set_translation(dx, 0, 0);
                this.opacity = Math.max(0, 255 - Math.abs(dx) * 1.8);
            } else if (type === Clutter.EventType.TOUCH_END && dragging) {
                dragging = false;
                const [cx] = event.get_coords();
                const dx = cx - dragStartX;
                if (Math.abs(dx) > 120) {
                    const direction = dx > 0 ? 500 : -500;
                    this.ease({
                        translation_x: direction,
                        opacity: 0,
                        duration: 200,
                        mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                        onComplete: () => {
                            if (this._onDismiss) this._onDismiss(this);
                            this.destroy();
                        },
                    });
                } else {
                    this.ease({
                        translation_x: 0,
                        opacity: 255,
                        duration: 150,
                        mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                    });
                }
            }
            return Clutter.EVENT_PROPAGATE;
        });
    }
});

// ─── Media Controls Card ─────────────────────────────────────────

const MediaControlsCard = GObject.registerClass(
class MediaControlsCard extends St.BoxLayout {
    _init() {
        super._init({
            vertical: true,
            style: `background: linear-gradient(135deg, ${BRAND_ACTIVE}, ${BRAND_DARK_SURFACE});
                    background-color: ${BRAND_ACTIVE};
                    border-radius: 20px;
                    padding: 18px 20px;
                    margin: 6px 0;
                    spacing: 10px;`,
            x_expand: true,
        });

        this._buildControls();
    }

    _buildControls() {
        // Title row
        const titleRow = new St.BoxLayout({ style: 'spacing: 10px;' });
        titleRow.add_child(new St.Icon({
            icon_name: 'audio-x-generic-symbolic',
            icon_size: 40,
            style: `color: ${BRAND_LIGHT_TEXT}; background-color: ${BRAND_DARK_SURFACE}; border-radius: 10px; padding: 8px;`,
        }));
        const infoBox = new St.BoxLayout({ vertical: true, style: 'spacing: 2px;', x_expand: true });
        this._trackLabel = new St.Label({
            text: 'No media playing',
            style: `color: white; font-size: 15px; font-weight: bold;`,
        });
        this._artistLabel = new St.Label({
            text: 'Unknown artist',
            style: `color: rgba(232,224,240,0.6); font-size: 12px;`,
        });
        infoBox.add_child(this._trackLabel);
        infoBox.add_child(this._artistLabel);
        titleRow.add_child(infoBox);
        this.add_child(titleRow);

        // Progress bar
        this._progressSlider = new St.Slider({
            value: 0,
            style: `height: 4px; color: ${BRAND_PRIMARY};`,
            x_expand: true,
        });
        this.add_child(this._progressSlider);

        // Playback controls
        const controlsRow = new St.BoxLayout({
            style: 'spacing: 24px;',
            x_align: Clutter.ActorAlign.CENTER,
        });

        const prevBtn = this._makeControlBtn('media-skip-backward-symbolic');
        const playBtn = this._makeControlBtn('media-playback-start-symbolic', true);
        const nextBtn = this._makeControlBtn('media-skip-forward-symbolic');

        prevBtn.connect('clicked', () => this._sendMediaKey('Previous'));
        playBtn.connect('clicked', () => this._sendMediaKey('PlayPause'));
        nextBtn.connect('clicked', () => this._sendMediaKey('Next'));

        controlsRow.add_child(prevBtn);
        controlsRow.add_child(playBtn);
        controlsRow.add_child(nextBtn);
        this.add_child(controlsRow);
    }

    _makeControlBtn(iconName, large = false) {
        const size = large ? 36 : 24;
        return new St.Button({
            child: new St.Icon({
                icon_name: iconName,
                icon_size: size,
                style: `color: white;`,
            }),
            style: `padding: 8px; border-radius: 50%;`,
        });
    }

    _sendMediaKey(action) {
        try {
            const bus = Gio.DBus.session;
            bus.call(
                'org.mpris.MediaPlayer2.playerctld',
                '/org/mpris/MediaPlayer2',
                'org.mpris.MediaPlayer2.Player',
                action,
                null, null,
                Gio.DBusCallFlags.NONE,
                -1, null, null
            );
        } catch (e) {
            // No active media player – silently ignore
        }
    }

    updateTrack(title, artist) {
        this._trackLabel.set_text(title || 'No media playing');
        this._artistLabel.set_text(artist || 'Unknown artist');
    }
});

// ─── Quick Setting Toggle ────────────────────────────────────────

const QuickToggle = GObject.registerClass(
class QuickToggle extends St.Button {
    _init(params) {
        super._init({
            toggle_mode: true,
            style: `background-color: ${BRAND_DARK_SURFACE};
                    border-radius: 18px;
                    padding: 14px 10px;
                    min-width: 100px;
                    min-height: 60px;`,
        });

        this._label = params.label || 'Toggle';
        this._iconName = params.icon || 'emblem-system-symbolic';
        this._active = params.active || false;
        this._onToggle = params.onToggle || null;

        const box = new St.BoxLayout({
            vertical: true,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            style: 'spacing: 6px;',
        });

        this._iconWidget = new St.Icon({
            icon_name: this._iconName,
            icon_size: 26,
            style: `color: ${this._active ? BRAND_PRIMARY : BRAND_LIGHT_TEXT};`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        box.add_child(this._iconWidget);

        this._labelWidget = new St.Label({
            text: this._label,
            style: `color: ${BRAND_LIGHT_TEXT}; font-size: 11px; text-align: center;`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        box.add_child(this._labelWidget);
        this.set_child(box);

        this.checked = this._active;
        this._updateStyle();

        this.connect('clicked', () => {
            this._active = this.checked;
            this._updateStyle();
            if (this._onToggle) this._onToggle(this._active);
        });
    }

    _updateStyle() {
        if (this._active) {
            this.style = `background-color: ${BRAND_PRIMARY};
                          border-radius: 18px;
                          padding: 14px 10px;
                          min-width: 100px;
                          min-height: 60px;`;
            this._iconWidget.style = `color: white;`;
        } else {
            this.style = `background-color: ${BRAND_DARK_SURFACE};
                          border-radius: 18px;
                          padding: 14px 10px;
                          min-width: 100px;
                          min-height: 60px;`;
            this._iconWidget.style = `color: ${BRAND_LIGHT_TEXT};`;
        }
    }

    setActive(active) {
        this._active = active;
        this.checked = active;
        this._updateStyle();
    }
});

// ─── Notification Shade ──────────────────────────────────────────

export const NotificationShade = GObject.registerClass(
class NotificationShade extends St.Widget {
    _init() {
        const monitor = Main.layoutManager.primaryMonitor;
        super._init({
            name: 'satas-notification-shade',
            reactive: true,
            visible: false,
            x: monitor.x,
            y: monitor.y,
            width: monitor.width,
            height: monitor.height,
        });

        this._isOpen = false;
        this._notifications = [];
        this._clockTimerId = 0;

        this._buildOverlay();
        this._buildShadePanel();
        this._connectGnomeNotifications();
        this._setupGestureZone();

        Main.layoutManager.addTopChrome(this);
    }

    _buildOverlay() {
        // Dim background
        this._dimBg = new St.Widget({
            style: 'background-color: rgba(0,0,0,0.55);',
            reactive: true,
            x: 0, y: 0,
            width: Main.layoutManager.primaryMonitor.width,
            height: Main.layoutManager.primaryMonitor.height,
        });
        this._dimBg.connect('button-press-event', () => {
            this.close();
            return Clutter.EVENT_STOP;
        });
        this.add_child(this._dimBg);
    }

    _buildShadePanel() {
        const monitor = Main.layoutManager.primaryMonitor;
        const panelWidth = Math.min(460, monitor.width - 40);

        this._shadePanel = new St.BoxLayout({
            vertical: true,
            style: `background-color: ${BRAND_DARK_BG};
                    border-radius: 0 0 28px 28px;
                    padding: 24px 24px 16px 24px;
                    spacing: 6px;`,
            width: panelWidth,
            x: Math.floor((monitor.width - panelWidth) / 2),
            y: 0,
        });
        this.add_child(this._shadePanel);

        // ── Clock & Date ──
        this._clockLabel = new St.Label({
            text: '',
            style: `color: white; font-size: 52px; font-weight: 200; letter-spacing: 2px;`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._shadePanel.add_child(this._clockLabel);

        this._dateLabel = new St.Label({
            text: '',
            style: `color: rgba(232,224,240,0.6); font-size: 14px; padding-bottom: 12px;`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._shadePanel.add_child(this._dateLabel);
        this._updateClock();

        // ── Quick Settings Grid ──
        const qsLabel = new St.Label({
            text: 'Quick Settings',
            style: `color: ${BRAND_LIGHT_TEXT}; font-size: 13px; font-weight: bold; padding: 6px 0 4px 4px;`,
        });
        this._shadePanel.add_child(qsLabel);

        this._quickSettingsGrid = new St.Widget({
            layout_manager: new Clutter.GridLayout({
                orientation: Clutter.Orientation.HORIZONTAL,
                column_spacing: 10,
                row_spacing: 10,
            }),
            x_expand: true,
        });
        const gridLayout = this._quickSettingsGrid.layout_manager;

        // Row 0
        this._wifiToggle = new QuickToggle({
            label: 'Wi-Fi', icon: 'network-wireless-symbolic', active: true,
            onToggle: (on) => this._onWifiToggle(on),
        });
        this._btToggle = new QuickToggle({
            label: 'Bluetooth', icon: 'bluetooth-active-symbolic', active: false,
            onToggle: (on) => this._onBluetoothToggle(on),
        });
        this._darkToggle = new QuickToggle({
            label: 'Dark Mode', icon: 'weather-clear-night-symbolic', active: true,
            onToggle: (on) => this._onDarkModeToggle(on),
        });

        gridLayout.attach(this._wifiToggle, 0, 0, 1, 1);
        gridLayout.attach(this._btToggle, 1, 0, 1, 1);
        gridLayout.attach(this._darkToggle, 2, 0, 1, 1);

        // Row 1
        this._dndToggle = new QuickToggle({
            label: 'Do Not Disturb', icon: 'notifications-disabled-symbolic', active: false,
            onToggle: (on) => this._onDndToggle(on),
        });
        this._airplaneToggle = new QuickToggle({
            label: 'Airplane', icon: 'airplane-mode-symbolic', active: false,
            onToggle: () => {},
        });
        this._rotateToggle = new QuickToggle({
            label: 'Auto Rotate', icon: 'object-rotate-right-symbolic', active: true,
            onToggle: () => {},
        });

        gridLayout.attach(this._dndToggle, 0, 1, 1, 1);
        gridLayout.attach(this._airplaneToggle, 1, 1, 1, 1);
        gridLayout.attach(this._rotateToggle, 2, 1, 1, 1);

        this._shadePanel.add_child(this._quickSettingsGrid);

        // ── Brightness Slider ──
        const brightnessRow = this._makeSliderRow('display-brightness-symbolic', 'Brightness', 0.75);
        this._brightnessSlider = brightnessRow._slider;
        this._brightnessSlider.connect('notify::value', () => {
            this._onBrightnessChanged(this._brightnessSlider.value);
        });
        this._shadePanel.add_child(brightnessRow);

        // ── Volume Slider ──
        const volumeRow = this._makeSliderRow('audio-volume-high-symbolic', 'Volume', 0.6);
        this._volumeSlider = volumeRow._slider;
        this._volumeSlider.connect('notify::value', () => {
            this._onVolumeChanged(this._volumeSlider.value);
        });
        this._shadePanel.add_child(volumeRow);

        // ── Media Controls ──
        this._mediaCard = new MediaControlsCard();
        this._shadePanel.add_child(this._mediaCard);

        // ── Notifications Section ──
        const notiHeader = new St.BoxLayout({ style: 'spacing: 8px; padding: 10px 0 4px 4px;', x_expand: true });
        notiHeader.add_child(new St.Label({
            text: 'Notifications',
            style: `color: ${BRAND_LIGHT_TEXT}; font-size: 13px; font-weight: bold;`,
            x_expand: true,
        }));
        this._clearAllBtn = new St.Button({
            label: 'Clear All',
            style: `color: ${BRAND_PRIMARY}; font-size: 12px; font-weight: bold; padding: 4px 12px;
                    border-radius: 12px; background-color: rgba(124,58,237,0.12);`,
        });
        this._clearAllBtn.connect('clicked', () => this._clearAllNotifications());
        notiHeader.add_child(this._clearAllBtn);
        this._shadePanel.add_child(notiHeader);

        // Scrollable notification list
        this._notiScrollView = new St.ScrollView({
            x_expand: true,
            y_expand: true,
            overlay_scrollbars: true,
            style: 'max-height: 320px;',
        });
        this._notiScrollView.set_policy(St.PolicyType.NEVER, St.PolicyType.AUTOMATIC);

        this._notiContainer = new St.BoxLayout({
            vertical: true,
            x_expand: true,
            style: 'spacing: 4px; padding: 2px 0;',
        });
        this._notiScrollView.add_child(this._notiContainer);
        this._shadePanel.add_child(this._notiScrollView);

        // Empty state
        this._emptyLabel = new St.Label({
            text: 'No notifications',
            style: `color: rgba(232,224,240,0.35); font-size: 14px; padding: 28px 0;`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._notiContainer.add_child(this._emptyLabel);

        // Handle bar at bottom
        const handleWrap = new St.Bin({
            x_align: Clutter.ActorAlign.CENTER,
            style: 'padding-top: 10px;',
            child: new St.Widget({
                width: 48, height: 5,
                style: `background-color: rgba(232,224,240,0.25); border-radius: 3px;`,
            }),
        });
        this._shadePanel.add_child(handleWrap);
    }

    _makeSliderRow(iconName, label, value) {
        const row = new St.BoxLayout({
            style: 'spacing: 10px; padding: 6px 4px;',
            x_expand: true,
        });
        row.add_child(new St.Icon({
            icon_name: iconName,
            icon_size: 18,
            style: `color: ${BRAND_LIGHT_TEXT};`,
        }));
        const slider = new St.Slider({
            value: value,
            x_expand: true,
            style: `color: ${BRAND_PRIMARY}; height: 20px;`,
        });
        row._slider = slider;
        row.add_child(slider);
        return row;
    }

    _updateClock() {
        const now = GLib.DateTime.new_now_local();
        this._clockLabel.set_text(now.format('%H:%M') || '');
        this._dateLabel.set_text(now.format('%A, %B %e') || '');

        // Update every 15 seconds while shade is open
        if (this._clockTimerId) {
            GLib.source_remove(this._clockTimerId);
            this._clockTimerId = 0;
        }
        if (this._isOpen) {
            this._clockTimerId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 15, () => {
                this._updateClock();
                return GLib.SOURCE_REMOVE;
            });
        }
    }

    // ── Quick Settings Callbacks ──

    _onWifiToggle(on) {
        try {
            const bus = Gio.DBus.system;
            bus.call(
                'org.freedesktop.NetworkManager',
                '/org/freedesktop/NetworkManager',
                'org.freedesktop.DBus.Properties',
                'Set',
                new GLib.Variant('(ssv)', [
                    'org.freedesktop.NetworkManager',
                    'WirelessEnabled',
                    new GLib.Variant('b', on),
                ]),
                null, Gio.DBusCallFlags.NONE, -1, null, null
            );
        } catch (e) { /* NM not available */ }
    }

    _onBluetoothToggle(on) {
        try {
            GLib.spawn_command_line_async(
                on ? 'rfkill unblock bluetooth' : 'rfkill block bluetooth'
            );
        } catch (e) { /* rfkill not available */ }
    }

    _onDarkModeToggle(on) {
        try {
            const settings = new Gio.Settings({ schema_id: 'org.gnome.desktop.interface' });
            settings.set_string('color-scheme', on ? 'prefer-dark' : 'prefer-light');
        } catch (e) { /* schema not available */ }
    }

    _onDndToggle(on) {
        try {
            const settings = new Gio.Settings({ schema_id: 'org.gnome.desktop.notifications' });
            settings.set_boolean('show-banners', !on);
        } catch (e) { /* schema not available */ }
    }

    _onBrightnessChanged(value) {
        try {
            const bus = Gio.DBus.session;
            const brightnessValue = Math.round(value * 100);
            bus.call(
                'org.gnome.SettingsDaemon.Power',
                '/org/gnome/SettingsDaemon/Power',
                'org.freedesktop.DBus.Properties',
                'Set',
                new GLib.Variant('(ssv)', [
                    'org.gnome.SettingsDaemon.Power.Screen',
                    'Brightness',
                    new GLib.Variant('i', brightnessValue),
                ]),
                null, Gio.DBusCallFlags.NONE, -1, null, null
            );
        } catch (e) { /* brightness control not available */ }
    }

    _onVolumeChanged(value) {
        try {
            const percent = Math.round(value * 100);
            GLib.spawn_command_line_async(`pactl set-sink-volume @DEFAULT_SINK@ ${percent}%`);
        } catch (e) { /* pactl not available */ }
    }

    // ── GNOME Notification Integration ──

    _connectGnomeNotifications() {
        const tray = Main.messageTray;
        if (!tray) return;

        this._sourceAddedId = tray.connect('source-added', (_tray, source) => {
            this._watchSource(source);
        });

        // Watch existing sources
        const sources = tray.getSources ? tray.getSources() : [];
        for (const source of sources) {
            this._watchSource(source);
        }
    }

    _watchSource(source) {
        source.connect('notification-added', (_source, notification) => {
            this._addNotification({
                source: source.title || 'App',
                title: notification.title || '',
                body: notification.body || '',
                icon: source.iconName || 'dialog-information-symbolic',
                timestamp: GLib.DateTime.new_now_local(),
                notification: notification,
            });
        });
    }

    addNotification(params) {
        this._addNotification(params);
    }

    _addNotification(params) {
        // Hide empty label
        if (this._emptyLabel.visible) {
            this._emptyLabel.visible = false;
        }

        const card = new NotificationCard({
            source: params.source,
            title: params.title,
            body: params.body,
            icon: params.icon,
            timestamp: params.timestamp || GLib.DateTime.new_now_local(),
            actions: params.actions || [],
            notification: params.notification || null,
            onDismiss: (c) => this._onNotificationDismissed(c),
        });

        this._notifications.push(card);

        // Insert at top
        if (this._notiContainer.get_n_children() > 0) {
            this._notiContainer.insert_child_at_index(card, 0);
        } else {
            this._notiContainer.add_child(card);
        }
    }

    _onNotificationDismissed(card) {
        const idx = this._notifications.indexOf(card);
        if (idx !== -1) {
            this._notifications.splice(idx, 1);
        }
        if (this._notifications.length === 0) {
            this._emptyLabel.visible = true;
        }
    }

    _clearAllNotifications() {
        for (const card of [...this._notifications]) {
            card.ease({
                opacity: 0,
                translation_x: 300,
                duration: 200,
                mode: Clutter.AnimationMode.EASE_IN_QUAD,
                onComplete: () => card.destroy(),
            });
        }
        this._notifications = [];
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 250, () => {
            this._emptyLabel.visible = true;
            return GLib.SOURCE_REMOVE;
        });
    }

    // ── Gesture Zone ──

    _setupGestureZone() {
        const monitor = Main.layoutManager.primaryMonitor;
        this._gestureZone = new St.Widget({
            name: 'satas-shade-gesture-zone',
            reactive: true,
            x: 0,
            y: monitor.y,
            width: monitor.width,
            height: 24,
            style: 'background-color: transparent;',
        });

        let gestureStartY = 0;
        this._gestureZone.connect('button-press-event', (_actor, event) => {
            gestureStartY = event.get_coords()[1];
            return Clutter.EVENT_PROPAGATE;
        });
        this._gestureZone.connect('button-release-event', (_actor, event) => {
            const endY = event.get_coords()[1];
            if (endY - gestureStartY > 50) {
                this.open();
            }
            return Clutter.EVENT_PROPAGATE;
        });
        this._gestureZone.connect('touch-event', (_actor, event) => {
            const type = event.type();
            if (type === Clutter.EventType.TOUCH_BEGIN) {
                gestureStartY = event.get_coords()[1];
            } else if (type === Clutter.EventType.TOUCH_END) {
                const endY = event.get_coords()[1];
                if (endY - gestureStartY > 50) {
                    this.open();
                }
            }
            return Clutter.EVENT_PROPAGATE;
        });

        Main.layoutManager.addTopChrome(this._gestureZone);
    }

    // ── Open / Close ──

    open() {
        if (this._isOpen) return;
        this._isOpen = true;

        const monitor = Main.layoutManager.primaryMonitor;
        this.set_position(monitor.x, monitor.y);
        this.set_size(monitor.width, monitor.height);
        this._dimBg.set_size(monitor.width, monitor.height);

        const panelHeight = this._shadePanel.get_preferred_height(-1)[1] || 700;
        this._shadePanel.set_position(
            Math.floor((monitor.width - this._shadePanel.width) / 2),
            -panelHeight
        );
        this.visible = true;
        this._dimBg.opacity = 0;
        this._dimBg.ease({ opacity: 255, duration: SHADE_ANIMATION_MS, mode: Clutter.AnimationMode.EASE_OUT_QUAD });

        this._shadePanel.ease({
            y: 0,
            duration: SHADE_ANIMATION_MS,
            mode: Clutter.AnimationMode.EASE_OUT_CUBIC,
        });

        this._updateClock();
    }

    close() {
        if (!this._isOpen) return;
        this._isOpen = false;

        const panelHeight = this._shadePanel.get_preferred_height(-1)[1] || 700;

        this._dimBg.ease({ opacity: 0, duration: SHADE_ANIMATION_MS, mode: Clutter.AnimationMode.EASE_IN_QUAD });
        this._shadePanel.ease({
            y: -panelHeight,
            duration: SHADE_ANIMATION_MS,
            mode: Clutter.AnimationMode.EASE_IN_CUBIC,
            onComplete: () => {
                this.visible = false;
            },
        });

        if (this._clockTimerId) {
            GLib.source_remove(this._clockTimerId);
            this._clockTimerId = 0;
        }
    }

    toggle() {
        if (this._isOpen) this.close();
        else this.open();
    }

    vfunc_key_press_event(event) {
        if (event.get_key_symbol() === Clutter.KEY_Escape) {
            this.close();
            return Clutter.EVENT_STOP;
        }
        return Clutter.EVENT_PROPAGATE;
    }

    destroy() {
        if (this._clockTimerId) {
            GLib.source_remove(this._clockTimerId);
            this._clockTimerId = 0;
        }
        if (this._sourceAddedId && Main.messageTray) {
            Main.messageTray.disconnect(this._sourceAddedId);
            this._sourceAddedId = 0;
        }
        if (this._gestureZone) {
            this._gestureZone.destroy();
            this._gestureZone = null;
        }
        super.destroy();
    }
});

// ── Singleton Management ──

let _shadeInstance = null;

export function getNotificationShade() {
    if (!_shadeInstance)
        _shadeInstance = new NotificationShade();
    return _shadeInstance;
}

export function toggleNotificationShade() {
    getNotificationShade().toggle();
}

export function openNotificationShade() {
    getNotificationShade().open();
}

export function closeNotificationShade() {
    getNotificationShade().close();
}

export function destroyNotificationShade() {
    if (_shadeInstance) {
        _shadeInstance.destroy();
        _shadeInstance = null;
    }
}
