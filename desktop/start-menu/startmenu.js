// SatasOS Start Menu - Windows 11 Style
// GNOME 45+ ESM Import Style

import St from 'gi://St';
import Clutter from 'gi://Clutter';
import Shell from 'gi://Shell';
import Meta from 'gi://Meta';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Gio from 'gi://Gio';
import Pango from 'gi://Pango';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const MENU_WIDTH = 640;
const MENU_HEIGHT = 700;
const GRID_COLUMNS = 6;
const GRID_ICON_SIZE = 36;
const GRID_ITEM_SIZE = 88;
const BRAND_PRIMARY = '#7C3AED';
const BRAND_HOVER = '#6D28D9';
const BRAND_ACTIVE = '#5B21B6';
const DARK_BG = '#1E1B2E';
const DARK_SURFACE = '#2D2640';
const LIGHT_TEXT = '#E8E0F0';
const TASKBAR_HEIGHT = 48;
const ANIM_DURATION = 250;

const DEFAULT_PINNED_APPS = [
    'org.gnome.Nautilus.desktop',
    'firefox.desktop',
    'org.gnome.Terminal.desktop',
    'org.gnome.Settings.desktop',
    'org.gnome.TextEditor.desktop',
    'org.gnome.Calculator.desktop',
    'org.gnome.Software.desktop',
    'org.gnome.Evince.desktop',
    'org.gnome.clocks.desktop',
    'org.gnome.Calendar.desktop',
    'org.gnome.Weather.desktop',
    'org.gnome.Maps.desktop',
    'org.gnome.Music.desktop',
    'org.gnome.Photos.desktop',
    'org.gnome.Contacts.desktop',
    'org.gnome.Characters.desktop',
    'org.gnome.DiskUtility.desktop',
    'org.gnome.SystemMonitor.desktop',
];

// ─── AppGridItem ─────────────────────────────────────────────────────────────

const AppGridItem = GObject.registerClass(
class AppGridItem extends St.Button {
    _init(app) {
        super._init({
            style_class: 'app-grid-item',
            reactive: true,
            can_focus: true,
            track_hover: true,
            width: GRID_ITEM_SIZE,
            height: GRID_ITEM_SIZE,
            style: `
                border-radius: 10px;
                padding: 8px 4px;
                background-color: transparent;
                transition-duration: 150ms;
            `,
        });

        this._app = app;

        const layout = new St.BoxLayout({
            vertical: true,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            style: 'spacing: 6px;',
        });

        const icon = app.create_icon_texture(GRID_ICON_SIZE);
        icon.set({
            x_align: Clutter.ActorAlign.CENTER,
        });
        layout.add_child(icon);

        const label = new St.Label({
            text: app.get_name(),
            style: `
                color: ${LIGHT_TEXT};
                font-size: 11px;
                text-align: center;
            `,
            x_align: Clutter.ActorAlign.CENTER,
        });
        label.clutter_text.set_line_wrap(false);
        label.clutter_text.set_ellipsize(Pango.EllipsizeMode.END);
        label.set_width(GRID_ITEM_SIZE - 8);
        layout.add_child(label);

        this.set_child(layout);

        this.connect('notify::hover', () => {
            this.style = `
                border-radius: 10px;
                padding: 8px 4px;
                background-color: ${this.hover ? 'rgba(124, 58, 237, 0.15)' : 'transparent'};
                transition-duration: 150ms;
            `;
        });

        this.connect('clicked', () => {
            app.open_new_window(-1);
        });
    }

    getApp() {
        return this._app;
    }
});

// ─── AllAppsListItem ─────────────────────────────────────────────────────────

const AllAppsListItem = GObject.registerClass(
class AllAppsListItem extends St.Button {
    _init(app) {
        super._init({
            style_class: 'all-apps-list-item',
            reactive: true,
            can_focus: true,
            track_hover: true,
            style: `
                border-radius: 8px;
                padding: 8px 16px;
                background-color: transparent;
                transition-duration: 100ms;
            `,
            x_expand: true,
        });

        this._app = app;

        const layout = new St.BoxLayout({
            style: 'spacing: 12px;',
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
        });

        const icon = app.create_icon_texture(24);
        icon.set({ y_align: Clutter.ActorAlign.CENTER });
        layout.add_child(icon);

        const label = new St.Label({
            text: app.get_name(),
            style: `
                color: ${LIGHT_TEXT};
                font-size: 13px;
            `,
            y_align: Clutter.ActorAlign.CENTER,
            x_expand: true,
        });
        layout.add_child(label);

        this.set_child(layout);

        this.connect('notify::hover', () => {
            this.style = `
                border-radius: 8px;
                padding: 8px 16px;
                background-color: ${this.hover ? 'rgba(124, 58, 237, 0.12)' : 'transparent'};
                transition-duration: 100ms;
            `;
        });

        this.connect('clicked', () => {
            app.open_new_window(-1);
        });
    }

    getApp() {
        return this._app;
    }
});

