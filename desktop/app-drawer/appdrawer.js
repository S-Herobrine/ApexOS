// SatasOS App Drawer - Android-style full-screen app launcher
// GNOME 45+ ESM import style

import St from 'gi://St';
import Clutter from 'gi://Clutter';
import Shell from 'gi://Shell';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Gio from 'gi://Gio';
import Meta from 'gi://Meta';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const BRAND_PRIMARY = '#7C3AED';
const BRAND_HOVER = '#6D28D9';
const BRAND_ACTIVE = '#5B21B6';
const BRAND_DARK_BG = '#1E1B2E';
const BRAND_DARK_SURFACE = '#2D2640';
const BRAND_LIGHT_TEXT = '#E8E0F0';

const ICON_SIZE = 64;
const GRID_COLUMN_COUNT = 6;
const GRID_SPACING = 24;
const APP_BUTTON_WIDTH = 110;
const APP_BUTTON_HEIGHT = 120;
const ANIMATION_DURATION = 350;
const CATEGORY_LIST = ['All', 'System', 'Internet', 'Media', 'Games', 'Android'];
const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#'.split('');

const CATEGORY_MAP = {
    'System':   ['System', 'Settings', 'Utility', 'Development', 'PackageManager'],
    'Internet': ['Network', 'WebBrowser', 'Email', 'Chat', 'InstantMessaging', 'IRCClient', 'P2P'],
    'Media':    ['AudioVideo', 'Audio', 'Video', 'Graphics', 'Photography', 'Music', 'Player'],
    'Games':    ['Game', 'ActionGame', 'AdventureGame', 'ArcadeGame', 'BoardGame',
                 'BlocksGame', 'CardGame', 'Emulator', 'LogicGame', 'RolePlaying',
                 'Simulation', 'SportsGame', 'StrategyGame'],
    'Android':  ['Android', 'Anbox', 'Waydroid'],
};

