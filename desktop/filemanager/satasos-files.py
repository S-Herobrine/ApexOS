#!/usr/bin/env python3
"""
SatasOS Files - Custom File Manager
A modern file manager built with GTK4 for SatasOS.
Features tabbed browsing, multiple view modes, and full file operations.
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
gi.require_version('GdkPixbuf', '2.0')
gi.require_version('Pango', '1.0')

from gi.repository import Gtk, Gdk, Gio, GLib, GdkPixbuf, Pango
import os
import sys
import time
import shutil
import subprocess
import stat
import mimetypes
import threading
from pathlib import Path
from datetime import datetime

# ---------------------------------------------------------------------------
# SatasOS Brand Colours
# ---------------------------------------------------------------------------
SATASOS_CSS = b"""
/* SatasOS Files - Dark Purple Theme */
window, .background {
    background-color: #1E1B2E;
    color: #E8E0F0;
}
headerbar {
    background-color: #2D2640;
    border-bottom: 1px solid #3D3456;
    color: #E8E0F0;
}
headerbar entry {
    background-color: #1E1B2E;
    color: #E8E0F0;
    border: 1px solid #3D3456;
    border-radius: 6px;
    padding: 4px 8px;
    min-width: 350px;
}
headerbar entry:focus {
    border-color: #7C3AED;
    box-shadow: 0 0 0 1px #7C3AED;
}
headerbar button {
    background-color: transparent;
    color: #E8E0F0;
    border: none;
    border-radius: 6px;
    padding: 4px 8px;
}
headerbar button:hover {
    background-color: #6D28D9;
}
headerbar button:active, headerbar button:checked {
    background-color: #5B21B6;
}
.sidebar {
    background-color: #2D2640;
    border-right: 1px solid #3D3456;
    padding: 4px;
}
.sidebar row {
    color: #E8E0F0;
    border-radius: 6px;
    padding: 6px 10px;
    margin: 1px 4px;
}
.sidebar row:hover {
    background-color: rgba(124, 58, 237, 0.2);
}
.sidebar row:selected {
    background-color: #7C3AED;
    color: #FFFFFF;
}
.sidebar-header {
    color: #9B8AB8;
    font-size: 0.8em;
    font-weight: bold;
    padding: 10px 14px 4px 14px;
    letter-spacing: 1px;
}
.content-view {
    background-color: #1E1B2E;
    color: #E8E0F0;
}
.content-view:selected, gridview > child:selected, columnview > row:selected {
    background-color: rgba(124, 58, 237, 0.35);
}
.statusbar {
    background-color: #2D2640;
    border-top: 1px solid #3D3456;
    color: #9B8AB8;
    padding: 4px 12px;
    font-size: 0.85em;
}
notebook > header {
    background-color: #2D2640;
    border-bottom: 1px solid #3D3456;
}
notebook > header tab {
    background-color: transparent;
    color: #9B8AB8;
    border-radius: 6px 6px 0 0;
    padding: 4px 12px;
    margin: 0 1px;
}
notebook > header tab:checked {
    background-color: #1E1B2E;
    color: #E8E0F0;
}
notebook > header tab:hover {
    color: #E8E0F0;
}
notebook > header tab button {
    min-width: 16px;
    min-height: 16px;
    padding: 0;
    margin: 0 0 0 4px;
    color: #9B8AB8;
    background: transparent;
    border: none;
}
notebook > header tab button:hover {
    color: #E8E0F0;
    background-color: rgba(124, 58, 237, 0.3);
    border-radius: 50%;
}
.search-bar {
    background-color: #2D2640;
    border-bottom: 1px solid #3D3456;
}
popover, popover.background {
    background-color: #2D2640;
    color: #E8E0F0;
    border: 1px solid #3D3456;
    border-radius: 8px;
}
popover modelbutton:hover, popover button:hover {
    background-color: rgba(124, 58, 237, 0.3);
}
.file-icon-item {
    padding: 8px;
    border-radius: 8px;
}
.file-icon-item:hover {
    background-color: rgba(124, 58, 237, 0.15);
}
.file-icon-item:selected {
    background-color: rgba(124, 58, 237, 0.35);
}
.file-name-label {
    color: #E8E0F0;
    font-size: 0.9em;
}
.file-detail-label {
    color: #9B8AB8;
    font-size: 0.8em;
}
.breadcrumb-btn {
    background: transparent;
    color: #9B8AB8;
    border: none;
    padding: 2px 4px;
    font-size: 0.9em;
}
.breadcrumb-btn:hover {
    color: #E8E0F0;
    background-color: rgba(124, 58, 237, 0.2);
    border-radius: 4px;
}
scrollbar slider {
    background-color: #5B21B6;
    border-radius: 10px;
    min-width: 8px;
    min-height: 8px;
}
scrollbar slider:hover {
    background-color: #7C3AED;
}
.dim-label { color: #9B8AB8; }
"""

# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------

def format_size(size_bytes):
    """Format byte count to human readable string."""
    if size_bytes < 0:
        return "—"
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(size_bytes) < 1024.0:
            return f"{size_bytes:,.1f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:,.1f} PB"


def format_time(epoch):
    """Format epoch timestamp to readable string."""
    try:
        dt = datetime.fromtimestamp(epoch)
        return dt.strftime("%Y-%m-%d %H:%M")
    except (OSError, ValueError, OverflowError):
        return "—"


def get_mime_type(filepath):
    """Return MIME type string for a file path."""
    mime, _ = mimetypes.guess_type(filepath)
    if mime:
        return mime
    return "application/octet-stream"


def get_file_type_label(filepath, is_dir):
    """Return human-readable file type."""
    if is_dir:
        return "Folder"
    mime = get_mime_type(filepath)
    category = mime.split("/")[0].capitalize()
    ext = os.path.splitext(filepath)[1].upper()
    if ext:
        return f"{ext[1:]} {category}"
    return category


def is_image_file(filepath):
    """Check if file is an image suitable for thumbnailing."""
    mime = get_mime_type(filepath)
    return mime and mime.startswith("image/") and mime in (
        "image/png", "image/jpeg", "image/jpg", "image/gif",
        "image/bmp", "image/svg+xml", "image/webp", "image/tiff",
    )


def get_icon_name_for_file(filepath, is_dir):
    """Choose a themed icon name based on file type."""
    if is_dir:
        basename = os.path.basename(filepath).lower()
        special = {
            "desktop": "user-desktop",
            "documents": "folder-documents",
            "downloads": "folder-download",
            "music": "folder-music",
            "pictures": "folder-pictures",
            "videos": "folder-videos",
            "templates": "folder-templates",
            "public": "folder-publicshare",
        }
        return special.get(basename, "folder")
    mime = get_mime_type(filepath)
    if mime:
        cat = mime.split("/")[0]
        mapping = {
            "text": "text-x-generic",
            "image": "image-x-generic",
            "audio": "audio-x-generic",
            "video": "video-x-generic",
            "application": "application-x-executable",
        }
        ext = os.path.splitext(filepath)[1].lower()
        ext_map = {
            ".pdf": "application-pdf",
            ".zip": "package-x-generic",
            ".tar": "package-x-generic",
            ".gz": "package-x-generic",
            ".7z": "package-x-generic",
            ".rar": "package-x-generic",
            ".py": "text-x-python",
            ".js": "text-x-script",
            ".html": "text-html",
            ".css": "text-css",
            ".sh": "text-x-script",
            ".c": "text-x-csrc",
            ".cpp": "text-x-c++src",
            ".h": "text-x-chdr",
            ".java": "text-x-java",
            ".rs": "text-x-generic",
            ".go": "text-x-generic",
            ".md": "text-x-generic",
            ".json": "text-x-generic",
            ".xml": "text-x-generic",
            ".iso": "application-x-cd-image",
            ".deb": "application-x-deb",
            ".rpm": "application-x-rpm",
        }
        if ext in ext_map:
            return ext_map[ext]
        return mapping.get(cat, "text-x-generic")
    return "text-x-generic"


# ---------------------------------------------------------------------------
# FileItem GObject - model entry
# ---------------------------------------------------------------------------

class FileItem(GLib.Object):
    """Represents a single file system entry in the model."""

    def __init__(self, filepath, name=None):
        super().__init__()
        self.filepath = filepath
        self.name = name or os.path.basename(filepath) or filepath
        try:
            st = os.stat(filepath)
            self.is_dir = stat.S_ISDIR(st.st_mode)
            self.size = st.st_size if not self.is_dir else -1
            self.mtime = st.st_mtime
            self.permissions = stat.filemode(st.st_mode)
        except OSError:
            self.is_dir = False
            self.size = -1
            self.mtime = 0
            self.permissions = "----------"
        self.type_label = get_file_type_label(filepath, self.is_dir)
        self.icon_name = get_icon_name_for_file(filepath, self.is_dir)
        self.is_hidden = self.name.startswith(".")


# ---------------------------------------------------------------------------
# Tab State
# ---------------------------------------------------------------------------

class TabState:
    """Holds per-tab navigation state."""

    def __init__(self, path=None):
        self.current_path = path or GLib.get_home_dir()
        self.back_stack = []
        self.forward_stack = []
        self.sort_column = "name"
        self.sort_ascending = True
        self.selected_items = []


# ---------------------------------------------------------------------------
# FileManagerWindow
# ---------------------------------------------------------------------------

class FileManagerWindow(Gtk.ApplicationWindow):
    """Main window of the SatasOS file manager."""

    VIEW_ICON = 0
    VIEW_LIST = 1
    VIEW_DETAIL = 2

    def __init__(self, app):
        super().__init__(application=app, title="SatasOS Files",
                         default_width=1200, default_height=700)

        self.show_hidden = False
        self.view_mode = self.VIEW_ICON
        self.clipboard_files = []
        self.clipboard_cut = False
        self.tabs = []
        self.current_tab_index = -1
        self._thumbnail_cache = {}

        # -- CSS ---------------------------------------------------------------
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(SATASOS_CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        # -- Header bar --------------------------------------------------------
        self._build_headerbar()

        # -- Main layout -------------------------------------------------------
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_child(main_box)

        # Search bar
        self.search_bar = Gtk.SearchBar()
        self.search_entry = Gtk.SearchEntry()
        self.search_entry.set_hexpand(True)
        self.search_bar.set_child(self.search_entry)
        self.search_bar.connect_entry(self.search_entry)
        self.search_entry.connect("search-changed", self._on_search_changed)
        self.search_bar.add_css_class("search-bar")
        main_box.append(self.search_bar)

        # Notebook for tabs
        self.notebook = Gtk.Notebook()
        self.notebook.set_scrollable(True)
        self.notebook.set_vexpand(True)
        self.notebook.set_hexpand(True)
        self.notebook.connect("switch-page", self._on_tab_switched)

        # New-tab button on the notebook
        new_tab_btn = Gtk.Button()
        new_tab_btn.set_icon_name("list-add-symbolic")
        new_tab_btn.set_tooltip_text("New Tab  (Ctrl+T)")
        new_tab_btn.connect("clicked", lambda _b: self._add_new_tab())
        self.notebook.set_action_widget(new_tab_btn, Gtk.PackType.END)

        main_box.append(self.notebook)

        # Status bar
        self.statusbar = Gtk.Label(label="Ready")
        self.statusbar.set_xalign(0)
        self.statusbar.set_margin_start(8)
        self.statusbar.set_margin_end(8)
        self.statusbar.add_css_class("statusbar")
        main_box.append(self.statusbar)

        # -- Keyboard shortcuts ------------------------------------------------
        self._setup_shortcuts()

        # -- Volume monitor ----------------------------------------------------
        self.volume_monitor = Gio.VolumeMonitor.get()
        self.volume_monitor.connect("mount-added", lambda _vm, _m: self._refresh_sidebar())
        self.volume_monitor.connect("mount-removed", lambda _vm, _m: self._refresh_sidebar())

        # -- Open first tab ----------------------------------------------------
        self._add_new_tab(GLib.get_home_dir())

    # ------------------------------------------------------------------
    # Header bar construction
    # ------------------------------------------------------------------

    def _build_headerbar(self):
        hb = Gtk.HeaderBar()
        self.set_titlebar(hb)

        # Back / Forward
        self.back_btn = Gtk.Button(icon_name="go-previous-symbolic")
        self.back_btn.set_tooltip_text("Back  (Alt+Left)")
        self.back_btn.connect("clicked", lambda _b: self._navigate_back())
        hb.pack_start(self.back_btn)

        self.forward_btn = Gtk.Button(icon_name="go-next-symbolic")
        self.forward_btn.set_tooltip_text("Forward  (Alt+Right)")
        self.forward_btn.connect("clicked", lambda _b: self._navigate_forward())
        hb.pack_start(self.forward_btn)

        # Address bar
        self.address_entry = Gtk.Entry()
        self.address_entry.set_hexpand(True)
        self.address_entry.set_icon_from_icon_name(Gtk.EntryIconPosition.PRIMARY, "folder-symbolic")
        self.address_entry.connect("activate", self._on_address_activate)
        hb.set_title_widget(self.address_entry)

        # Search toggle
        search_btn = Gtk.ToggleButton(icon_name="edit-find-symbolic")
        search_btn.set_tooltip_text("Search")
        search_btn.connect("toggled", self._on_search_toggled)
        self.search_toggle = search_btn
        hb.pack_end(search_btn)

        # View mode buttons
        view_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        view_box.add_css_class("linked")
        self.icon_view_btn = Gtk.ToggleButton(icon_name="view-grid-symbolic")
        self.icon_view_btn.set_tooltip_text("Icon View")
        self.icon_view_btn.set_active(True)
        self.icon_view_btn.connect("toggled", self._on_view_mode, self.VIEW_ICON)
        view_box.append(self.icon_view_btn)

        self.list_view_btn = Gtk.ToggleButton(icon_name="view-list-symbolic")
        self.list_view_btn.set_tooltip_text("List View")
        self.list_view_btn.set_group(self.icon_view_btn)
        self.list_view_btn.connect("toggled", self._on_view_mode, self.VIEW_LIST)
        view_box.append(self.list_view_btn)

        self.detail_view_btn = Gtk.ToggleButton(icon_name="view-list-compact-symbolic")
        self.detail_view_btn.set_tooltip_text("Detail View")
        self.detail_view_btn.set_group(self.icon_view_btn)
        self.detail_view_btn.connect("toggled", self._on_view_mode, self.VIEW_DETAIL)
        view_box.append(self.detail_view_btn)
        hb.pack_end(view_box)

        # Menu button
        menu_btn = Gtk.MenuButton(icon_name="open-menu-symbolic")
        menu_btn.set_tooltip_text("Menu")
        menu = Gio.Menu()
        menu.append("New Folder", "win.new-folder")
        menu.append("New File", "win.new-file")
        menu.append("Show Hidden Files", "win.toggle-hidden")
        menu.append("Properties", "win.properties")
        menu.append("About", "win.about")
        menu_btn.set_menu_model(menu)
        hb.pack_end(menu_btn)

        # Register actions for the menu
        for name, cb in [
            ("new-folder", self._action_new_folder),
            ("new-file", self._action_new_file),
            ("toggle-hidden", self._action_toggle_hidden),
            ("properties", self._action_properties),
            ("about", self._action_about),
        ]:
            action = Gio.SimpleAction.new(name, None)
            action.connect("activate", cb)
            self.add_action(action)

    # ------------------------------------------------------------------
    # Keyboard shortcut setup
    # ------------------------------------------------------------------

    def _setup_shortcuts(self):
        ctrl = Gtk.EventControllerKey()
        ctrl.connect("key-pressed", self._on_key_pressed)
        self.add_controller(ctrl)

    def _on_key_pressed(self, controller, keyval, keycode, state):
        ctrl = bool(state & Gdk.ModifierType.CONTROL_MASK)
        alt = bool(state & Gdk.ModifierType.ALT_MASK)
        if ctrl and keyval == Gdk.KEY_t:
            self._add_new_tab()
            return True
        if ctrl and keyval == Gdk.KEY_w:
            self._close_current_tab()
            return True
        if ctrl and keyval == Gdk.KEY_c:
            self._clipboard_copy()
            return True
        if ctrl and keyval == Gdk.KEY_x:
            self._clipboard_cut()
            return True
        if ctrl and keyval == Gdk.KEY_v:
            self._clipboard_paste()
            return True
        if ctrl and keyval == Gdk.KEY_l:
            self.address_entry.grab_focus()
            return True
        if ctrl and keyval == Gdk.KEY_h:
            self._action_toggle_hidden(None, None)
            return True
        if alt and keyval == Gdk.KEY_Left:
            self._navigate_back()
            return True
        if alt and keyval == Gdk.KEY_Right:
            self._navigate_forward()
            return True
        if keyval == Gdk.KEY_Delete:
            self._delete_selected()
            return True
        if keyval == Gdk.KEY_F2:
            self._rename_selected()
            return True
        if keyval == Gdk.KEY_F5:
            self._refresh_current()
            return True
        return False

    # ------------------------------------------------------------------
    # Tab management
    # ------------------------------------------------------------------

    def _add_new_tab(self, path=None):
        tab = TabState(path)
        pane = self._build_tab_content(tab)
        tab.pane = pane

        # Tab label with close button
        tab_label_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        tab.label_widget = Gtk.Label(label=os.path.basename(tab.current_path) or "/")
        tab.label_widget.set_ellipsize(Pango.EllipsizeMode.END)
        tab.label_widget.set_max_width_chars(18)
        tab_label_box.append(tab.label_widget)

        close_btn = Gtk.Button(icon_name="window-close-symbolic")
        close_btn.set_has_frame(False)
        close_btn.connect("clicked", self._on_tab_close, tab)
        tab_label_box.append(close_btn)

        idx = self.notebook.append_page(pane, tab_label_box)
        self.tabs.append(tab)
        self.notebook.set_current_page(idx)
        self._navigate_to(tab.current_path)

    def _on_tab_close(self, _btn, tab):
        if len(self.tabs) <= 1:
            return
        idx = self.tabs.index(tab)
        self.tabs.remove(tab)
        self.notebook.remove_page(idx)

    def _close_current_tab(self):
        if len(self.tabs) <= 1:
            return
        idx = self.notebook.get_current_page()
        self.tabs.pop(idx)
        self.notebook.remove_page(idx)

    def _on_tab_switched(self, _nb, _page, idx):
        if idx < 0 or idx >= len(self.tabs):
            return
        self.current_tab_index = idx
        tab = self.tabs[idx]
        self.address_entry.set_text(tab.current_path)
        self._update_nav_buttons(tab)

    def _current_tab(self):
        idx = self.notebook.get_current_page()
        if 0 <= idx < len(self.tabs):
            return self.tabs[idx]
        return None

    # ------------------------------------------------------------------
    # Build tab content (sidebar + content area)
    # ------------------------------------------------------------------

    def _build_tab_content(self, tab):
        hbox = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        hbox.set_position(200)

        # Sidebar
        sidebar_scroll = Gtk.ScrolledWindow()
        sidebar_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        sidebar_scroll.set_size_request(180, -1)
        sidebar_scroll.add_css_class("sidebar")

        sidebar_list = Gtk.ListBox()
        sidebar_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        sidebar_list.connect("row-activated", self._on_sidebar_row_activated)
        tab.sidebar = sidebar_list
        sidebar_scroll.set_child(sidebar_list)
        hbox.set_start_child(sidebar_scroll)

        # Content scroll
        content_scroll = Gtk.ScrolledWindow()
        content_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        content_scroll.set_hexpand(True)
        content_scroll.set_vexpand(True)
        content_scroll.add_css_class("content-view")
        tab.content_scroll = content_scroll
        hbox.set_end_child(content_scroll)

        # List store
        tab.model = Gio.ListStore(item_type=FileItem)

        self._populate_sidebar(tab)
        return hbox

    # ------------------------------------------------------------------
    # Sidebar
    # ------------------------------------------------------------------

    def _populate_sidebar(self, tab):
        sidebar = tab.sidebar
        # Remove existing children
        while True:
            child = sidebar.get_first_child()
            if child is None:
                break
            sidebar.remove(child)

        def add_header(text):
            lbl = Gtk.Label(label=text.upper())
            lbl.set_xalign(0)
            lbl.add_css_class("sidebar-header")
            row = Gtk.ListBoxRow()
            row.set_selectable(False)
            row.set_activatable(False)
            row.set_child(lbl)
            sidebar.append(row)

        def add_item(icon, label, path):
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            img = Gtk.Image.new_from_icon_name(icon)
            img.set_pixel_size(18)
            box.append(img)
            lbl = Gtk.Label(label=label)
            lbl.set_xalign(0)
            lbl.set_hexpand(True)
            lbl.set_ellipsize(Pango.EllipsizeMode.END)
            box.append(lbl)
            row = Gtk.ListBoxRow()
            row.set_child(box)
            row._nav_path = path
            sidebar.append(row)

        home = GLib.get_home_dir()
        add_header("Quick Access")
        add_item("user-home", "Home", home)
        add_item("user-desktop", "Desktop", os.path.join(home, "Desktop"))
        add_item("folder-documents", "Documents", os.path.join(home, "Documents"))
        add_item("folder-download", "Downloads", os.path.join(home, "Downloads"))
        add_item("folder-music", "Music", os.path.join(home, "Music"))
        add_item("folder-pictures", "Pictures", os.path.join(home, "Pictures"))
        add_item("folder-videos", "Videos", os.path.join(home, "Videos"))

        add_header("Drives")
        add_item("drive-harddisk", "C: (/) — System", "/")
        add_item("drive-harddisk", "D: (/home) — Home", "/home")

        # Mounted volumes from Gio.VolumeMonitor
        try:
            for mount in self.volume_monitor.get_mounts():
                root = mount.get_root()
                if root:
                    mount_path = root.get_path()
                    mount_name = mount.get_name() or mount_path
                    add_item("drive-removable-media", mount_name, mount_path)
        except Exception:
            pass

        add_header("Other")
        add_item("user-trash", "Trash", "trash:///")

    def _refresh_sidebar(self):
        for tab in self.tabs:
            self._populate_sidebar(tab)

    def _on_sidebar_row_activated(self, _listbox, row):
        path = getattr(row, "_nav_path", None)
        if path:
            self._navigate_to(path)

    # ------------------------------------------------------------------
    # Navigation
    # ------------------------------------------------------------------

    def _navigate_to(self, path, push_history=True):
        tab = self._current_tab()
        if tab is None:
            return
        if not os.path.isdir(path) and path != "trash:///":
            self._open_file(path)
            return
        if push_history and tab.current_path != path:
            tab.back_stack.append(tab.current_path)
            tab.forward_stack.clear()
        tab.current_path = path
        self.address_entry.set_text(path)
        tab.label_widget.set_label(os.path.basename(path) or "/")
        self._update_nav_buttons(tab)
        self._load_directory(tab)

    def _navigate_back(self):
        tab = self._current_tab()
        if tab and tab.back_stack:
            tab.forward_stack.append(tab.current_path)
            dest = tab.back_stack.pop()
            self._navigate_to(dest, push_history=False)

    def _navigate_forward(self):
        tab = self._current_tab()
        if tab and tab.forward_stack:
            tab.back_stack.append(tab.current_path)
            dest = tab.forward_stack.pop()
            self._navigate_to(dest, push_history=False)

    def _update_nav_buttons(self, tab):
        self.back_btn.set_sensitive(bool(tab.back_stack))
        self.forward_btn.set_sensitive(bool(tab.forward_stack))

    def _on_address_activate(self, entry):
        path = entry.get_text().strip()
        if os.path.exists(path):
            self._navigate_to(path)

    # ------------------------------------------------------------------
    # Directory loading
    # ------------------------------------------------------------------

    def _load_directory(self, tab):
        tab.model.remove_all()
        path = tab.current_path
        try:
            entries = os.listdir(path)
        except PermissionError:
            self.statusbar.set_label("Permission denied")
            return
        except OSError as exc:
            self.statusbar.set_label(str(exc))
            return

        items = []
        for entry_name in entries:
            if not self.show_hidden and entry_name.startswith("."):
                continue
            full = os.path.join(path, entry_name)
            items.append(FileItem(full))

        # Sort: directories first, then alphabetical
        items.sort(key=lambda fi: (not fi.is_dir, fi.name.lower()))

        for item in items:
            tab.model.append(item)

        self._build_content_view(tab)
        self._update_statusbar(tab)

    def _build_content_view(self, tab):
        """Rebuild the content view widget according to current view mode."""
        if self.view_mode == self.VIEW_ICON:
            widget = self._create_icon_view(tab)
        elif self.view_mode == self.VIEW_LIST:
            widget = self._create_list_view(tab, detail=False)
        else:
            widget = self._create_list_view(tab, detail=True)
        tab.content_scroll.set_child(widget)

    # ------------------------------------------------------------------
    # Icon view
    # ------------------------------------------------------------------

    def _create_icon_view(self, tab):
        factory = Gtk.SignalListItemFactory()
        factory.connect("setup", self._icon_setup)
        factory.connect("bind", self._icon_bind)

        sel_model = Gtk.MultiSelection(model=tab.model)
        grid = Gtk.GridView(model=sel_model, factory=factory)
        grid.set_max_columns(12)
        grid.set_min_columns(3)
        grid.add_css_class("content-view")
        grid.connect("activate", self._on_item_activated, tab)

        # Right-click
        rc = Gtk.GestureClick(button=3)
        rc.connect("pressed", self._on_right_click, tab, sel_model)
        grid.add_controller(rc)

        tab.selection_model = sel_model
        return grid

    def _icon_setup(self, _factory, list_item):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.set_halign(Gtk.Align.CENTER)
        box.set_valign(Gtk.Align.START)
        box.set_size_request(96, 96)
        box.add_css_class("file-icon-item")

        icon = Gtk.Image()
        icon.set_pixel_size(48)
        box.append(icon)

        label = Gtk.Label()
        label.set_ellipsize(Pango.EllipsizeMode.END)
        label.set_max_width_chars(14)
        label.set_justify(Gtk.Justification.CENTER)
        label.set_wrap(True)
        label.set_wrap_mode(Pango.WrapMode.WORD_CHAR)
        label.set_lines(2)
        label.add_css_class("file-name-label")
        box.append(label)

        list_item.set_child(box)

    def _icon_bind(self, _factory, list_item):
        item = list_item.get_item()
        box = list_item.get_child()
        icon = box.get_first_child()
        label = icon.get_next_sibling()
        label.set_label(item.name)

        # Try thumbnail for images
        if not item.is_dir and is_image_file(item.filepath):
            thumb = self._get_thumbnail(item.filepath)
            if thumb:
                icon.set_from_paintable(Gdk.Texture.new_for_pixbuf(thumb))
            else:
                icon.set_from_icon_name(item.icon_name)
        else:
            icon.set_from_icon_name(item.icon_name)

    def _get_thumbnail(self, filepath):
        """Load or cache a thumbnail pixbuf."""
        if filepath in self._thumbnail_cache:
            return self._thumbnail_cache[filepath]
        try:
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(filepath, 48, 48, True)
            self._thumbnail_cache[filepath] = pixbuf
            return pixbuf
        except Exception:
            return None

    # ------------------------------------------------------------------
    # List / Detail view  (ColumnView)
    # ------------------------------------------------------------------

    def _create_list_view(self, tab, detail=False):
        sel_model = Gtk.MultiSelection(model=tab.model)
        tab.selection_model = sel_model

        cv = Gtk.ColumnView(model=sel_model)
        cv.add_css_class("content-view")

        # Name column
        name_factory = Gtk.SignalListItemFactory()
        name_factory.connect("setup", self._list_name_setup)
        name_factory.connect("bind", self._list_name_bind)
        name_col = Gtk.ColumnViewColumn(title="Name", factory=name_factory)
        name_col.set_expand(True)
        name_col.set_resizable(True)
        cv.append_column(name_col)

        # Size column
        size_factory = Gtk.SignalListItemFactory()
        size_factory.connect("setup", self._list_label_setup)
        size_factory.connect("bind", self._list_size_bind)
        size_col = Gtk.ColumnViewColumn(title="Size", factory=size_factory)
        size_col.set_fixed_width(100)
        size_col.set_resizable(True)
        cv.append_column(size_col)

        # Type column
        type_factory = Gtk.SignalListItemFactory()
        type_factory.connect("setup", self._list_label_setup)
        type_factory.connect("bind", self._list_type_bind)
        type_col = Gtk.ColumnViewColumn(title="Type", factory=type_factory)
        type_col.set_fixed_width(140)
        type_col.set_resizable(True)
        cv.append_column(type_col)

        # Date Modified column
        date_factory = Gtk.SignalListItemFactory()
        date_factory.connect("setup", self._list_label_setup)
        date_factory.connect("bind", self._list_date_bind)
        date_col = Gtk.ColumnViewColumn(title="Date Modified", factory=date_factory)
        date_col.set_fixed_width(160)
        date_col.set_resizable(True)
        cv.append_column(date_col)

        # Extra detail columns
        if detail:
            perm_factory = Gtk.SignalListItemFactory()
            perm_factory.connect("setup", self._list_label_setup)
            perm_factory.connect("bind", self._list_perm_bind)
            perm_col = Gtk.ColumnViewColumn(title="Permissions", factory=perm_factory)
            perm_col.set_fixed_width(120)
            perm_col.set_resizable(True)
            cv.append_column(perm_col)

            mime_factory = Gtk.SignalListItemFactory()
            mime_factory.connect("setup", self._list_label_setup)
            mime_factory.connect("bind", self._list_mime_bind)
            mime_col = Gtk.ColumnViewColumn(title="MIME Type", factory=mime_factory)
            mime_col.set_fixed_width(160)
            mime_col.set_resizable(True)
            cv.append_column(mime_col)

        cv.connect("activate", self._on_item_activated, tab)

        # Right-click
        rc = Gtk.GestureClick(button=3)
        rc.connect("pressed", self._on_right_click, tab, sel_model)
        cv.add_controller(rc)

        return cv

    def _list_name_setup(self, _factory, list_item):
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        icon = Gtk.Image()
        icon.set_pixel_size(20)
        box.append(icon)
        label = Gtk.Label()
        label.set_xalign(0)
        label.set_ellipsize(Pango.EllipsizeMode.END)
        label.add_css_class("file-name-label")
        box.append(label)
        list_item.set_child(box)

    def _list_name_bind(self, _factory, list_item):
        item = list_item.get_item()
        box = list_item.get_child()
        icon = box.get_first_child()
        label = icon.get_next_sibling()
        icon.set_from_icon_name(item.icon_name)
        label.set_label(item.name)

    def _list_label_setup(self, _factory, list_item):
        label = Gtk.Label()
        label.set_xalign(0)
        label.set_ellipsize(Pango.EllipsizeMode.END)
        label.add_css_class("file-detail-label")
        list_item.set_child(label)

    def _list_size_bind(self, _factory, list_item):
        item = list_item.get_item()
        list_item.get_child().set_label(format_size(item.size))

    def _list_type_bind(self, _factory, list_item):
        item = list_item.get_item()
        list_item.get_child().set_label(item.type_label)

    def _list_date_bind(self, _factory, list_item):
        item = list_item.get_item()
        list_item.get_child().set_label(format_time(item.mtime))

    def _list_perm_bind(self, _factory, list_item):
        item = list_item.get_item()
        list_item.get_child().set_label(item.permissions)

    def _list_mime_bind(self, _factory, list_item):
        item = list_item.get_item()
        list_item.get_child().set_label(get_mime_type(item.filepath))

    # ------------------------------------------------------------------
    # Item activation (double-click / enter)
    # ------------------------------------------------------------------

    def _on_item_activated(self, _view, position, tab):
        item = tab.model.get_item(position)
        if item is None:
            return
        if item.is_dir:
            self._navigate_to(item.filepath)
        else:
            self._open_file(item.filepath)

    def _open_file(self, filepath):
        """Open a file with the default application."""
        try:
            gfile = Gio.File.new_for_path(filepath)
            launcher = Gtk.FileLauncher(file=gfile)
            launcher.launch(self, None, None)
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Right-click context menu
    # ------------------------------------------------------------------

    def _on_right_click(self, gesture, _n, x, y, tab, sel_model):
        menu_model = Gio.Menu()
        menu_model.append("Open", "win.ctx-open")
        menu_model.append("Open With…", "win.ctx-open-with")

        sep1 = Gio.Menu()
        sep1.append("Cut", "win.ctx-cut")
        sep1.append("Copy", "win.ctx-copy")
        sep1.append("Paste", "win.ctx-paste")
        menu_model.append_section(None, sep1)

        sep2 = Gio.Menu()
        sep2.append("Rename", "win.ctx-rename")
        sep2.append("Delete (Trash)", "win.ctx-delete")
        sep2.append("Delete Permanently", "win.ctx-delete-perm")
        menu_model.append_section(None, sep2)

        sep3 = Gio.Menu()
        sep3.append("New Folder", "win.new-folder")
        sep3.append("New File", "win.new-file")
        menu_model.append_section(None, sep3)

        sep4 = Gio.Menu()
        sep4.append("Compress…", "win.ctx-compress")
        sep4.append("Extract Here", "win.ctx-extract")
        sep4.append("Properties", "win.properties")
        menu_model.append_section(None, sep4)

        # Register context actions (idempotent via lookup)
        for name, cb in [
            ("ctx-open", lambda *_a: self._ctx_open()),
            ("ctx-open-with", lambda *_a: self._ctx_open_with()),
            ("ctx-cut", lambda *_a: self._clipboard_cut()),
            ("ctx-copy", lambda *_a: self._clipboard_copy()),
            ("ctx-paste", lambda *_a: self._clipboard_paste()),
            ("ctx-rename", lambda *_a: self._rename_selected()),
            ("ctx-delete", lambda *_a: self._delete_selected()),
            ("ctx-delete-perm", lambda *_a: self._delete_selected(permanent=True)),
            ("ctx-compress", lambda *_a: self._compress_selected()),
            ("ctx-extract", lambda *_a: self._extract_selected()),
        ]:
            if not self.lookup_action(name):
                action = Gio.SimpleAction.new(name, None)
                action.connect("activate", cb)
                self.add_action(action)

        popover = Gtk.PopoverMenu(menu_model=menu_model)
        popover.set_parent(gesture.get_widget())
        rect = Gdk.Rectangle()
        rect.x, rect.y, rect.width, rect.height = int(x), int(y), 1, 1
        popover.set_pointing_to(rect)
        popover.popup()

    # ------------------------------------------------------------------
    # Context actions
    # ------------------------------------------------------------------

    def _get_selected_items(self):
        tab = self._current_tab()
        if not tab or not hasattr(tab, "selection_model"):
            return []
        sel = tab.selection_model
        bitset = sel.get_selection()
        items = []
        pos = 0
        while pos < bitset.get_size():
            idx = bitset.get_nth(pos)
            item = tab.model.get_item(idx)
            if item:
                items.append(item)
            pos += 1
        return items

    def _ctx_open(self):
        for item in self._get_selected_items():
            if item.is_dir:
                self._navigate_to(item.filepath)
            else:
                self._open_file(item.filepath)
            break

    def _ctx_open_with(self):
        items = self._get_selected_items()
        if items:
            try:
                gfile = Gio.File.new_for_path(items[0].filepath)
                launcher = Gtk.FileLauncher(file=gfile)
                launcher.open_containing_folder(self, None, None)
            except Exception:
                pass

    # ------------------------------------------------------------------
    # Clipboard operations
    # ------------------------------------------------------------------

    def _clipboard_copy(self):
        self.clipboard_files = [i.filepath for i in self._get_selected_items()]
        self.clipboard_cut = False
        count = len(self.clipboard_files)
        self.statusbar.set_label(f"{count} item(s) copied")

    def _clipboard_cut(self):
        self.clipboard_files = [i.filepath for i in self._get_selected_items()]
        self.clipboard_cut = True
        count = len(self.clipboard_files)
        self.statusbar.set_label(f"{count} item(s) cut")

    def _clipboard_paste(self):
        tab = self._current_tab()
        if not tab or not self.clipboard_files:
            return
        dest_dir = tab.current_path
        for src in self.clipboard_files:
            basename = os.path.basename(src)
            dest = os.path.join(dest_dir, basename)
            # Avoid overwrite by appending suffix
            counter = 1
            original_dest = dest
            while os.path.exists(dest):
                name, ext = os.path.splitext(basename)
                dest = os.path.join(dest_dir, f"{name} ({counter}){ext}")
                counter += 1
            try:
                if self.clipboard_cut:
                    if os.path.isdir(src):
                        shutil.move(src, dest)
                    else:
                        shutil.move(src, dest)
                else:
                    if os.path.isdir(src):
                        shutil.copytree(src, dest)
                    else:
                        gfile_src = Gio.File.new_for_path(src)
                        gfile_dst = Gio.File.new_for_path(dest)
                        gfile_src.copy(gfile_dst, Gio.FileCopyFlags.NONE, None, None, None)
            except Exception as exc:
                self.statusbar.set_label(f"Paste error: {exc}")
                return
        if self.clipboard_cut:
            self.clipboard_files.clear()
            self.clipboard_cut = False
        self._refresh_current()
        self.statusbar.set_label("Paste complete")

    # ------------------------------------------------------------------
    # Delete operations
    # ------------------------------------------------------------------

    def _delete_selected(self, permanent=False):
        items = self._get_selected_items()
        if not items:
            return
        for item in items:
            try:
                if permanent:
                    if item.is_dir:
                        shutil.rmtree(item.filepath)
                    else:
                        os.remove(item.filepath)
                else:
                    gfile = Gio.File.new_for_path(item.filepath)
                    gfile.trash(None)
            except Exception as exc:
                self.statusbar.set_label(f"Delete error: {exc}")
                return
        self._refresh_current()
        kind = "permanently deleted" if permanent else "moved to trash"
        self.statusbar.set_label(f"{len(items)} item(s) {kind}")

    # ------------------------------------------------------------------
    # Rename
    # ------------------------------------------------------------------

    def _rename_selected(self):
        items = self._get_selected_items()
        if not items:
            return
        item = items[0]

        dialog = Gtk.AlertDialog()
        dialog.set_message("Rename")
        dialog.set_detail(f"Enter new name for '{item.name}':")
        dialog.set_buttons(["Cancel", "Rename"])
        dialog.set_default_button(1)
        dialog.set_cancel_button(0)

        def on_response(d, result):
            try:
                idx = d.choose_finish(result)
            except Exception:
                return
            # GTK4 AlertDialog doesn't support text input natively;
            # fall back to a simple dialog approach
        dialog.choose(self, None, on_response)

    # ------------------------------------------------------------------
    # Compress / Extract
    # ------------------------------------------------------------------

    def _compress_selected(self):
        items = self._get_selected_items()
        if not items:
            return
        tab = self._current_tab()
        archive_name = os.path.join(tab.current_path, items[0].name + ".tar.gz")
        try:
            import tarfile
            with tarfile.open(archive_name, "w:gz") as tar:
                for item in items:
                    tar.add(item.filepath, arcname=item.name)
            self._refresh_current()
            self.statusbar.set_label(f"Compressed to {os.path.basename(archive_name)}")
        except Exception as exc:
            self.statusbar.set_label(f"Compress error: {exc}")

    def _extract_selected(self):
        items = self._get_selected_items()
        if not items:
            return
        tab = self._current_tab()
        item = items[0]
        try:
            import tarfile
            import zipfile
            if tarfile.is_tarfile(item.filepath):
                with tarfile.open(item.filepath) as tar:
                    tar.extractall(path=tab.current_path)
            elif zipfile.is_zipfile(item.filepath):
                with zipfile.ZipFile(item.filepath, 'r') as zf:
                    zf.extractall(path=tab.current_path)
            self._refresh_current()
            self.statusbar.set_label("Extraction complete")
        except Exception as exc:
            self.statusbar.set_label(f"Extract error: {exc}")

    # ------------------------------------------------------------------
    # View mode
    # ------------------------------------------------------------------

    def _on_view_mode(self, btn, mode):
        if btn.get_active():
            self.view_mode = mode
            tab = self._current_tab()
            if tab:
                self._build_content_view(tab)

    # ------------------------------------------------------------------
    # Search
    # ------------------------------------------------------------------

    def _on_search_toggled(self, btn):
        self.search_bar.set_search_mode(btn.get_active())

    def _on_search_changed(self, entry):
        query = entry.get_text().strip().lower()
        tab = self._current_tab()
        if not tab:
            return
        if not query:
            self._load_directory(tab)
            return
        # Filter current model
        tab.model.remove_all()
        try:
            for name in os.listdir(tab.current_path):
                if not self.show_hidden and name.startswith("."):
                    continue
                if query in name.lower():
                    full = os.path.join(tab.current_path, name)
                    tab.model.append(FileItem(full))
        except OSError:
            pass
        self._build_content_view(tab)

    # ------------------------------------------------------------------
    # Menu actions
    # ------------------------------------------------------------------

    def _action_new_folder(self, _action, _param):
        tab = self._current_tab()
        if not tab:
            return
        base = os.path.join(tab.current_path, "New Folder")
        path = base
        counter = 1
        while os.path.exists(path):
            path = f"{base} ({counter})"
            counter += 1
        try:
            os.makedirs(path)
            self._refresh_current()
            self.statusbar.set_label(f"Created folder: {os.path.basename(path)}")
        except OSError as exc:
            self.statusbar.set_label(f"Error: {exc}")

    def _action_new_file(self, _action, _param):
        tab = self._current_tab()
        if not tab:
            return
        base = os.path.join(tab.current_path, "New File")
        path = base
        counter = 1
        while os.path.exists(path):
            path = f"{base} ({counter})"
            counter += 1
        try:
            Path(path).touch()
            self._refresh_current()
            self.statusbar.set_label(f"Created file: {os.path.basename(path)}")
        except OSError as exc:
            self.statusbar.set_label(f"Error: {exc}")

    def _action_toggle_hidden(self, _action, _param):
        self.show_hidden = not self.show_hidden
        self._refresh_current()
        state = "shown" if self.show_hidden else "hidden"
        self.statusbar.set_label(f"Hidden files {state}")

    def _action_properties(self, _action, _param):
        items = self._get_selected_items()
        if not items:
            tab = self._current_tab()
            if tab:
                items = [FileItem(tab.current_path)]
        if not items:
            return
        item = items[0]
        self._show_properties_dialog(item)

    def _show_properties_dialog(self, item):
        dialog = Gtk.AlertDialog()
        dialog.set_message(f"Properties — {item.name}")
        try:
            st = os.stat(item.filepath)
            detail_lines = [
                f"Path: {item.filepath}",
                f"Type: {item.type_label}",
                f"Size: {format_size(item.size)}",
                f"Modified: {format_time(item.mtime)}",
                f"Permissions: {item.permissions}",
                f"MIME: {get_mime_type(item.filepath)}",
            ]
            if item.is_dir:
                try:
                    count = len(os.listdir(item.filepath))
                    detail_lines.append(f"Contains: {count} items")
                except OSError:
                    pass
            dialog.set_detail("\n".join(detail_lines))
        except OSError:
            dialog.set_detail("Could not read file properties.")
        dialog.set_buttons(["Close"])
        dialog.set_default_button(0)
        dialog.choose(self, None, None)

    def _action_about(self, _action, _param):
        dialog = Gtk.AlertDialog()
        dialog.set_message("SatasOS Files")
        dialog.set_detail(
            "A modern file manager for SatasOS.\n\n"
            "Version 1.0\n"
            "Built with GTK4 and Python\n\n"
            "© 2025 SatasOS Project"
        )
        dialog.set_buttons(["Close"])
        dialog.set_default_button(0)
        dialog.choose(self, None, None)

    # ------------------------------------------------------------------
    # Refresh / Status
    # ------------------------------------------------------------------

    def _refresh_current(self):
        tab = self._current_tab()
        if tab:
            self._load_directory(tab)

    def _update_statusbar(self, tab):
        try:
            total = tab.model.get_n_items()
            statvfs = os.statvfs(tab.current_path)
            free = statvfs.f_frsize * statvfs.f_bavail
            free_str = format_size(free)
        except (OSError, AttributeError):
            total = tab.model.get_n_items()
            try:
                usage = shutil.disk_usage(tab.current_path)
                free_str = format_size(usage.free)
            except (OSError, AttributeError):
                free_str = "N/A"

        self.statusbar.set_label(f"{total} items  |  Free space: {free_str}")


# ---------------------------------------------------------------------------
# SatasOSFileManager Application
# ---------------------------------------------------------------------------

class SatasOSFileManager(Gtk.Application):
    """Main application class for SatasOS Files."""

    def __init__(self):
        super().__init__(
            application_id="org.satasos.files",
            flags=Gio.ApplicationFlags.HANDLES_OPEN,
        )
        self.connect("activate", self._on_activate)
        self.connect("open", self._on_open)

    def _on_activate(self, _app):
        win = FileManagerWindow(self)
        win.present()

    def _on_open(self, _app, files, _n, _hint):
        win = FileManagerWindow(self)
        for gfile in files:
            path = gfile.get_path()
            if path and os.path.isdir(path):
                win._navigate_to(path)
                break
        win.present()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    app = SatasOSFileManager()
    return app.run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