// ─── PowerMenu ───────────────────────────────────────────────────────────────

const PowerMenu = GObject.registerClass(
class PowerMenu extends St.Widget {
    _init() {
        super._init({
            style: `
                background-color: ${DARK_SURFACE};
                border-radius: 12px;
                padding: 8px;
                border: 1px solid rgba(124, 58, 237, 0.25);
            `,
            visible: false,
            reactive: true,
            layout_manager: new Clutter.BoxLayout({
                orientation: Clutter.Orientation.VERTICAL,
                spacing: 2,
            }),
        });

        const items = [
            { label: 'Shut down', icon: 'system-shutdown-symbolic', action: 'shutdown' },
            { label: 'Restart', icon: 'system-reboot-symbolic', action: 'restart' },
            { label: 'Suspend', icon: 'media-playback-pause-symbolic', action: 'suspend' },
            { label: 'Log Out', icon: 'system-log-out-symbolic', action: 'logout' },
        ];

        for (const item of items) {
            const btn = new St.Button({
                reactive: true,
                can_focus: true,
                track_hover: true,
                style: `
                    border-radius: 8px;
                    padding: 10px 16px;
                    background-color: transparent;
                    transition-duration: 100ms;
                `,
                x_expand: true,
            });

            const layout = new St.BoxLayout({
                style: 'spacing: 10px;',
                x_expand: true,
            });

            const icon = new St.Icon({
                icon_name: item.icon,
                icon_size: 18,
                style: `color: ${LIGHT_TEXT};`,
                y_align: Clutter.ActorAlign.CENTER,
            });
            layout.add_child(icon);

            const label = new St.Label({
                text: item.label,
                style: `
                    color: ${LIGHT_TEXT};
                    font-size: 13px;
                `,
                y_align: Clutter.ActorAlign.CENTER,
                x_expand: true,
            });
            layout.add_child(label);

            btn.set_child(layout);

            btn.connect('notify::hover', () => {
                let bg = 'transparent';
                if (btn.hover) {
                    bg = item.action === 'shutdown'
                        ? 'rgba(239, 68, 68, 0.25)'
                        : 'rgba(124, 58, 237, 0.15)';
                }
                btn.style = `
                    border-radius: 8px;
                    padding: 10px 16px;
                    background-color: ${bg};
                    transition-duration: 100ms;
                `;
            });

            btn.connect('clicked', () => {
                this._executePowerAction(item.action);
            });

            this.add_child(btn);
        }
    }

    _executePowerAction(action) {
        try {
            switch (action) {
            case 'shutdown':
                this._callLogin1Method('PowerOff', true);
                break;
            case 'restart':
                this._callLogin1Method('Reboot', true);
                break;
            case 'suspend':
                this._callLogin1Method('Suspend', true);
                break;
            case 'logout':
                Meta.quit(Meta.ExitCode.SUCCESS);
                break;
            }
        } catch (e) {
            logError(e, 'Power action failed');
        }
    }

    _callLogin1Method(method, interactive) {
        const bus = Gio.DBusProxy.new_for_bus_sync(
            Gio.BusType.SYSTEM,
            Gio.DBusProxyFlags.NONE,
            null,
            'org.freedesktop.login1',
            '/org/freedesktop/login1',
            'org.freedesktop.login1.Manager',
            null
        );
        bus.call_sync(
            method,
            new GLib.Variant('(b)', [interactive]),
            Gio.DBusCallFlags.NONE,
            -1,
            null
        );
    }

    toggle() {
        if (this.visible) {
            this.ease({
                opacity: 0,
                scale_y: 0.9,
                duration: 150,
                mode: Clutter.AnimationMode.EASE_IN_QUAD,
                onComplete: () => {
                    this.visible = false;
                },
            });
        } else {
            this.visible = true;
            this.opacity = 0;
            this.scale_y = 0.9;
            this.ease({
                opacity: 255,
                scale_y: 1.0,
                duration: 200,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
            });
        }
    }
});

// ─── StartMenu ───────────────────────────────────────────────────────────────