export const AppDrawer = GObject.registerClass(
class AppDrawer extends St.Widget {
    _init() {
        const monitor = Main.layoutManager.primaryMonitor;
        super._init({
            name: 'satas-app-drawer',
            reactive: true,
            visible: false,
            x: monitor.x,
            y: monitor.y,
            width: monitor.width,
            height: monitor.height,
            style: `background-color: rgba(14, 12, 22, 0.92);`,
        });

        this._isOpen = false;
        this._allApps = [];
        this._filteredApps = [];
        this._activeCategory = 'All';
        this._appSystem = Shell.AppSystem.get_default();
        this._longPressTimeoutId = 0;

        this._buildLayout();
        this._loadApps();
        this._connectSignals();

        Main.layoutManager.addTopChrome(this);
    }

    _buildLayout() {
        const monitor = Main.layoutManager.primaryMonitor;

        // Main container that slides up
        this._container = new St.BoxLayout({
            vertical: true,
            x: 0,
            y: 0,
            width: monitor.width,
            height: monitor.height,
            style: `padding: 32px 48px 24px 48px;`,
        });
        this.add_child(this._container);

        // Header area with handle bar
        this._handleBar = new St.Widget({
            width: 48,
            height: 5,
            style: `background-color: ${BRAND_LIGHT_TEXT}; border-radius: 3px;`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        const handleWrap = new St.Bin({
            x_align: Clutter.ActorAlign.CENTER,
            style: 'padding-bottom: 18px;',
            child: this._handleBar,
        });
        this._container.add_child(handleWrap);

        // Search bar
        this._searchEntry = new St.Entry({
            hint_text: 'Search apps…',
            can_focus: true,
            track_hover: true,
            style_class: 'satas-search-entry',
            style: `background-color: ${BRAND_DARK_SURFACE};
                    color: ${BRAND_LIGHT_TEXT};
                    border: 1px solid ${BRAND_PRIMARY};
                    border-radius: 24px;
                    padding: 10px 22px;
                    font-size: 16px;
                    caret-color: ${BRAND_PRIMARY};
                    selection-background-color: ${BRAND_PRIMARY};
                    min-height: 20px;`,
        });
        this._searchEntry.clutter_text.connect('text-changed', () => this._onSearchChanged());
        this._container.add_child(this._searchEntry);

        // Category tabs row
        this._categoryRow = new St.BoxLayout({
            style: 'padding: 16px 0 12px 0; spacing: 10px;',
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._categoryButtons = {};
        for (const cat of CATEGORY_LIST) {
            const btn = new St.Button({
                label: cat,
                toggle_mode: true,
                style: this._categoryButtonStyle(cat === 'All'),
            });
            btn._categoryName = cat;
            btn.connect('clicked', () => this._onCategoryClicked(cat));
            this._categoryRow.add_child(btn);
            this._categoryButtons[cat] = btn;
        }
        this._categoryButtons['All'].checked = true;
        this._container.add_child(this._categoryRow);

        // Middle area: scrollable grid + alphabet sidebar
        const middleBox = new St.BoxLayout({
            vertical: false,
            x_expand: true,
            y_expand: true,
        });
        this._container.add_child(middleBox);

        // Scroll view for the app grid
        this._scrollView = new St.ScrollView({
            x_expand: true,
            y_expand: true,
            style: 'padding-right: 8px;',
            overlay_scrollbars: true,
        });
        this._scrollView.set_policy(St.PolicyType.NEVER, St.PolicyType.AUTOMATIC);
        middleBox.add_child(this._scrollView);

        this._gridContainer = new St.BoxLayout({
            vertical: true,
            x_expand: true,
            style: `spacing: 8px;`,
        });
        this._scrollView.add_child(this._gridContainer);

        // Alphabet sidebar
        this._alphabetSidebar = new St.BoxLayout({
            vertical: true,
            style: `padding: 4px 6px; spacing: 1px;`,
            y_align: Clutter.ActorAlign.CENTER,
        });
        for (const letter of ALPHABET) {
            const letterBtn = new St.Button({
                label: letter,
                style: `color: ${BRAND_LIGHT_TEXT};
                        font-size: 11px;
                        font-weight: bold;
                        padding: 1px 6px;
                        min-width: 20px;
                        text-align: center;
                        border-radius: 4px;`,
            });
            letterBtn.connect('clicked', () => this._scrollToLetter(letter));
            letterBtn.connect('enter-event', () => {
                letterBtn.style = letterBtn.style + `background-color: ${BRAND_PRIMARY};`;
                return Clutter.EVENT_PROPAGATE;
            });
            letterBtn.connect('leave-event', () => {
                letterBtn.style = `color: ${BRAND_LIGHT_TEXT};
                        font-size: 11px;
                        font-weight: bold;
                        padding: 1px 6px;
                        min-width: 20px;
                        text-align: center;
                        border-radius: 4px;`;
                return Clutter.EVENT_PROPAGATE;
            });
            this._alphabetSidebar.add_child(letterBtn);
        }
        middleBox.add_child(this._alphabetSidebar);

        // Pagination info / app count label at the bottom
        this._statusLabel = new St.Label({
            text: '',
            style: `color: rgba(232,224,240,0.5);
                    font-size: 12px;
                    padding-top: 12px;`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._container.add_child(this._statusLabel);
    }

    _categoryButtonStyle(active) {
        if (active) {
            return `background-color: ${BRAND_PRIMARY};
                    color: white;
                    border-radius: 20px;
                    padding: 8px 20px;
                    font-size: 14px;
                    font-weight: bold;`;
        }
        return `background-color: ${BRAND_DARK_SURFACE};
                color: ${BRAND_LIGHT_TEXT};
                border-radius: 20px;
                padding: 8px 20px;
                font-size: 14px;`;
    }

    _loadApps() {
        const apps = this._appSystem.get_installed().filter(app => {
            return app.get_app_info() &&
                   !app.get_app_info().get_nodisplay() &&
                   app.get_app_info().should_show();
        });

        this._allApps = apps.map(app => {
            const info = app.get_app_info();
            const cats = info.get_categories() || '';
            const catList = cats.split(';').filter(c => c.length > 0);
            const name = app.get_name() || '';
            const firstChar = name.charAt(0).toUpperCase();
            const letter = /[A-Z]/.test(firstChar) ? firstChar : '#';
            return {
                app: app,
                name: name,
                id: app.get_id(),
                icon: info.get_icon(),
                categories: catList,
                letter: letter,
            };
        });

        this._allApps.sort((a, b) => a.name.localeCompare(b.name));
        this._applyFilter();
    }

    _getAppCategory(appEntry) {
        for (const [catName, catKeys] of Object.entries(CATEGORY_MAP)) {
            for (const key of catKeys) {
                if (appEntry.categories.includes(key)) {
                    return catName;
                }
            }
        }
        return 'System';
    }

    _applyFilter() {
        const query = this._searchEntry.get_text().toLowerCase().trim();
        let apps = this._allApps;

        if (this._activeCategory !== 'All') {
            apps = apps.filter(a => this._getAppCategory(a) === this._activeCategory);
        }

        if (query.length > 0) {
            apps = apps.filter(a => a.name.toLowerCase().includes(query));
        }

        this._filteredApps = apps;
        this._rebuildGrid();
    }

    _rebuildGrid() {
        this._gridContainer.destroy_all_children();
        this._sectionActors = {};

        if (this._filteredApps.length === 0) {
            const emptyLabel = new St.Label({
                text: 'No apps found',
                style: `color: ${BRAND_LIGHT_TEXT};
                        font-size: 18px;
                        padding: 60px 0;`,
                x_align: Clutter.ActorAlign.CENTER,
            });
            this._gridContainer.add_child(emptyLabel);
            this._statusLabel.set_text('0 apps');
            return;
        }

        let currentLetter = '';
        let currentRow = null;
        let colIndex = 0;

        for (const appEntry of this._filteredApps) {
            // Section header for new letter
            if (appEntry.letter !== currentLetter) {
                currentLetter = appEntry.letter;
                const header = new St.Label({
                    text: currentLetter,
                    style: `color: ${BRAND_PRIMARY};
                            font-size: 18px;
                            font-weight: bold;
                            padding: 14px 8px 6px 8px;`,
                });
                this._gridContainer.add_child(header);
                this._sectionActors[currentLetter] = header;
                currentRow = null;
                colIndex = 0;
            }

            // Start a new row if needed
            if (!currentRow || colIndex >= GRID_COLUMN_COUNT) {
                currentRow = new St.BoxLayout({
                    style: `spacing: ${GRID_SPACING}px; padding: 4px 0;`,
                    x_align: Clutter.ActorAlign.START,
                });
                this._gridContainer.add_child(currentRow);
                colIndex = 0;
            }

            const appButton = this._createAppButton(appEntry);
            currentRow.add_child(appButton);
            colIndex++;
        }

        this._statusLabel.set_text(`${this._filteredApps.length} apps`);
    }

    _createAppButton(appEntry) {
        const btn = new St.Button({
            style: `width: ${APP_BUTTON_WIDTH}px;
                    height: ${APP_BUTTON_HEIGHT}px;
                    border-radius: 16px;
                    padding: 8px 4px;
                    text-align: center;`,
            x_align: Clutter.ActorAlign.CENTER,
        });

        const box = new St.BoxLayout({
            vertical: true,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            style: 'spacing: 6px;',
        });

        const iconWidget = new St.Icon({
            gicon: appEntry.icon || null,
            icon_name: appEntry.icon ? null : 'application-x-executable',
            icon_size: ICON_SIZE,
            style: 'margin: 0 auto;',
            x_align: Clutter.ActorAlign.CENTER,
        });
        box.add_child(iconWidget);

        const nameLabel = new St.Label({
            text: appEntry.name,
            style: `color: ${BRAND_LIGHT_TEXT};
                    font-size: 12px;
                    text-align: center;`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        nameLabel.clutter_text.set_ellipsize(3); // PANGO_ELLIPSIZE_END
        nameLabel.clutter_text.set_max_length(18);
        box.add_child(nameLabel);

        btn.set_child(box);

        // Hover styling
        btn.connect('enter-event', () => {
            btn.style = btn.style + `background-color: ${BRAND_DARK_SURFACE};`;
            return Clutter.EVENT_PROPAGATE;
        });
        btn.connect('leave-event', () => {
            btn.style = `width: ${APP_BUTTON_WIDTH}px;
                    height: ${APP_BUTTON_HEIGHT}px;
                    border-radius: 16px;
                    padding: 8px 4px;
                    text-align: center;`;
            return Clutter.EVENT_PROPAGATE;
        });

        // Click to launch
        btn.connect('clicked', () => {
            appEntry.app.activate();
            this.close();
        });

        // Long press: show app info popup
        let pressTimeoutId = 0;
        btn.connect('button-press-event', () => {
            pressTimeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 800, () => {
                pressTimeoutId = 0;
                this._showAppInfo(appEntry, btn);
                return GLib.SOURCE_REMOVE;
            });
            return Clutter.EVENT_PROPAGATE;
        });
        btn.connect('button-release-event', () => {
            if (pressTimeoutId) {
                GLib.source_remove(pressTimeoutId);
                pressTimeoutId = 0;
            }
            return Clutter.EVENT_PROPAGATE;
        });

        return btn;
    }

    _showAppInfo(appEntry, sourceActor) {
        // Remove any existing info popup
        if (this._infoPopup) {
            this._infoPopup.destroy();
            this._infoPopup = null;
        }

        const info = appEntry.app.get_app_info();
        const description = info.get_description() || 'No description available.';
        const desktopFile = info.get_filename() || 'Unknown';

        this._infoPopup = new St.BoxLayout({
            vertical: true,
            style: `background-color: ${BRAND_DARK_SURFACE};
                    border: 1px solid ${BRAND_PRIMARY};
                    border-radius: 16px;
                    padding: 20px;
                    spacing: 8px;
                    min-width: 300px;
                    max-width: 400px;`,
        });

        // App info header with icon
        const headerRow = new St.BoxLayout({ style: 'spacing: 12px;' });
        headerRow.add_child(new St.Icon({
            gicon: appEntry.icon || null,
            icon_name: appEntry.icon ? null : 'application-x-executable',
            icon_size: 48,
        }));
        const headerText = new St.BoxLayout({ vertical: true, style: 'spacing: 2px;' });
        headerText.add_child(new St.Label({
            text: appEntry.name,
            style: `color: white; font-size: 18px; font-weight: bold;`,
        }));
        headerText.add_child(new St.Label({
            text: appEntry.id,
            style: `color: rgba(232,224,240,0.5); font-size: 11px;`,
        }));
        headerRow.add_child(headerText);
        this._infoPopup.add_child(headerRow);

        // Description
        const descLabel = new St.Label({
            text: description,
            style: `color: ${BRAND_LIGHT_TEXT}; font-size: 13px; padding-top: 4px;`,
        });
        descLabel.clutter_text.set_line_wrap(true);
        descLabel.clutter_text.set_max_length(200);
        this._infoPopup.add_child(descLabel);

        // Categories
        if (appEntry.categories.length > 0) {
            this._infoPopup.add_child(new St.Label({
                text: `Categories: ${appEntry.categories.join(', ')}`,
                style: `color: rgba(232,224,240,0.5); font-size: 11px; padding-top: 4px;`,
            }));
        }

        // Desktop file path
        this._infoPopup.add_child(new St.Label({
            text: desktopFile,
            style: `color: rgba(232,224,240,0.35); font-size: 10px;`,
        }));

        // Close button
        const closeBtn = new St.Button({
            label: 'Close',
            style: `background-color: ${BRAND_PRIMARY};
                    color: white;
                    border-radius: 12px;
                    padding: 6px 20px;
                    font-size: 13px;
                    margin-top: 8px;`,
            x_align: Clutter.ActorAlign.END,
        });
        closeBtn.connect('clicked', () => {
            this._infoPopup.destroy();
            this._infoPopup = null;
        });
        this._infoPopup.add_child(closeBtn);

        // Position popup near the source actor
        const [sx, sy] = sourceActor.get_transformed_position();
        const monitor = Main.layoutManager.primaryMonitor;
        let px = Math.min(sx, monitor.width - 420);
        let py = Math.min(sy - 180, monitor.height - 300);
        px = Math.max(px, 20);
        py = Math.max(py, 20);
        this._infoPopup.set_position(px, py);

        this.add_child(this._infoPopup);
    }

    _scrollToLetter(letter) {
        if (!this._sectionActors || !this._sectionActors[letter])
            return;

        const target = this._sectionActors[letter];
        const vscroll = this._scrollView.get_vscroll_bar();
        const adjustment = vscroll.get_adjustment();
        const [, targetY] = target.get_transformed_position();
        const [, containerY] = this._gridContainer.get_transformed_position();
        const scrollTo = targetY - containerY;
        adjustment.ease(scrollTo, {
            duration: 200,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
        });
    }

    _onSearchChanged() {
        // Debounce search filter
        if (this._searchTimeout) {
            GLib.source_remove(this._searchTimeout);
            this._searchTimeout = 0;
        }
        this._searchTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 150, () => {
            this._searchTimeout = 0;
            this._applyFilter();
            return GLib.SOURCE_REMOVE;
        });
    }

    _onCategoryClicked(category) {
        this._activeCategory = category;
        for (const [name, btn] of Object.entries(this._categoryButtons)) {
            const isActive = name === category;
            btn.checked = isActive;
            btn.style = this._categoryButtonStyle(isActive);
        }
        this._applyFilter();
    }

    _connectSignals() {
        // Watch for app installs/uninstalls
        this._installedChangedId = this._appSystem.connect('installed-changed', () => {
            this._loadApps();
        });

        // Swipe-up gesture zone at bottom of screen
        this._gestureDetector = new St.Widget({
            name: 'satas-drawer-gesture-zone',
            reactive: true,
            x: 0,
            y: Main.layoutManager.primaryMonitor.height - 32,
            width: Main.layoutManager.primaryMonitor.width,
            height: 32,
            style: 'background-color: transparent;',
        });
        let gestureStartY = 0;
        this._gestureDetector.connect('touch-event', (_actor, event) => {
            const type = event.type();
            if (type === Clutter.EventType.TOUCH_BEGIN) {
                gestureStartY = event.get_coords()[1];
            } else if (type === Clutter.EventType.TOUCH_END) {
                const endY = event.get_coords()[1];
                if (gestureStartY - endY > 80) {
                    this.open();
                }
            }
            return Clutter.EVENT_PROPAGATE;
        });
        this._gestureDetector.connect('button-press-event', (_actor, event) => {
            gestureStartY = event.get_coords()[1];
            return Clutter.EVENT_PROPAGATE;
        });
        this._gestureDetector.connect('button-release-event', (_actor, event) => {
            const endY = event.get_coords()[1];
            if (gestureStartY - endY > 80) {
                this.open();
            }
            return Clutter.EVENT_PROPAGATE;
        });
        Main.layoutManager.addTopChrome(this._gestureDetector);
    }

    // Click on background to close
    vfunc_button_press_event(event) {
        const [x, y] = event.get_coords();
        const target = this.get_stage().get_actor_at_pos(Clutter.PickMode.ALL, x, y);
        if (target === this) {
            this.close();
            return Clutter.EVENT_STOP;
        }
        return Clutter.EVENT_PROPAGATE;
    }

    vfunc_key_press_event(event) {
        const sym = event.get_key_symbol();
        if (sym === Clutter.KEY_Escape) {
            this.close();
            return Clutter.EVENT_STOP;
        }
        return Clutter.EVENT_PROPAGATE;
    }

    open() {
        if (this._isOpen)
            return;
        this._isOpen = true;

        const monitor = Main.layoutManager.primaryMonitor;
        this.set_position(monitor.x, monitor.y);
        this.set_size(monitor.width, monitor.height);
        this._container.set_size(monitor.width, monitor.height);

        // Start from below screen
        this._container.set_position(0, monitor.height);
        this.visible = true;
        this.opacity = 255;

        this._container.ease({
            y: 0,
            duration: ANIMATION_DURATION,
            mode: Clutter.AnimationMode.EASE_OUT_CUBIC,
            onComplete: () => {
                this._searchEntry.grab_key_focus();
            },
        });

        // Refresh apps list when opening
        this._loadApps();
    }

    close() {
        if (!this._isOpen)
            return;
        this._isOpen = false;

        const monitor = Main.layoutManager.primaryMonitor;
        this._container.ease({
            y: monitor.height,
            duration: ANIMATION_DURATION,
            mode: Clutter.AnimationMode.EASE_IN_CUBIC,
            onComplete: () => {
                this.visible = false;
                this._searchEntry.set_text('');
                if (this._infoPopup) {
                    this._infoPopup.destroy();
                    this._infoPopup = null;
                }
            },
        });
    }

    toggle() {
        if (this._isOpen)
            this.close();
        else
            this.open();
    }

    destroy() {
        if (this._searchTimeout) {
            GLib.source_remove(this._searchTimeout);
            this._searchTimeout = 0;
        }
        if (this._installedChangedId) {
            this._appSystem.disconnect(this._installedChangedId);
            this._installedChangedId = 0;
        }
        if (this._gestureDetector) {
            this._gestureDetector.destroy();
            this._gestureDetector = null;
        }
        if (this._infoPopup) {
            this._infoPopup.destroy();
            this._infoPopup = null;
        }
        super.destroy();
    }
});

// Singleton management
let _drawerInstance = null;

export function getAppDrawer() {
    if (!_drawerInstance)
        _drawerInstance = new AppDrawer();
    return _drawerInstance;
}

export function toggleAppDrawer() {
    getAppDrawer().toggle();
}

export function openAppDrawer() {
    getAppDrawer().open();
}

export function closeAppDrawer() {
    getAppDrawer().close();
}

export function destroyAppDrawer() {
    if (_drawerInstance) {
        _drawerInstance.destroy();
        _drawerInstance = null;
    }
}
