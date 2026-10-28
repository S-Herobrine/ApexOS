/**
 * SatasOS Shell Extension
 *
 * Main entry point for the SatasOS GNOME Shell extension.
 * Replaces the default GNOME top panel with a modern bottom taskbar,
 * start menu, app drawer, notification shade, and system tray.
 *
 * Compatible with GNOME 45+ ESM module style.
 */

import St from 'gi://St';
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as Layout from 'resource:///org/gnome/shell/ui/layout.js';
import * as DND from 'resource:///org/gnome/shell/ui/dnd.js';

import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const TASKBAR_HEIGHT = 48;
const START_MENU_WIDTH = 640;
const START_MENU_HEIGHT = 680;
const APP_ICON_SIZE = 48;
const PINNED_ICON_SIZE = 56;
const NOTIFICATION_WIDTH = 380;

/**
 * SatasOS Taskbar Panel
 * Bottom-aligned panel containing start button, pinned apps, running app indicators,
 * system tray, clock, and quick-settings toggles.
 */
const SatasOSTaskbar = GObject.registerClass(
class SatasOSTaskbar extends St.Widget {
    _init(extension) {
        super._init({
            name: 'satasos-taskbar',
            reactive: true,
            track_hover: true,
            style_class: 'satasos-taskbar',
        });

        this._extension = extension;
        this._monitor = Main.layoutManager.primaryMonitor;

        this.set_position(this._monitor.x, this._monitor.y + this._monitor.height - TASKBAR_HEIGHT);
        this.set_size(this._monitor.width, TASKBAR_HEIGHT);

        this._layout = new St.BoxLayout({
            style_class: 'satasos-taskbar-inner',
            x_expand: true,
            y_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this.add_child(this._layout);

        this._buildStartButton();
        this._buildSearchButton();
        this._buildPinnedApps();
        this._buildRunningApps();
        this._buildSpacer();
        this._buildSystemTray();
        this._buildClock();
        this._buildQuickSettingsButton();
        this._buildShowDesktopButton();

        this._appSystem = Shell.AppSystem.get_default();
        this._appStateChangedId = this._appSystem.connect('app-state-changed',
            this._onAppStateChanged.bind(this));

        this._monitorsChangedId = Main.layoutManager.connect('monitors-changed',
            this._onMonitorsChanged.bind(this));
    }

    _buildStartButton() {
        this._startButton = new St.Button({
            style_class: 'satasos-start-button',
            reactive: true,
            can_focus: true,
            track_hover: true,
            y_align: Clutter.ActorAlign.CENTER,
        });
        const startIcon = new St.Icon({
            icon_name: 'view-app-grid-symbolic',
            icon_size: 24,
            style_class: 'satasos-start-icon',
        });
        this._startButton.set_child(startIcon);
        this._startButton.connect('clicked', () => {
            this._extension.toggleStartMenu();
        });
        this._layout.add_child(this._startButton);
    }

    _buildSearchButton() {
        this._searchButton = new St.Button({
            style_class: 'satasos-taskbar-button',
            reactive: true,
            can_focus: true,
            track_hover: true,
            y_align: Clutter.ActorAlign.CENTER,
        });
        const searchIcon = new St.Icon({
            icon_name: 'edit-find-symbolic',
            icon_size: 20,
            style_class: 'satasos-taskbar-icon',
        });
        this._searchButton.set_child(searchIcon);
        this._searchButton.connect('clicked', () => {
            this._extension.toggleStartMenu(true);
        });
        this._layout.add_child(this._searchButton);
    }

    _buildPinnedApps() {
        this._pinnedBox = new St.BoxLayout({
            style_class: 'satasos-pinned-apps',
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._layout.add_child(this._pinnedBox);

        const pinnedIds = [
            'org.gnome.Nautilus.desktop',
            'org.gnome.Terminal.desktop',
            'org.gnome.TextEditor.desktop',
            'org.gnome.Settings.desktop',
            'firefox.desktop',
        ];

        for (const id of pinnedIds) {
            const app = this._appSystem?.lookup_app(id);
            if (app) {
                this._addPinnedAppButton(app);
            }
        }
    }

    _addPinnedAppButton(app) {
        const button = new St.Button({
            style_class: 'satasos-taskbar-app-button',
            reactive: true,
            can_focus: true,
            track_hover: true,
            y_align: Clutter.ActorAlign.CENTER,
        });
        const icon = app.create_icon_texture(APP_ICON_SIZE);
        button.set_child(icon);
        button.connect('clicked', () => {
            const windows = app.get_windows();
            if (windows.length > 0) {
                const lastWindow = windows[0];
                if (lastWindow.has_focus()) {
                    lastWindow.minimize();
                } else {
                    lastWindow.activate(global.get_current_time());
                }
            } else {
                app.activate();
            }
        });
        button._app = app;
        this._pinnedBox.add_child(button);
    }

    _buildRunningApps() {
        this._runningBox = new St.BoxLayout({
            style_class: 'satasos-running-apps',
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._layout.add_child(this._runningBox);
        this._refreshRunningApps();
    }

    _refreshRunningApps() {
        this._runningBox.destroy_all_children();
        const runningApps = this._appSystem?.get_running() ?? [];

        for (const app of runningApps) {
            const isPinned = this._pinnedBox.get_children().some(
                child => child._app?.get_id() === app.get_id()
            );
            if (isPinned) {
                const pinnedBtn = this._pinnedBox.get_children().find(
                    child => child._app?.get_id() === app.get_id()
                );
                if (pinnedBtn) {
                    pinnedBtn.add_style_class_name('running');
                }
                continue;
            }

            const button = new St.Button({
                style_class: 'satasos-taskbar-app-button running',
                reactive: true,
                can_focus: true,
                track_hover: true,
                y_align: Clutter.ActorAlign.CENTER,
            });
            const icon = app.create_icon_texture(APP_ICON_SIZE);
            button.set_child(icon);
            button._app = app;
            button.connect('clicked', () => {
                const windows = app.get_windows();
                if (windows.length > 0) {
                    const win = windows[0];
                    if (win.has_focus()) {
                        win.minimize();
                    } else {
                        win.activate(global.get_current_time());
                    }
                }
            });
            this._runningBox.add_child(button);
        }
    }

    _buildSpacer() {
        this._layout.add_child(new St.Widget({ x_expand: true }));
    }

    _buildSystemTray() {
        this._trayBox = new St.BoxLayout({
            style_class: 'satasos-system-tray',
            y_align: Clutter.ActorAlign.CENTER,
        });

        const trayIcons = [
            { name: 'network-wireless-symbolic', tooltip: 'Network' },
            { name: 'audio-volume-high-symbolic', tooltip: 'Volume' },
            { name: 'battery-full-symbolic', tooltip: 'Battery' },
        ];

        for (const item of trayIcons) {
            const btn = new St.Button({
                style_class: 'satasos-tray-button',
                reactive: true,
                can_focus: true,
                track_hover: true,
                y_align: Clutter.ActorAlign.CENTER,
            });
            const icon = new St.Icon({
                icon_name: item.name,
                icon_size: 18,
                style_class: 'satasos-tray-icon',
            });
            btn.set_child(icon);
            btn.connect('clicked', () => {
                this._extension.toggleNotificationShade();
            });
            this._trayBox.add_child(btn);
        }

        this._layout.add_child(this._trayBox);
    }

    _buildClock() {
        this._clockLabel = new St.Label({
            style_class: 'satasos-clock',
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._updateClock();
        this._clockTimerId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1,
            () => {
                this._updateClock();
                return GLib.SOURCE_CONTINUE;
            });
        const clockButton = new St.Button({
            style_class: 'satasos-clock-button',
            reactive: true,
            can_focus: true,
            track_hover: true,
            y_align: Clutter.ActorAlign.CENTER,
            child: this._clockLabel,
        });
        clockButton.connect('clicked', () => {
            this._extension.toggleNotificationShade();
        });
        this._layout.add_child(clockButton);
    }

    _updateClock() {
        const now = GLib.DateTime.new_now_local();
        const timeStr = now.format('%l:%M %p');
        const dateStr = now.format('%b %e');
        this._clockLabel.set_text(`${timeStr.trim()}  ${dateStr}`);
    }

    _buildQuickSettingsButton() {
        const qsButton = new St.Button({
            style_class: 'satasos-quick-settings-button',
            reactive: true,
            can_focus: true,
            track_hover: true,
            y_align: Clutter.ActorAlign.CENTER,
        });
        const qsIcon = new St.Icon({
            icon_name: 'emblem-system-symbolic',
            icon_size: 18,
            style_class: 'satasos-tray-icon',
        });
        qsButton.set_child(qsIcon);
        qsButton.connect('clicked', () => {
            this._extension.toggleNotificationShade();
        });
        this._layout.add_child(qsButton);
    }

    _buildShowDesktopButton() {
        const sdButton = new St.Button({
            style_class: 'satasos-show-desktop-button',
            reactive: true,
            can_focus: true,
            track_hover: true,
            y_align: Clutter.ActorAlign.CENTER,
        });
        sdButton.set_size(8, TASKBAR_HEIGHT);
        sdButton.connect('clicked', () => {
            const tracker = Shell.WindowTracker.get_default();
            const windows = global.get_window_actors().map(a => a.meta_window)
                .filter(w => w.window_type === Meta.WindowType.NORMAL && !w.is_hidden());
            if (windows.length > 0) {
                for (const win of windows) {
                    win.minimize();
                }
            } else {
                const minimized = global.get_window_actors().map(a => a.meta_window)
                    .filter(w => w.window_type === Meta.WindowType.NORMAL && w.minimized);
                for (const win of minimized) {
                    win.unminimize();
                }
            }
        });
        this._layout.add_child(sdButton);
    }

    _onAppStateChanged(appSystem, app) {
        this._refreshRunningApps();
    }

    _onMonitorsChanged() {
        this._monitor = Main.layoutManager.primaryMonitor;
        this.set_position(this._monitor.x, this._monitor.y + this._monitor.height - TASKBAR_HEIGHT);
        this.set_size(this._monitor.width, TASKBAR_HEIGHT);
    }

    destroy() {
        if (this._clockTimerId) {
            GLib.source_remove(this._clockTimerId);
            this._clockTimerId = null;
        }
        if (this._appStateChangedId) {
            this._appSystem.disconnect(this._appStateChangedId);
            this._appStateChangedId = null;
        }
        if (this._monitorsChangedId) {
            Main.layoutManager.disconnect(this._monitorsChangedId);
            this._monitorsChangedId = null;
        }
        super.destroy();
    }
});

/**
 * SatasOS Start Menu
 * Slide-up panel with search, pinned apps grid, and recommended/recent files.
 */
const SatasOSStartMenu = GObject.registerClass(
class SatasOSStartMenu extends St.Widget {
    _init(extension) {
        super._init({
            name: 'satasos-start-menu',
            style_class: 'satasos-start-menu',
            reactive: true,
            visible: false,
            opacity: 0,
        });

        this._extension = extension;
        this._isOpen = false;
        this._monitor = Main.layoutManager.primaryMonitor;

        this.set_size(START_MENU_WIDTH, START_MENU_HEIGHT);
        this._reposition();

        const mainBox = new St.BoxLayout({
            style_class: 'satasos-start-menu-inner',
            vertical: true,
            x_expand: true,
            y_expand: true,
        });
        this.add_child(mainBox);

        this._buildSearchBar(mainBox);
        this._buildPinnedSection(mainBox);
        this._buildRecommendedSection(mainBox);
        this._buildFooter(mainBox);
    }

    _reposition() {
        const x = Math.round((this._monitor.width - START_MENU_WIDTH) / 2) + this._monitor.x;
        const y = this._monitor.y + this._monitor.height - TASKBAR_HEIGHT - START_MENU_HEIGHT - 8;
        this.set_position(x, y);
    }

    _buildSearchBar(container) {
        const searchBox = new St.BoxLayout({
            style_class: 'satasos-search-box',
            x_expand: true,
        });
        const searchIcon = new St.Icon({
            icon_name: 'edit-find-symbolic',
            icon_size: 16,
            style_class: 'satasos-search-icon',
        });
        searchBox.add_child(searchIcon);

        this._searchEntry = new St.Entry({
            style_class: 'satasos-search-entry',
            hint_text: 'Type to search apps, files, settings…',
            can_focus: true,
            x_expand: true,
        });
        this._searchEntry.clutter_text.connect('text-changed', () => {
            this._onSearchTextChanged();
        });
        searchBox.add_child(this._searchEntry);
        container.add_child(searchBox);
    }

    _buildPinnedSection(container) {
        const pinnedHeader = new St.BoxLayout({
            style_class: 'satasos-section-header',
            x_expand: true,
        });
        pinnedHeader.add_child(new St.Label({
            text: 'Pinned',
            style_class: 'satasos-section-title',
            y_align: Clutter.ActorAlign.CENTER,
        }));
        pinnedHeader.add_child(new St.Widget({ x_expand: true }));
        const allAppsBtn = new St.Button({
            style_class: 'satasos-section-link',
            label: 'All apps →',
            reactive: true,
            can_focus: true,
        });
        allAppsBtn.connect('clicked', () => {
            this.close();
            this._extension.toggleAppDrawer();
        });
        pinnedHeader.add_child(allAppsBtn);
        container.add_child(pinnedHeader);

        const pinnedScroll = new St.ScrollView({
            style_class: 'satasos-pinned-scroll',
            x_expand: true,
            y_expand: true,
            overlay_scrollbars: true,
        });

        this._pinnedGrid = new St.Widget({
            style_class: 'satasos-pinned-grid',
            layout_manager: new Clutter.FlowLayout({
                orientation: Clutter.Orientation.HORIZONTAL,
                homogeneous: true,
                column_spacing: 12,
                row_spacing: 12,
            }),
            x_expand: true,
        });

        pinnedScroll.set_child(this._pinnedGrid);
        container.add_child(pinnedScroll);
        this._populatePinnedApps();
    }

    _populatePinnedApps() {
        this._pinnedGrid.destroy_all_children();
        const appSystem = Shell.AppSystem.get_default();
        const favorites = global.settings.get_strv('favorite-apps');
        const allApps = appSystem.get_installed();

        const appsToShow = favorites.length > 0
            ? favorites.map(id => appSystem.lookup_app(id)).filter(Boolean)
            : allApps.slice(0, 18);

        for (const app of appsToShow) {
            const appButton = new St.Button({
                style_class: 'satasos-pinned-app',
                reactive: true,
                can_focus: true,
                track_hover: true,
            });
            const appBox = new St.BoxLayout({
                vertical: true,
                x_align: Clutter.ActorAlign.CENTER,
                y_align: Clutter.ActorAlign.CENTER,
                style_class: 'satasos-pinned-app-inner',
            });
            const icon = app.create_icon_texture(PINNED_ICON_SIZE);
            appBox.add_child(icon);
            appBox.add_child(new St.Label({
                text: app.get_name(),
                style_class: 'satasos-pinned-app-label',
                x_align: Clutter.ActorAlign.CENTER,
            }));
            appButton.set_child(appBox);
            appButton.connect('clicked', () => {
                app.activate();
                this.close();
            });
            this._pinnedGrid.add_child(appButton);
        }
    }

    _buildRecommendedSection(container) {
        const recHeader = new St.BoxLayout({
            style_class: 'satasos-section-header',
            x_expand: true,
        });
        recHeader.add_child(new St.Label({
            text: 'Recommended',
            style_class: 'satasos-section-title',
            y_align: Clutter.ActorAlign.CENTER,
        }));
        recHeader.add_child(new St.Widget({ x_expand: true }));
        const moreBtn = new St.Button({
            style_class: 'satasos-section-link',
            label: 'More →',
            reactive: true,
            can_focus: true,
        });
        recHeader.add_child(moreBtn);
        container.add_child(recHeader);

        this._recommendedBox = new St.BoxLayout({
            style_class: 'satasos-recommended-list',
            vertical: true,
            x_expand: true,
        });
        container.add_child(this._recommendedBox);
        this._populateRecommended();
    }

    _populateRecommended() {
        this._recommendedBox.destroy_all_children();
        const recentManager = Shell.AppSystem.get_default();
        const running = recentManager.get_running();

        const items = running.slice(0, 4);
        for (const app of items) {
            const row = new St.BoxLayout({
                style_class: 'satasos-recommended-item',
                x_expand: true,
                reactive: true,
                track_hover: true,
            });
            const icon = app.create_icon_texture(32);
            row.add_child(icon);
            const labelBox = new St.BoxLayout({ vertical: true, x_expand: true });
            labelBox.add_child(new St.Label({
                text: app.get_name(),
                style_class: 'satasos-recommended-name',
            }));
            labelBox.add_child(new St.Label({
                text: 'Recently used',
                style_class: 'satasos-recommended-detail',
            }));
            row.add_child(labelBox);
            this._recommendedBox.add_child(row);
        }

        if (items.length === 0) {
            this._recommendedBox.add_child(new St.Label({
                text: 'No recent activity',
                style_class: 'satasos-recommended-empty',
            }));
        }
    }

    _buildFooter(container) {
        const footer = new St.BoxLayout({
            style_class: 'satasos-start-footer',
            x_expand: true,
        });

        const userButton = new St.Button({
            style_class: 'satasos-footer-button',
            reactive: true,
            can_focus: true,
            track_hover: true,
        });
        const userBox = new St.BoxLayout({ y_align: Clutter.ActorAlign.CENTER });
        userBox.add_child(new St.Icon({
            icon_name: 'avatar-default-symbolic',
            icon_size: 20,
            style_class: 'satasos-footer-icon',
        }));
        userBox.add_child(new St.Label({
            text: GLib.get_real_name() || GLib.get_user_name(),
            style_class: 'satasos-footer-label',
            y_align: Clutter.ActorAlign.CENTER,
        }));
        userButton.set_child(userBox);
        footer.add_child(userButton);

        footer.add_child(new St.Widget({ x_expand: true }));

        const powerButton = new St.Button({
            style_class: 'satasos-footer-button satasos-power-button',
            reactive: true,
            can_focus: true,
            track_hover: true,
        });
        powerButton.set_child(new St.Icon({
            icon_name: 'system-shutdown-symbolic',
            icon_size: 20,
            style_class: 'satasos-footer-icon',
        }));
        footer.add_child(powerButton);
        container.add_child(footer);
    }

    _onSearchTextChanged() {
        const text = this._searchEntry.get_text().toLowerCase().trim();
        if (text.length === 0) {
            this._populatePinnedApps();
            return;
        }
        this._pinnedGrid.destroy_all_children();
        const appSystem = Shell.AppSystem.get_default();
        const allApps = appSystem.get_installed();
        const matches = allApps.filter(app => {
            const name = app.get_name()?.toLowerCase() ?? '';
            const desc = app.get_description()?.toLowerCase() ?? '';
            return name.includes(text) || desc.includes(text);
        }).slice(0, 18);

        for (const app of matches) {
            const appButton = new St.Button({
                style_class: 'satasos-pinned-app',
                reactive: true,
                can_focus: true,
                track_hover: true,
            });
            const appBox = new St.BoxLayout({
                vertical: true,
                x_align: Clutter.ActorAlign.CENTER,
                style_class: 'satasos-pinned-app-inner',
            });
            const icon = app.create_icon_texture(PINNED_ICON_SIZE);
            appBox.add_child(icon);
            appBox.add_child(new St.Label({
                text: app.get_name(),
                style_class: 'satasos-pinned-app-label',
                x_align: Clutter.ActorAlign.CENTER,
            }));
            appButton.set_child(appBox);
            appButton.connect('clicked', () => {
                app.activate();
                this.close();
            });
            this._pinnedGrid.add_child(appButton);
        }
    }

    open(focusSearch = false) {
        if (this._isOpen) return;
        this._isOpen = true;
        this._reposition();
        this._populateRecommended();
        this.show();
        this.ease({
            opacity: 255,
            duration: 200,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
            onComplete: () => {
                if (focusSearch) {
                    this._searchEntry.grab_key_focus();
                }
            },
        });
    }

    close() {
        if (!this._isOpen) return;
        this._isOpen = false;
        this._searchEntry.set_text('');
        this.ease({
            opacity: 0,
            duration: 150,
            mode: Clutter.AnimationMode.EASE_IN_QUAD,
            onComplete: () => {
                this.hide();
            },
        });
    }

    toggle(focusSearch = false) {
        if (this._isOpen) {
            this.close();
        } else {
            this.open(focusSearch);
        }
    }
});

/**
 * SatasOS App Drawer
 * Full-screen overlay showing all installed applications in a scrollable grid.
 */
const SatasOSAppDrawer = GObject.registerClass(
class SatasOSAppDrawer extends St.Widget {
    _init(extension) {
        super._init({
            name: 'satasos-app-drawer',
            style_class: 'satasos-app-drawer',
            reactive: true,
            visible: false,
            opacity: 0,
        });

        this._extension = extension;
        this._isOpen = false;
        this._monitor = Main.layoutManager.primaryMonitor;

        this.set_position(this._monitor.x, this._monitor.y);
        this.set_size(this._monitor.width, this._monitor.height);

        const overlay = new St.BoxLayout({
            style_class: 'satasos-app-drawer-overlay',
            vertical: true,
            x_expand: true,
            y_expand: true,
        });
        this.add_child(overlay);

        const searchRow = new St.BoxLayout({
            style_class: 'satasos-drawer-search-row',
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._drawerSearchEntry = new St.Entry({
            style_class: 'satasos-drawer-search-entry',
            hint_text: 'Search all applications…',
            can_focus: true,
        });
        this._drawerSearchEntry.set_width(400);
        this._drawerSearchEntry.clutter_text.connect('text-changed', () => {
            this._filterApps();
        });
        searchRow.add_child(this._drawerSearchEntry);
        overlay.add_child(searchRow);

        const scrollView = new St.ScrollView({
            style_class: 'satasos-drawer-scroll',
            x_expand: true,
            y_expand: true,
            overlay_scrollbars: true,
        });

        this._appGrid = new St.Widget({
            style_class: 'satasos-app-grid',
            layout_manager: new Clutter.FlowLayout({
                orientation: Clutter.Orientation.HORIZONTAL,
                homogeneous: true,
                column_spacing: 24,
                row_spacing: 24,
            }),
            x_expand: true,
            x_align: Clutter.ActorAlign.CENTER,
        });

        scrollView.set_child(this._appGrid);
        overlay.add_child(scrollView);

        this.connect('button-press-event', (actor, event) => {
            const [stageX, stageY] = event.get_coords();
            const childAtPos = actor.get_stage().get_actor_at_pos(Clutter.PickMode.REACTIVE, stageX, stageY);
            if (childAtPos === this) {
                this.close();
                return Clutter.EVENT_STOP;
            }
            return Clutter.EVENT_PROPAGATE;
        });
    }

    _populateApps() {
        this._appGrid.destroy_all_children();
        const appSystem = Shell.AppSystem.get_default();
        const allApps = appSystem.get_installed().sort((a, b) => {
            return (a.get_name() || '').localeCompare(b.get_name() || '');
        });

        for (const app of allApps) {
            this._addAppToGrid(app);
        }
    }

    _addAppToGrid(app) {
        const button = new St.Button({
            style_class: 'satasos-drawer-app',
            reactive: true,
            can_focus: true,
            track_hover: true,
        });
        const box = new St.BoxLayout({
            vertical: true,
            x_align: Clutter.ActorAlign.CENTER,
            style_class: 'satasos-drawer-app-inner',
        });
        const icon = app.create_icon_texture(64);
        box.add_child(icon);
        box.add_child(new St.Label({
            text: app.get_name(),
            style_class: 'satasos-drawer-app-label',
            x_align: Clutter.ActorAlign.CENTER,
        }));
        button.set_child(box);
        button._app = app;
        button.connect('clicked', () => {
            app.activate();
            this.close();
        });
        this._appGrid.add_child(button);
    }

    _filterApps() {
        const query = this._drawerSearchEntry.get_text().toLowerCase().trim();
        const children = this._appGrid.get_children();
        for (const child of children) {
            if (!child._app) continue;
            const name = child._app.get_name()?.toLowerCase() ?? '';
            const desc = child._app.get_description()?.toLowerCase() ?? '';
            child.visible = query.length === 0 || name.includes(query) || desc.includes(query);
        }
    }

    open() {
        if (this._isOpen) return;
        this._isOpen = true;
        this._populateApps();
        this._drawerSearchEntry.set_text('');
        this.show();
        this.ease({
            opacity: 255,
            duration: 250,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
            onComplete: () => {
                this._drawerSearchEntry.grab_key_focus();
            },
        });
    }

    close() {
        if (!this._isOpen) return;
        this._isOpen = false;
        this.ease({
            opacity: 0,
            duration: 200,
            mode: Clutter.AnimationMode.EASE_IN_QUAD,
            onComplete: () => {
                this.hide();
                this._appGrid.destroy_all_children();
            },
        });
    }

    toggle() {
        if (this._isOpen) this.close();
        else this.open();
    }
});

/**
 * SatasOS Notification Shade
 * Slide-down panel with notifications, quick-settings toggles, and media controls.
 */
const SatasOSNotificationShade = GObject.registerClass(
class SatasOSNotificationShade extends St.Widget {
    _init(extension) {
        super._init({
            name: 'satasos-notification-shade',
            style_class: 'satasos-notification-shade',
            reactive: true,
            visible: false,
            opacity: 0,
        });

        this._extension = extension;
        this._isOpen = false;
        this._monitor = Main.layoutManager.primaryMonitor;

        this.set_size(NOTIFICATION_WIDTH, this._monitor.height - TASKBAR_HEIGHT);
        this.set_position(
            this._monitor.x + this._monitor.width - NOTIFICATION_WIDTH - 8,
            this._monitor.y
        );

        const mainBox = new St.BoxLayout({
            style_class: 'satasos-notification-inner',
            vertical: true,
            x_expand: true,
            y_expand: true,
        });
        this.add_child(mainBox);

        this._buildQuickSettings(mainBox);
        this._buildNotificationList(mainBox);
    }

    _buildQuickSettings(container) {
        const qsBox = new St.BoxLayout({
            style_class: 'satasos-quick-settings',
            x_expand: true,
        });

        const toggles = [
            { icon: 'network-wireless-symbolic', label: 'Wi-Fi', active: true },
            { icon: 'bluetooth-active-symbolic', label: 'Bluetooth', active: false },
            { icon: 'night-light-symbolic', label: 'Night Light', active: false },
            { icon: 'airplane-mode-symbolic', label: 'Airplane', active: false },
            { icon: 'thunderbolt-symbolic', label: 'Power Saver', active: false },
            { icon: 'rotation-locked-symbolic', label: 'Rotation', active: false },
        ];

        const grid = new St.Widget({
            style_class: 'satasos-qs-grid',
            layout_manager: new Clutter.FlowLayout({
                orientation: Clutter.Orientation.HORIZONTAL,
                homogeneous: true,
                column_spacing: 8,
                row_spacing: 8,
            }),
            x_expand: true,
        });

        for (const toggle of toggles) {
            const btn = new St.Button({
                style_class: `satasos-qs-toggle ${toggle.active ? 'active' : ''}`,
                reactive: true,
                can_focus: true,
                track_hover: true,
            });
            const inner = new St.BoxLayout({
                vertical: true,
                x_align: Clutter.ActorAlign.CENTER,
                y_align: Clutter.ActorAlign.CENTER,
            });
            inner.add_child(new St.Icon({
                icon_name: toggle.icon,
                icon_size: 20,
                style_class: 'satasos-qs-icon',
            }));
            inner.add_child(new St.Label({
                text: toggle.label,
                style_class: 'satasos-qs-label',
                x_align: Clutter.ActorAlign.CENTER,
            }));
            btn.set_child(inner);
            btn.connect('clicked', () => {
                btn.toggle_style_class_name('active');
            });
            grid.add_child(btn);
        }

        qsBox.add_child(grid);
        container.add_child(qsBox);

        const brightnessRow = new St.BoxLayout({
            style_class: 'satasos-slider-row',
            x_expand: true,
        });
        brightnessRow.add_child(new St.Icon({
            icon_name: 'display-brightness-symbolic',
            icon_size: 16,
            style_class: 'satasos-slider-icon',
        }));
        const brightnessSlider = new St.Widget({
            style_class: 'satasos-slider',
            x_expand: true,
            reactive: true,
        });
        const brightnessTrack = new St.Widget({
            style_class: 'satasos-slider-track',
            x_expand: true,
        });
        const brightnessFill = new St.Widget({
            style_class: 'satasos-slider-fill',
        });
        brightnessFill.set_width(200);
        brightnessTrack.add_child(brightnessFill);
        brightnessSlider.add_child(brightnessTrack);
        brightnessRow.add_child(brightnessSlider);
        container.add_child(brightnessRow);

        const volumeRow = new St.BoxLayout({
            style_class: 'satasos-slider-row',
            x_expand: true,
        });
        volumeRow.add_child(new St.Icon({
            icon_name: 'audio-volume-high-symbolic',
            icon_size: 16,
            style_class: 'satasos-slider-icon',
        }));
        const volumeSlider = new St.Widget({
            style_class: 'satasos-slider',
            x_expand: true,
            reactive: true,
        });
        const volumeTrack = new St.Widget({
            style_class: 'satasos-slider-track',
            x_expand: true,
        });
        const volumeFill = new St.Widget({
            style_class: 'satasos-slider-fill',
        });
        volumeFill.set_width(150);
        volumeTrack.add_child(volumeFill);
        volumeSlider.add_child(volumeTrack);
        volumeRow.add_child(volumeSlider);
        container.add_child(volumeRow);
    }

    _buildNotificationList(container) {
        const headerBox = new St.BoxLayout({
            style_class: 'satasos-notif-header',
            x_expand: true,
        });
        headerBox.add_child(new St.Label({
            text: 'Notifications',
            style_class: 'satasos-notif-title',
            y_align: Clutter.ActorAlign.CENTER,
        }));
        headerBox.add_child(new St.Widget({ x_expand: true }));
        const clearBtn = new St.Button({
            style_class: 'satasos-notif-clear-btn',
            label: 'Clear all',
            reactive: true,
            can_focus: true,
        });
        clearBtn.connect('clicked', () => {
            this._notifList.destroy_all_children();
            this._showEmptyState();
        });
        headerBox.add_child(clearBtn);
        container.add_child(headerBox);

        const scrollView = new St.ScrollView({
            style_class: 'satasos-notif-scroll',
            x_expand: true,
            y_expand: true,
            overlay_scrollbars: true,
        });

        this._notifList = new St.BoxLayout({
            style_class: 'satasos-notif-list',
            vertical: true,
            x_expand: true,
        });

        scrollView.set_child(this._notifList);
        container.add_child(scrollView);
        this._showEmptyState();
    }

    _showEmptyState() {
        this._notifList.destroy_all_children();
        const emptyBox = new St.BoxLayout({
            style_class: 'satasos-notif-empty',
            vertical: true,
            x_expand: true,
            y_expand: true,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
        });
        emptyBox.add_child(new St.Icon({
            icon_name: 'notifications-disabled-symbolic',
            icon_size: 48,
            style_class: 'satasos-notif-empty-icon',
        }));
        emptyBox.add_child(new St.Label({
            text: 'No notifications',
            style_class: 'satasos-notif-empty-label',
        }));
        this._notifList.add_child(emptyBox);
    }

    open() {
        if (this._isOpen) return;
        this._isOpen = true;
        this.show();
        this.ease({
            opacity: 255,
            duration: 200,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
        });
    }

    close() {
        if (!this._isOpen) return;
        this._isOpen = false;
        this.ease({
            opacity: 0,
            duration: 150,
            mode: Clutter.AnimationMode.EASE_IN_QUAD,
            onComplete: () => {
                this.hide();
            },
        });
    }

    toggle() {
        if (this._isOpen) this.close();
        else this.open();
    }
});

/**
 * SatasOS Lock Screen Overlay
 */
const SatasOSLockScreen = GObject.registerClass(
class SatasOSLockScreen extends St.Widget {
    _init(extension) {
        super._init({
            name: 'satasos-lock-screen',
            style_class: 'satasos-lock-screen',
            reactive: true,
            visible: false,
            opacity: 0,
        });

        this._extension = extension;
        this._isLocked = false;
        this._monitor = Main.layoutManager.primaryMonitor;
        this.set_position(this._monitor.x, this._monitor.y);
        this.set_size(this._monitor.width, this._monitor.height);

        const center = new St.BoxLayout({
            style_class: 'satasos-lock-center',
            vertical: true,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            x_expand: true,
            y_expand: true,
        });

        this._lockClock = new St.Label({
            style_class: 'satasos-lock-clock',
            x_align: Clutter.ActorAlign.CENTER,
        });
        center.add_child(this._lockClock);

        this._lockDate = new St.Label({
            style_class: 'satasos-lock-date',
            x_align: Clutter.ActorAlign.CENTER,
        });
        center.add_child(this._lockDate);

        center.add_child(new St.Icon({
            icon_name: 'avatar-default-symbolic',
            icon_size: 80,
            style_class: 'satasos-lock-avatar',
            x_align: Clutter.ActorAlign.CENTER,
        }));

        center.add_child(new St.Label({
            text: GLib.get_real_name() || GLib.get_user_name(),
            style_class: 'satasos-lock-username',
            x_align: Clutter.ActorAlign.CENTER,
        }));

        const passwordEntry = new St.Entry({
            style_class: 'satasos-lock-password',
            hint_text: 'Password',
            can_focus: true,
            x_align: Clutter.ActorAlign.CENTER,
        });
        passwordEntry.clutter_text.set_password_char('●');
        center.add_child(passwordEntry);

        this.add_child(center);
    }

    _updateLockClock() {
        const now = GLib.DateTime.new_now_local();
        this._lockClock.set_text(now.format('%l:%M %p').trim());
        this._lockDate.set_text(now.format('%A, %B %e'));
    }
});


/**
 * Main SatasOS Shell Extension
 */
export default class SatasOSShellExtension extends Extension {
    enable() {
        this._originalPanelVisible = Main.panel.visible;
        Main.panel.hide();

        if (Main.panel.get_parent()) {
            this._panelWasInChrome = true;
        }

        Main.layoutManager._updateHotCorners?.();

        this._taskbar = new SatasOSTaskbar(this);
        this._startMenu = new SatasOSStartMenu(this);
        this._appDrawer = new SatasOSAppDrawer(this);
        this._notificationShade = new SatasOSNotificationShade(this);
        this._lockScreen = new SatasOSLockScreen(this);

        Main.layoutManager.addTopChrome(this._taskbar, {
            affectsStruts: true,
            trackFullscreen: true,
        });

        Main.uiGroup.add_child(this._startMenu);
        Main.uiGroup.add_child(this._appDrawer);
        Main.uiGroup.add_child(this._notificationShade);
        Main.uiGroup.add_child(this._lockScreen);

        this._setupKeyBindings();
        this._setupGlobalClickHandler();

        this._workAreaAdjustTimerId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
            this._adjustWorkArea();
            this._workAreaAdjustTimerId = null;
            return GLib.SOURCE_REMOVE;
        });
    }

    disable() {
        this._removeKeyBindings();

        if (this._globalClickId) {
            global.stage.disconnect(this._globalClickId);
            this._globalClickId = null;
        }

        if (this._workAreaAdjustTimerId) {
            GLib.source_remove(this._workAreaAdjustTimerId);
            this._workAreaAdjustTimerId = null;
        }

        if (this._taskbar) {
            Main.layoutManager.removeChrome(this._taskbar);
            this._taskbar.destroy();
            this._taskbar = null;
        }

        if (this._startMenu) {
            this._startMenu.close();
            Main.uiGroup.remove_child(this._startMenu);
            this._startMenu.destroy();
            this._startMenu = null;
        }

        if (this._appDrawer) {
            this._appDrawer.close();
            Main.uiGroup.remove_child(this._appDrawer);
            this._appDrawer.destroy();
            this._appDrawer = null;
        }

        if (this._notificationShade) {
            this._notificationShade.close();
            Main.uiGroup.remove_child(this._notificationShade);
            this._notificationShade.destroy();
            this._notificationShade = null;
        }

        if (this._lockScreen) {
            Main.uiGroup.remove_child(this._lockScreen);
            this._lockScreen.destroy();
            this._lockScreen = null;
        }

        Main.panel.show();
        Main.layoutManager._updateHotCorners?.();
    }

    _setupKeyBindings() {
        Main.wm.addKeybinding(
            'toggle-start-menu',
            new Gio.Settings({ schema_id: 'org.gnome.mutter.keybindings' }),
            Meta.KeyBindingFlags.IGNORE_AUTOREPEAT,
            Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW,
            () => {
                this.toggleStartMenu();
            }
        );

        this._superKeyPressId = global.display.connect('overlay-key', () => {
            this.toggleStartMenu();
        });
    }

    _removeKeyBindings() {
        try {
            Main.wm.removeKeybinding('toggle-start-menu');
        } catch (e) {
            // Binding may not exist
        }

        if (this._superKeyPressId) {
            global.display.disconnect(this._superKeyPressId);
            this._superKeyPressId = null;
        }
    }

    _setupGlobalClickHandler() {
        this._globalClickId = global.stage.connect('button-press-event', (actor, event) => {
            const [x, y] = event.get_coords();
            if (this._startMenu?._isOpen && !this._startMenu.contains(global.stage.get_actor_at_pos(Clutter.PickMode.REACTIVE, x, y))) {
                const startBtnAtPos = this._taskbar?._startButton?.contains(global.stage.get_actor_at_pos(Clutter.PickMode.REACTIVE, x, y));
                if (!startBtnAtPos) {
                    this._startMenu.close();
                }
            }
            if (this._notificationShade?._isOpen) {
                const shadeActor = global.stage.get_actor_at_pos(Clutter.PickMode.REACTIVE, x, y);
                if (!this._notificationShade.contains(shadeActor) && !this._taskbar?._trayBox?.contains(shadeActor) && !this._taskbar?._clockLabel?.get_parent()?.contains(shadeActor)) {
                    this._notificationShade.close();
                }
            }
            return Clutter.EVENT_PROPAGATE;
        });
    }

    _adjustWorkArea() {
        const monitor = Main.layoutManager.primaryMonitor;
        if (monitor) {
            Main.layoutManager._updateHotCorners?.();
        }
    }

    toggleStartMenu(focusSearch = false) {
        if (this._appDrawer?._isOpen) {
            this._appDrawer.close();
        }
        if (this._notificationShade?._isOpen) {
            this._notificationShade.close();
        }
        this._startMenu?.toggle(focusSearch);
    }

    toggleAppDrawer() {
        if (this._startMenu?._isOpen) {
            this._startMenu.close();
        }
        if (this._notificationShade?._isOpen) {
            this._notificationShade.close();
        }
        this._appDrawer?.toggle();
    }

    toggleNotificationShade() {
        if (this._startMenu?._isOpen) {
            this._startMenu.close();
        }
        if (this._appDrawer?._isOpen) {
            this._appDrawer.close();
        }
        this._notificationShade?.toggle();
    }
}