export const StartMenu = GObject.registerClass(
{
    Signals: {
        'menu-toggled': { param_types: [GObject.TYPE_BOOLEAN] },
    },
},
class StartMenu extends St.Widget {
    _init() {
        const monitor = Main.layoutManager.primaryMonitor;

        super._init({
            name: 'satas-start-menu',
            reactive: true,
            visible: false,
            width: MENU_WIDTH,
            height: MENU_HEIGHT,
            x: Math.round((monitor.width - MENU_WIDTH) / 2),
            y: monitor.height - TASKBAR_HEIGHT - MENU_HEIGHT - 8,
            style: `
                background-color: ${DARK_BG};
                border-radius: 16px;
                border: 1px solid rgba(124, 58, 237, 0.2);
            `,
        });

        this._isOpen = false;
        this._showingAllApps = false;
        this._backdrop = null;
        this._superKeyId = null;

        this._buildUI();
        this._bindSuperKey();

        Main.layoutManager.addTopChrome(this);

        this.connect('destroy', this._onDestroy.bind(this));
    }

    _buildUI() {
        this._mainLayout = new St.BoxLayout({
            vertical: true,
            x_expand: true,
            y_expand: true,
            style: 'padding: 24px 20px 0 20px;',
        });
        this.add_child(this._mainLayout);

        this._buildSearchBar();
        this._buildContentArea();
        this._buildBottomBar();
    }

    // ── Search Bar ───────────────────────────────────────────────────────

    _buildSearchBar() {
        this._searchContainer = new St.BoxLayout({
            style: `
                background-color: ${DARK_SURFACE};
                border-radius: 24px;
                padding: 8px 16px;
                margin-bottom: 20px;
            `,
            x_expand: true,
        });

        const searchIcon = new St.Icon({
            icon_name: 'edit-find-symbolic',
            icon_size: 16,
            style: `
                color: rgba(232, 224, 240, 0.5);
                margin-right: 8px;
            `,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._searchContainer.add_child(searchIcon);

        this._searchEntry = new St.Entry({
            hint_text: 'Type to search',
            style: `
                color: ${LIGHT_TEXT};
                font-size: 14px;
                background-color: transparent;
                border: none;
                caret-color: ${BRAND_PRIMARY};
                selection-background-color: ${BRAND_PRIMARY};
            `,
            can_focus: true,
            x_expand: true,
        });

        this._searchEntry.clutter_text.connect('text-changed', () => {
            this._onSearchChanged();
        });

        this._searchEntry.clutter_text.connect('key-press-event', (_actor, event) => {
            const sym = event.get_key_symbol();
            if (sym === Clutter.KEY_Escape) {
                if (this._searchEntry.get_text().length > 0) {
                    this._searchEntry.set_text('');
                } else {
                    this.close();
                }
                return Clutter.EVENT_STOP;
            }
            return Clutter.EVENT_PROPAGATE;
        });

        this._searchContainer.add_child(this._searchEntry);
        this._mainLayout.add_child(this._searchContainer);
    }

    // ── Content Area (pinned apps + recommended, or all apps, or search results)

    _buildContentArea() {
        this._contentStack = new St.Widget({
            x_expand: true,
            y_expand: true,
            layout_manager: new Clutter.BinLayout(),
        });
        this._mainLayout.add_child(this._contentStack);

        this._buildPinnedView();
        this._buildAllAppsView();
        this._buildSearchResultsView();
    }

    _buildPinnedView() {
        this._pinnedView = new St.BoxLayout({
            vertical: true,
            x_expand: true,
            y_expand: true,
        });

        // "Pinned" header
        const pinnedHeader = new St.BoxLayout({
            style: 'margin-bottom: 12px;',
            x_expand: true,
        });

        const pinnedLabel = new St.Label({
            text: 'Pinned',
            style: `
                color: ${LIGHT_TEXT};
                font-size: 14px;
                font-weight: 600;
            `,
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
        });
        pinnedHeader.add_child(pinnedLabel);

        const allAppsBtn = new St.Button({
            reactive: true,
            can_focus: true,
            track_hover: true,
            style: `
                background-color: ${DARK_SURFACE};
                border-radius: 16px;
                padding: 6px 14px;
                transition-duration: 100ms;
            `,
        });

        const allAppsBtnLayout = new St.BoxLayout({ style: 'spacing: 6px;' });
        allAppsBtnLayout.add_child(new St.Label({
            text: 'All apps',
            style: `color: ${LIGHT_TEXT}; font-size: 12px;`,
            y_align: Clutter.ActorAlign.CENTER,
        }));
        allAppsBtnLayout.add_child(new St.Icon({
            icon_name: 'go-next-symbolic',
            icon_size: 12,
            style: `color: ${LIGHT_TEXT};`,
            y_align: Clutter.ActorAlign.CENTER,
        }));
        allAppsBtn.set_child(allAppsBtnLayout);

        allAppsBtn.connect('notify::hover', () => {
            allAppsBtn.style = `
                background-color: ${allAppsBtn.hover ? BRAND_HOVER : DARK_SURFACE};
                border-radius: 16px;
                padding: 6px 14px;
                transition-duration: 100ms;
            `;
        });
        allAppsBtn.connect('clicked', () => {
            this._showAllApps();
        });

        pinnedHeader.add_child(allAppsBtn);
        this._pinnedView.add_child(pinnedHeader);

        // Grid of pinned apps
        this._pinnedGrid = new St.Widget({
            layout_manager: new Clutter.GridLayout({
                orientation: Clutter.Orientation.HORIZONTAL,
                column_spacing: 4,
                row_spacing: 4,
            }),
            x_expand: true,
        });
        this._populatePinnedGrid();

        const pinnedScroll = new St.ScrollView({
            style: 'max-height: 280px;',
            x_expand: true,
            overlay_scrollbars: true,
        });
        pinnedScroll.set_child(this._pinnedGrid);
        this._pinnedView.add_child(pinnedScroll);

        // Separator
        this._pinnedView.add_child(new St.Widget({
            style: `
                height: 1px;
                background-color: rgba(232, 224, 240, 0.1);
                margin: 16px 0;
            `,
            x_expand: true,
        }));

        // "Recommended" section
        const recHeader = new St.Label({
            text: 'Recommended',
            style: `
                color: ${LIGHT_TEXT};
                font-size: 14px;
                font-weight: 600;
                margin-bottom: 12px;
            `,
        });
        this._pinnedView.add_child(recHeader);

        this._recommendedBox = new St.BoxLayout({
            vertical: true,
            x_expand: true,
            style: 'spacing: 2px;',
        });
        this._populateRecommended();

        const recScroll = new St.ScrollView({
            x_expand: true,
            y_expand: true,
            overlay_scrollbars: true,
        });
        recScroll.set_child(this._recommendedBox);
        this._pinnedView.add_child(recScroll);

        this._contentStack.add_child(this._pinnedView);
    }

    _populatePinnedGrid() {
        const appSystem = Shell.AppSystem.get_default();
        const gridLayout = this._pinnedGrid.layout_manager;
        let col = 0;
        let row = 0;

        for (const appId of DEFAULT_PINNED_APPS) {
            const app = appSystem.lookup_app(appId);
            if (!app) continue;

            const item = new AppGridItem(app);
            item.connect('clicked', () => {
                this.close();
            });
            gridLayout.attach(item, col, row, 1, 1);

            col++;
            if (col >= GRID_COLUMNS) {
                col = 0;
                row++;
            }
        }
    }

    _populateRecommended() {
        // Fetch recent files from GtkRecentManager via GIO
        try {
            const recentManager = new Gio.Settings({
                schema_id: 'org.gnome.desktop.privacy',
            });
            const recentEnabled = recentManager.get_boolean('remember-recent-files');

            if (recentEnabled) {
                this._loadRecentFiles();
            }
        } catch (e) {
            // Fallback: show recently used apps
            this._loadRecentApps();
        }
    }

    _loadRecentFiles() {
        try {
            const bookmarkFile = new GLib.BookmarkFile();
            const recentPath = GLib.build_filenamev([
                GLib.get_user_data_dir(), '..', 'recently-used.xbel',
            ]);

            let loaded = false;
            try {
                bookmarkFile.load_from_file(recentPath);
                loaded = true;
            } catch (e) {
                // Try alternate location
                const altPath = GLib.build_filenamev([
                    GLib.get_home_dir(), '.local', 'share', 'recently-used.xbel',
                ]);
                try {
                    bookmarkFile.load_from_file(altPath);
                    loaded = true;
                } catch (e2) {
                    // no recent files available
                }
            }

            if (loaded) {
                const uris = bookmarkFile.get_uris();
                const maxItems = Math.min(uris.length, 6);

                for (let i = 0; i < maxItems; i++) {
                    const uri = uris[i];
                    const file = Gio.File.new_for_uri(uri);
                    const basename = file.get_basename();
                    if (!basename) continue;

                    const recItem = this._createRecommendedItem(
                        basename,
                        'text-x-generic-symbolic',
                        uri
                    );
                    this._recommendedBox.add_child(recItem);
                }
            }

            if (this._recommendedBox.get_n_children() === 0) {
                this._loadRecentApps();
            }
        } catch (e) {
            this._loadRecentApps();
        }
    }

    _loadRecentApps() {
        const appSystem = Shell.AppSystem.get_default();
        const running = appSystem.get_running();
        const shown = new Set();
        const maxItems = 6;

        for (const app of running) {
            if (shown.size >= maxItems) break;
            const appId = app.get_id();
            if (shown.has(appId)) continue;
            shown.add(appId);

            const recItem = this._createRecommendedAppItem(app);
            this._recommendedBox.add_child(recItem);
        }

        // Fill remainder with installed apps
        const allApps = appSystem.get_installed().sort((a, b) => {
            return a.get_name().localeCompare(b.get_name());
        });
        for (const appInfo of allApps) {
            if (shown.size >= maxItems) break;
            const appId = appInfo.get_id();
            if (shown.has(appId)) continue;
            if (appInfo.should_show()) {
                const app = appSystem.lookup_app(appId);
                if (app) {
                    shown.add(appId);
                    const recItem = this._createRecommendedAppItem(app);
                    this._recommendedBox.add_child(recItem);
                }
            }
        }
    }

    _createRecommendedItem(label, iconName, uri) {
        const btn = new St.Button({
            reactive: true,
            can_focus: true,
            track_hover: true,
            style: `
                border-radius: 8px;
                padding: 8px 12px;
                background-color: transparent;
                transition-duration: 100ms;
            `,
            x_expand: true,
        });

        const layout = new St.BoxLayout({
            style: 'spacing: 10px;',
            x_expand: true,
        });

        layout.add_child(new St.Icon({
            icon_name: iconName,
            icon_size: 20,
            style: `color: rgba(232, 224, 240, 0.7);`,
            y_align: Clutter.ActorAlign.CENTER,
        }));

        const textBox = new St.BoxLayout({
            vertical: true,
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
        });

        textBox.add_child(new St.Label({
            text: label,
            style: `color: ${LIGHT_TEXT}; font-size: 12px;`,
        }));

        layout.add_child(textBox);
        btn.set_child(layout);

        btn.connect('notify::hover', () => {
            btn.style = `
                border-radius: 8px;
                padding: 8px 12px;
                background-color: ${btn.hover ? 'rgba(124, 58, 237, 0.1)' : 'transparent'};
                transition-duration: 100ms;
            `;
        });

        btn.connect('clicked', () => {
            try {
                Gio.AppInfo.launch_default_for_uri(uri, null);
            } catch (e) {
                logError(e, 'Failed to open recent file');
            }
            this.close();
        });

        return btn;
    }

    _createRecommendedAppItem(app) {
        const btn = new St.Button({
            reactive: true,
            can_focus: true,
            track_hover: true,
            style: `
                border-radius: 8px;
                padding: 8px 12px;
                background-color: transparent;
                transition-duration: 100ms;
            `,
            x_expand: true,
        });

        const layout = new St.BoxLayout({
            style: 'spacing: 10px;',
            x_expand: true,
        });

        const icon = app.create_icon_texture(20);
        icon.set({ y_align: Clutter.ActorAlign.CENTER });
        layout.add_child(icon);

        const textBox = new St.BoxLayout({
            vertical: true,
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
        });

        textBox.add_child(new St.Label({
            text: app.get_name(),
            style: `color: ${LIGHT_TEXT}; font-size: 12px;`,
        }));

        const desc = app.get_description();
        if (desc) {
            const descLabel = new St.Label({
                text: desc,
                style: `color: rgba(232, 224, 240, 0.5); font-size: 10px;`,
            });
            descLabel.clutter_text.set_ellipsize(Pango.EllipsizeMode.END);
            descLabel.set_width(200);
            textBox.add_child(descLabel);
        }

        layout.add_child(textBox);
        btn.set_child(layout);

        btn.connect('notify::hover', () => {
            btn.style = `
                border-radius: 8px;
                padding: 8px 12px;
                background-color: ${btn.hover ? 'rgba(124, 58, 237, 0.1)' : 'transparent'};
                transition-duration: 100ms;
            `;
        });

        btn.connect('clicked', () => {
            app.open_new_window(-1);
            this.close();
        });

        return btn;
    }

    _buildAllAppsView() {
        this._allAppsView = new St.BoxLayout({
            vertical: true,
            x_expand: true,
            y_expand: true,
            visible: false,
        });

        // "All apps" header with back button
        const allAppsHeader = new St.BoxLayout({
            style: 'margin-bottom: 12px;',
            x_expand: true,
        });

        const backBtn = new St.Button({
            reactive: true,
            can_focus: true,
            track_hover: true,
            style: `
                background-color: ${DARK_SURFACE};
                border-radius: 16px;
                padding: 6px 14px;
                transition-duration: 100ms;
            `,
        });

        const backBtnLayout = new St.BoxLayout({ style: 'spacing: 6px;' });
        backBtnLayout.add_child(new St.Icon({
            icon_name: 'go-previous-symbolic',
            icon_size: 12,
            style: `color: ${LIGHT_TEXT};`,
            y_align: Clutter.ActorAlign.CENTER,
        }));
        backBtnLayout.add_child(new St.Label({
            text: 'Back',
            style: `color: ${LIGHT_TEXT}; font-size: 12px;`,
            y_align: Clutter.ActorAlign.CENTER,
        }));
        backBtn.set_child(backBtnLayout);

        backBtn.connect('notify::hover', () => {
            backBtn.style = `
                background-color: ${backBtn.hover ? BRAND_HOVER : DARK_SURFACE};
                border-radius: 16px;
                padding: 6px 14px;
                transition-duration: 100ms;
            `;
        });
        backBtn.connect('clicked', () => {
            this._showPinnedView();
        });

        allAppsHeader.add_child(backBtn);

        const allAppsTitle = new St.Label({
            text: 'All apps',
            style: `
                color: ${LIGHT_TEXT};
                font-size: 14px;
                font-weight: 600;
                margin-left: 12px;
            `,
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
        });
        allAppsHeader.add_child(allAppsTitle);

        this._allAppsView.add_child(allAppsHeader);

        this._allAppsList = new St.BoxLayout({
            vertical: true,
            x_expand: true,
            style: 'spacing: 1px;',
        });

        this._allAppsScroll = new St.ScrollView({
            x_expand: true,
            y_expand: true,
            overlay_scrollbars: true,
        });
        this._allAppsScroll.set_child(this._allAppsList);

        this._allAppsView.add_child(this._allAppsScroll);
        this._contentStack.add_child(this._allAppsView);

        this._populateAllApps();
    }

    _populateAllApps() {
        const appSystem = Shell.AppSystem.get_default();
        const allApps = appSystem.get_installed()
            .filter(info => info.should_show())
            .sort((a, b) => a.get_name().localeCompare(b.get_name()));

        let currentLetter = '';

        for (const appInfo of allApps) {
            const app = appSystem.lookup_app(appInfo.get_id());
            if (!app) continue;

            const firstLetter = app.get_name().charAt(0).toUpperCase();
            if (firstLetter !== currentLetter) {
                currentLetter = firstLetter;
                const letterLabel = new St.Label({
                    text: currentLetter,
                    style: `
                        color: ${BRAND_PRIMARY};
                        font-size: 13px;
                        font-weight: 700;
                        padding: 8px 16px 4px 16px;
                    `,
                });
                this._allAppsList.add_child(letterLabel);
            }

            const item = new AllAppsListItem(app);
            item.connect('clicked', () => {
                this.close();
            });
            this._allAppsList.add_child(item);
        }
    }

    _buildSearchResultsView() {
        this._searchResultsView = new St.BoxLayout({
            vertical: true,
            x_expand: true,
            y_expand: true,
            visible: false,
        });

        const searchHeader = new St.Label({
            text: 'Search Results',
            style: `
                color: ${LIGHT_TEXT};
                font-size: 14px;
                font-weight: 600;
                margin-bottom: 12px;
            `,
        });
        this._searchResultsView.add_child(searchHeader);

        this._searchResultsList = new St.BoxLayout({
            vertical: true,
            x_expand: true,
            style: 'spacing: 1px;',
        });

        const searchScroll = new St.ScrollView({
            x_expand: true,
            y_expand: true,
            overlay_scrollbars: true,
        });
        searchScroll.set_child(this._searchResultsList);
        this._searchResultsView.add_child(searchScroll);

        this._noResultsLabel = new St.Label({
            text: 'No results found',
            style: `
                color: rgba(232, 224, 240, 0.4);
                font-size: 14px;
                text-align: center;
                margin-top: 40px;
            `,
            x_align: Clutter.ActorAlign.CENTER,
            visible: false,
        });
        this._searchResultsView.add_child(this._noResultsLabel);

        this._contentStack.add_child(this._searchResultsView);
    }

    // ── Bottom Bar ───────────────────────────────────────────────────────

    _buildBottomBar() {
        this._bottomBar = new St.BoxLayout({
            style: `
                padding: 12px 16px;
                border-top: 1px solid rgba(232, 224, 240, 0.08);
                margin-top: 8px;
            `,
            x_expand: true,
        });

        // User profile button
        const userBtn = new St.Button({
            reactive: true,
            can_focus: true,
            track_hover: true,
            style: `
                border-radius: 20px;
                padding: 6px 14px;
                background-color: transparent;
                transition-duration: 100ms;
            `,
        });

        const userLayout = new St.BoxLayout({ style: 'spacing: 10px;' });

        const userAvatar = new St.Icon({
            icon_name: 'avatar-default-symbolic',
            icon_size: 24,
            style: `
                color: ${BRAND_PRIMARY};
                background-color: ${DARK_SURFACE};
                border-radius: 12px;
                padding: 4px;
            `,
        });
        userLayout.add_child(userAvatar);

        const userName = new St.Label({
            text: GLib.get_user_name(),
            style: `
                color: ${LIGHT_TEXT};
                font-size: 13px;
                font-weight: 500;
            `,
            y_align: Clutter.ActorAlign.CENTER,
        });
        userLayout.add_child(userName);

        userBtn.set_child(userLayout);
        userBtn.connect('notify::hover', () => {
            userBtn.style = `
                border-radius: 20px;
                padding: 6px 14px;
                background-color: ${userBtn.hover ? 'rgba(124, 58, 237, 0.1)' : 'transparent'};
                transition-duration: 100ms;
            `;
        });

        this._bottomBar.add_child(userBtn);

        // Spacer
        const spacer = new St.Widget({ x_expand: true });
        this._bottomBar.add_child(spacer);

        // Settings button
        const settingsBtn = this._createBottomButton('preferences-system-symbolic', 'Settings');
        settingsBtn.connect('clicked', () => {
            const appSystem = Shell.AppSystem.get_default();
            const settingsApp = appSystem.lookup_app('org.gnome.Settings.desktop')
                || appSystem.lookup_app('gnome-control-center.desktop');
            if (settingsApp) {
                settingsApp.open_new_window(-1);
            }
            this.close();
        });
        this._bottomBar.add_child(settingsBtn);

        // Power button
        const powerBtn = this._createBottomButton('system-shutdown-symbolic', 'Power');
        this._powerMenu = new PowerMenu();

        powerBtn.connect('clicked', () => {
            this._powerMenu.toggle();
        });

        this._bottomBar.add_child(powerBtn);

        // Add power menu as overlay
        this._powerMenu.set({
            x_align: Clutter.ActorAlign.END,
            y_align: Clutter.ActorAlign.END,
        });

        this._mainLayout.add_child(this._bottomBar);
        this.add_child(this._powerMenu);

        // Position power menu
        this.connect('allocation-changed', () => {
            if (this._powerMenu) {
                this._powerMenu.set_position(
                    MENU_WIDTH - 200 - 20,
                    MENU_HEIGHT - 220
                );
            }
        });
    }

    _createBottomButton(iconName, tooltip) {
        const btn = new St.Button({
            reactive: true,
            can_focus: true,
            track_hover: true,
            style: `
                width: 36px;
                height: 36px;
                border-radius: 18px;
                padding: 0;
                margin: 0 4px;
                background-color: transparent;
                transition-duration: 100ms;
            `,
        });

        const icon = new St.Icon({
            icon_name: iconName,
            icon_size: 18,
            style: `color: ${LIGHT_TEXT};`,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
        });
        btn.set_child(icon);

        btn.connect('notify::hover', () => {
            btn.style = `
                width: 36px;
                height: 36px;
                border-radius: 18px;
                padding: 0;
                margin: 0 4px;
                background-color: ${btn.hover ? 'rgba(124, 58, 237, 0.15)' : 'transparent'};
                transition-duration: 100ms;
            `;
        });

        return btn;
    }

    // ── Search ───────────────────────────────────────────────────────────

    _onSearchChanged() {
        const query = this._searchEntry.get_text().trim().toLowerCase();

        if (query.length === 0) {
            this._searchResultsView.visible = false;
            if (this._showingAllApps) {
                this._allAppsView.visible = true;
                this._pinnedView.visible = false;
            } else {
                this._pinnedView.visible = true;
                this._allAppsView.visible = false;
            }
            return;
        }

        this._pinnedView.visible = false;
        this._allAppsView.visible = false;
        this._searchResultsView.visible = true;

        // Clear old results
        this._searchResultsList.destroy_all_children();

        const appSystem = Shell.AppSystem.get_default();
        const allApps = appSystem.get_installed()
            .filter(info => info.should_show())
            .filter(info => {
                const name = info.get_name().toLowerCase();
                const desc = (info.get_description() || '').toLowerCase();
                const keywords = (info.get_keywords?.() || []).join(' ').toLowerCase();
                return name.includes(query) || desc.includes(query) || keywords.includes(query);
            })
            .sort((a, b) => {
                const aName = a.get_name().toLowerCase();
                const bName = b.get_name().toLowerCase();
                const aStartsWith = aName.startsWith(query);
                const bStartsWith = bName.startsWith(query);
                if (aStartsWith && !bStartsWith) return -1;
                if (!aStartsWith && bStartsWith) return 1;
                return aName.localeCompare(bName);
            });

        const maxResults = 20;
        const results = allApps.slice(0, maxResults);

        if (results.length === 0) {
            this._noResultsLabel.visible = true;
        } else {
            this._noResultsLabel.visible = false;
            for (const appInfo of results) {
                const app = appSystem.lookup_app(appInfo.get_id());
                if (!app) continue;

                const item = new AllAppsListItem(app);
                item.connect('clicked', () => {
                    this.close();
                });
                this._searchResultsList.add_child(item);
            }
        }
    }

    // ── View Switching ───────────────────────────────────────────────────

    _showAllApps() {
        this._showingAllApps = true;
        this._pinnedView.visible = false;
        this._searchResultsView.visible = false;
        this._allAppsView.visible = true;

        this._allAppsView.opacity = 0;
        this._allAppsView.ease({
            opacity: 255,
            duration: 200,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
        });
    }

    _showPinnedView() {
        this._showingAllApps = false;
        this._allAppsView.visible = false;
        this._searchResultsView.visible = false;
        this._pinnedView.visible = true;

        this._pinnedView.opacity = 0;
        this._pinnedView.ease({
            opacity: 255,
            duration: 200,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
        });
    }

    // ── Super Key Binding ────────────────────────────────────────────────

    _bindSuperKey() {
        this._superKeyId = global.display.connect('overlay-key', () => {
            this.toggle();
        });
    }

    // ── Open / Close / Toggle ────────────────────────────────────────────

    toggle() {
        if (this._isOpen) {
            this.close();
        } else {
            this.open();
        }
    }

    open() {
        if (this._isOpen) return;
        this._isOpen = true;

        // Create backdrop for click-outside-to-close
        if (!this._backdrop) {
            const monitor = Main.layoutManager.primaryMonitor;
            this._backdrop = new St.Widget({
                reactive: true,
                width: monitor.width,
                height: monitor.height,
                x: monitor.x,
                y: monitor.y,
                style: 'background-color: transparent;',
            });
            this._backdrop.connect('button-press-event', () => {
                this.close();
                return Clutter.EVENT_STOP;
            });
            Main.layoutManager.addTopChrome(this._backdrop);
        }
        this._backdrop.visible = true;

        // Ensure menu is above backdrop
        const parent = this.get_parent();
        if (parent) {
            parent.set_child_above_sibling(this, this._backdrop);
        }

        // Reset state
        this._searchEntry.set_text('');
        this._showPinnedView();
        this._powerMenu.visible = false;

        // Animate open
        this.visible = true;
        this.opacity = 0;
        this.scale_y = 0.95;
        this.pivot_point = new Clutter.Point({ x: 0.5, y: 1.0 });

        this.ease({
            opacity: 255,
            scale_y: 1.0,
            duration: ANIM_DURATION,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
        });

        // Focus search entry
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
            global.stage.set_key_focus(this._searchEntry.clutter_text);
            return GLib.SOURCE_REMOVE;
        });

        this.emit('menu-toggled', true);
    }

    close() {
        if (!this._isOpen) return;
        this._isOpen = false;

        if (this._backdrop) {
            this._backdrop.visible = false;
        }

        this._powerMenu.visible = false;

        this.ease({
            opacity: 0,
            scale_y: 0.95,
            duration: ANIM_DURATION,
            mode: Clutter.AnimationMode.EASE_IN_QUAD,
            onComplete: () => {
                this.visible = false;
            },
        });

        this.emit('menu-toggled', false);
    }

    get isOpen() {
        return this._isOpen;
    }

    // ── Cleanup ──────────────────────────────────────────────────────────

    _onDestroy() {
        if (this._superKeyId) {
            global.display.disconnect(this._superKeyId);
            this._superKeyId = null;
        }

        if (this._backdrop) {
            Main.layoutManager.removeChrome(this._backdrop);
            this._backdrop.destroy();
            this._backdrop = null;
        }
    }
});

// ─── Extension Entry Points ──────────────────────────────────────────────────

let _startMenu = null;

export function enable() {
    _startMenu = new StartMenu();
}

export function disable() {
    if (_startMenu) {
        Main.layoutManager.removeChrome(_startMenu);
        _startMenu.destroy();
        _startMenu = null;
    }
}

export function getStartMenu() {
    return _startMenu;
}
