#!/usr/bin/env python3
"""
SatasOS Settings Application
Android-style settings panel built with GTK4 and Libadwaita.
"""

import os
import sys
import platform
import subprocess

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
gi.require_version('Pango', '1.0')

from gi.repository import Gtk, Gdk, Gio, GLib, Pango

try:
    gi.require_version('Adw', '1')
    from gi.repository import Adw
    HAS_ADW = True
except (ValueError, ImportError):
    HAS_ADW = False

# ---------------------------------------------------------------------------
# Brand colours
# ---------------------------------------------------------------------------
SATASOS_CSS = b"""
/* SatasOS Settings Dark Theme */
window, .main-box {
    background-color: #1E1B2E;
    color: #E8E0F0;
}

headerbar {
    background-color: #1E1B2E;
    color: #E8E0F0;
    border-bottom: 1px solid #2D2640;
    box-shadow: none;
}

headerbar title {
    color: #E8E0F0;
    font-weight: bold;
}

.category-sidebar {
    background-color: #1E1B2E;
    border-right: 1px solid #2D2640;
    padding: 6px;
}

.category-sidebar row {
    border-radius: 10px;
    padding: 10px 14px;
    margin: 2px 4px;
    color: #E8E0F0;
}

.category-sidebar row:selected {
    background-color: #7C3AED;
    color: #ffffff;
}

.category-sidebar row:hover:not(:selected) {
    background-color: #2D2640;
}

.category-sidebar row image {
    margin-right: 10px;
}

.settings-page {
    background-color: #1E1B2E;
    padding: 18px 24px;
}

.setting-row {
    background-color: #2D2640;
    border-radius: 12px;
    padding: 14px 18px;
    margin-bottom: 8px;
}

.setting-row:hover {
    background-color: #3A3354;
}

.setting-title {
    color: #E8E0F0;
    font-weight: bold;
    font-size: 14px;
}

.setting-subtitle {
    color: #A89FBF;
    font-size: 12px;
}

.section-header {
    color: #7C3AED;
    font-weight: bold;
    font-size: 13px;
    margin-top: 16px;
    margin-bottom: 6px;
    padding-left: 4px;
}

switch:checked slider {
    background-color: #7C3AED;
}

switch:checked {
    background-color: #5B21B6;
}

scale trough highlight {
    background-color: #7C3AED;
}

scale slider {
    background-color: #E8E0F0;
}

.accent-btn {
    border-radius: 50%;
    min-width: 32px;
    min-height: 32px;
    padding: 0;
    border: 2px solid transparent;
}

.accent-btn:checked, .accent-btn.selected {
    border-color: #ffffff;
}

.storage-label {
    color: #E8E0F0;
    font-size: 12px;
}

.about-logo {
    font-size: 48px;
    color: #7C3AED;
    font-weight: 800;
}

.about-version {
    color: #A89FBF;
    font-size: 13px;
}

.about-info-row {
    background-color: #2D2640;
    border-radius: 12px;
    padding: 12px 18px;
    margin-bottom: 6px;
}

.app-row {
    background-color: #2D2640;
    border-radius: 10px;
    padding: 10px 14px;
    margin-bottom: 4px;
}

.chart-area {
    background-color: #2D2640;
    border-radius: 12px;
}

.search-bar {
    background-color: #2D2640;
}

.search-result-row {
    background-color: #2D2640;
    border-radius: 10px;
    padding: 12px 16px;
    margin-bottom: 4px;
}

button.destructive-action {
    background-color: #DC2626;
    color: #ffffff;
}

button.suggested-action {
    background-color: #7C3AED;
    color: #ffffff;
}

button.suggested-action:hover {
    background-color: #6D28D9;
}

dropdown button {
    background-color: #2D2640;
    color: #E8E0F0;
    border-radius: 8px;
    border: 1px solid #3A3354;
}

levelbar trough block.filled {
    background-color: #7C3AED;
}

levelbar trough block.empty {
    background-color: #3A3354;
}
"""

# ---------------------------------------------------------------------------
# Categories
# ---------------------------------------------------------------------------
CATEGORIES = [
    ("network-wireless-symbolic",      "Network",    "WiFi, Bluetooth, VPN"),
    ("video-display-symbolic",         "Display",    "Brightness, resolution, night light"),
    ("audio-volume-high-symbolic",     "Sound",      "Volume, output, input devices"),
    ("battery-symbolic",               "Battery",    "Battery status and power saving"),
    ("drive-harddisk-symbolic",        "Storage",    "Disk usage and cleanup"),
    ("application-x-executable-symbolic", "Apps",    "Installed and default apps"),
    ("preferences-desktop-wallpaper-symbolic", "Appearance", "Theme, wallpaper, fonts"),
    ("emblem-system-symbolic",         "System",     "Language, date, accessibility"),
    ("help-about-symbolic",            "About",      "SatasOS information"),
]

# ---------------------------------------------------------------------------
# Search index – every setting with its category
# ---------------------------------------------------------------------------
SEARCH_ENTRIES = [
    ("Network", "WiFi",               "Turn wireless networking on or off"),
    ("Network", "Bluetooth",          "Connect Bluetooth devices"),
    ("Network", "Airplane Mode",      "Disable all radios"),
    ("Network", "VPN",                "Virtual private network"),
    ("Display", "Brightness",         "Adjust screen brightness"),
    ("Display", "Resolution",         "Screen resolution"),
    ("Display", "Refresh Rate",       "Monitor refresh rate"),
    ("Display", "Night Light",        "Reduce blue light at night"),
    ("Display", "Scale / Zoom",       "Interface scaling factor"),
    ("Sound",   "Master Volume",      "System output volume"),
    ("Sound",   "Output Device",      "Choose speakers or headphones"),
    ("Sound",   "Input Device",       "Microphone selection"),
    ("Sound",   "System Sounds",      "Enable or disable UI sounds"),
    ("Sound",   "Do Not Disturb",     "Mute all notifications"),
    ("Battery", "Battery Saver",      "Extend battery life"),
    ("Battery", "Screen Timeout",     "Turn off display after inactivity"),
    ("Battery", "Power Button",       "Action when pressing power button"),
    ("Storage", "Storage Usage",      "Breakdown of disk usage"),
    ("Storage", "Trash",              "Empty the trash bin"),
    ("Storage", "Temporary Files",    "Clean up temp files"),
    ("Apps",    "Installed Apps",      "List of installed applications"),
    ("Apps",    "Default Apps",        "Browser, email, file manager"),
    ("Apps",    "Startup Apps",        "Apps that run on login"),
    ("Appearance", "Theme",           "Dark or light mode"),
    ("Appearance", "Accent Colour",   "Pick accent colour"),
    ("Appearance", "Wallpaper",       "Change desktop wallpaper"),
    ("Appearance", "Icon Theme",      "Select icon set"),
    ("Appearance", "Font",            "System font"),
    ("Appearance", "Cursor Theme",    "Select cursor style"),
    ("System",  "Language",           "Display language"),
    ("System",  "Region / Timezone",  "Location and clock"),
    ("System",  "Keyboard Layout",    "Input method and layout"),
    ("System",  "Date & Time",        "Clock settings"),
    ("System",  "Accessibility",      "Large text, high contrast"),
    ("About",   "OS Version",         "SatasOS version information"),
    ("About",   "Hardware",           "CPU, RAM, hostname"),
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _icon(name, size=16):
    """Return a Gtk.Image for the given icon name."""
    img = Gtk.Image.new_from_icon_name(name)
    img.set_pixel_size(size)
    return img


def _label(text, css_class=None, xalign=0.0, wrap=False):
    """Convenience label builder."""
    lbl = Gtk.Label(label=text)
    lbl.set_xalign(xalign)
    lbl.set_hexpand(True)
    if wrap:
        lbl.set_wrap(True)
        lbl.set_wrap_mode(Pango.WrapMode.WORD_CHAR)
    if css_class:
        lbl.add_css_class(css_class)
    return lbl


def create_setting_row(icon_name, title, subtitle, widget):
    """
    Build a consistent settings row with icon, title/subtitle, and a trailing
    control widget (switch, dropdown, slider, etc.).
    """
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.add_css_class("setting-row")

    if icon_name:
        row.append(_icon(icon_name, 22))

    text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    text_box.set_hexpand(True)
    text_box.set_valign(Gtk.Align.CENTER)
    text_box.append(_label(title, "setting-title"))
    if subtitle:
        text_box.append(_label(subtitle, "setting-subtitle"))
    row.append(text_box)

    if widget is not None:
        widget.set_valign(Gtk.Align.CENTER)
        row.append(widget)

    return row


def _section_label(text):
    return _label(text, css_class="section-header")


def _make_switch(active=False):
    sw = Gtk.Switch()
    sw.set_active(active)
    return sw


def _string_list_dropdown(items, active=0):
    string_list = Gtk.StringList()
    for i in items:
        string_list.append(i)
    dd = Gtk.DropDown(model=string_list)
    dd.set_selected(active)
    return dd


def _read_proc_info():
    """Attempt to read basic hardware info from /proc (Linux only)."""
    cpu_model = "Unknown"
    mem_total = "Unknown"
    try:
        with open("/proc/cpuinfo", "r") as f:
            for line in f:
                if line.startswith("model name"):
                    cpu_model = line.split(":", 1)[1].strip()
                    break
    except OSError:
        pass
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                if line.startswith("MemTotal"):
                    kb = int(line.split()[1])
                    mem_total = f"{kb / 1048576:.1f} GB"
                    break
    except OSError:
        pass
    return cpu_model, mem_total


# ===================================================================
# Page builders
# ===================================================================

def _build_network_page():
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.add_css_class("settings-page")

    box.append(_section_label("Wireless"))
    box.append(create_setting_row("network-wireless-symbolic", "WiFi", "Connected to SatasOS-5G", _make_switch(True)))

    # Mock WiFi list
    wifi_networks = [
        ("SatasOS-5G", "network-wireless-signal-excellent-symbolic", True),
        ("Neighbor_Net", "network-wireless-signal-good-symbolic", False),
        ("CoffeeShop_Free", "network-wireless-signal-ok-symbolic", False),
        ("Hidden_Network", "network-wireless-signal-weak-symbolic", False),
    ]
    for ssid, sig_icon, connected in wifi_networks:
        status = "Connected" if connected else "Saved" if ssid == "Neighbor_Net" else ""
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        row.add_css_class("setting-row")
        row.append(_icon(sig_icon, 18))
        tbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        tbox.set_hexpand(True)
        tbox.append(_label(ssid, "setting-title"))
        if status:
            tbox.append(_label(status, "setting-subtitle"))
        row.append(tbox)
        if connected:
            check = _icon("emblem-ok-symbolic", 16)
            row.append(check)
        box.append(row)

    box.append(_section_label("Connections"))
    box.append(create_setting_row("bluetooth-active-symbolic", "Bluetooth", "On", _make_switch(True)))
    box.append(create_setting_row("airplane-mode-symbolic", "Airplane Mode", "Off", _make_switch(False)))

    box.append(_section_label("VPN"))
    box.append(create_setting_row("network-vpn-symbolic", "VPN", "Not connected", _make_switch(False)))
    btn = Gtk.Button(label="Add VPN…")
    btn.add_css_class("suggested-action")
    vbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
    vbox.set_halign(Gtk.Align.START)
    vbox.append(btn)
    box.append(vbox)

    return box


def _build_display_page():
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.add_css_class("settings-page")

    box.append(_section_label("Brightness"))
    brightness = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
    brightness.set_value(75)
    brightness.set_hexpand(True)
    brightness.set_size_request(200, -1)
    box.append(create_setting_row("display-brightness-symbolic", "Brightness", "75 %", brightness))

    box.append(_section_label("Screen"))
    box.append(create_setting_row("video-display-symbolic", "Resolution",
                                  "Current display resolution",
                                  _string_list_dropdown(["3840 × 2160", "2560 × 1440", "1920 × 1080", "1366 × 768"], 2)))

    box.append(create_setting_row("video-display-symbolic", "Refresh Rate",
                                  "Monitor refresh rate",
                                  _string_list_dropdown(["60 Hz", "75 Hz", "120 Hz", "144 Hz"], 0)))

    box.append(_section_label("Night Light"))
    box.append(create_setting_row("night-light-symbolic", "Night Light", "Reduce blue light in the evening", _make_switch(False)))
    box.append(create_setting_row("night-light-symbolic", "Schedule",
                                  "Sunset to sunrise",
                                  _string_list_dropdown(["Sunset to Sunrise", "Manual Schedule", "Disabled"], 0)))

    box.append(_section_label("Scaling"))
    box.append(create_setting_row("zoom-in-symbolic", "Scale / Zoom",
                                  "Interface scaling factor",
                                  _string_list_dropdown(["100 %", "125 %", "150 %", "200 %"], 0)))

    return box


def _build_sound_page():
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.add_css_class("settings-page")

    box.append(_section_label("Output"))
    vol = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
    vol.set_value(65)
    vol.set_hexpand(True)
    vol.set_size_request(200, -1)
    box.append(create_setting_row("audio-volume-high-symbolic", "Master Volume", "65 %", vol))
    box.append(create_setting_row("audio-speakers-symbolic", "Output Device",
                                  "Select playback device",
                                  _string_list_dropdown(["Built-in Speakers", "HDMI Audio", "Bluetooth Headphones"], 0)))

    box.append(_section_label("Input"))
    box.append(create_setting_row("audio-input-microphone-symbolic", "Input Device",
                                  "Select recording device",
                                  _string_list_dropdown(["Built-in Microphone", "USB Microphone", "Line In"], 0)))
    mic_vol = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
    mic_vol.set_value(80)
    mic_vol.set_hexpand(True)
    mic_vol.set_size_request(200, -1)
    box.append(create_setting_row("audio-input-microphone-symbolic", "Microphone Volume", "80 %", mic_vol))

    box.append(_section_label("Notifications"))
    box.append(create_setting_row("audio-volume-medium-symbolic", "System Sounds", "Play sounds for UI events", _make_switch(True)))
    box.append(create_setting_row("audio-volume-medium-symbolic", "Alert Sound",
                                  "Choose notification sound",
                                  _string_list_dropdown(["Chime", "Ping", "Pop", "Bell", "None"], 0)))
    box.append(create_setting_row("notifications-disabled-symbolic", "Do Not Disturb",
                                  "Mute all notification sounds", _make_switch(False)))

    return box


def _battery_chart_draw(_area, cr, width, height):
    """Cairo draw function for a simple battery usage bar chart."""
    bars = [
        ("#7C3AED", 0.8, "Screen"),
        ("#6D28D9", 0.5, "System"),
        ("#5B21B6", 0.35, "WiFi"),
        ("#9F7AEA", 0.25, "Apps"),
        ("#3A3354", 0.15, "Other"),
    ]
    n = len(bars)
    bar_w = max(width / (n * 2), 20)
    gap = (width - bar_w * n) / (n + 1)
    max_h = height - 36

    # Background
    cr.set_source_rgba(0.176, 0.149, 0.251, 1)  # #2D2640
    cr.rectangle(0, 0, width, height)
    cr.fill()

    for i, (colour, frac, name) in enumerate(bars):
        x = gap + i * (bar_w + gap)
        bh = frac * max_h
        y = height - 24 - bh

        r = int(colour[1:3], 16) / 255.0
        g = int(colour[3:5], 16) / 255.0
        b = int(colour[5:7], 16) / 255.0
        cr.set_source_rgb(r, g, b)
        cr.rectangle(x, y, bar_w, bh)
        cr.fill()

        cr.set_source_rgb(0.91, 0.88, 0.94)
        cr.set_font_size(10)
        tw = cr.text_extents(name).width
        cr.move_to(x + (bar_w - tw) / 2, height - 6)
        cr.show_text(name)


def _build_battery_page():
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.add_css_class("settings-page")

    box.append(_section_label("Battery Status"))
    box.append(create_setting_row("battery-good-symbolic", "Battery Level", "78 % — about 4 h 32 min remaining", None))
    box.append(create_setting_row("battery-caution-symbolic", "Battery Saver", "Limit background activity", _make_switch(False)))

    box.append(_section_label("Power"))
    box.append(create_setting_row("preferences-system-time-symbolic", "Screen Timeout",
                                  "Turn off display after",
                                  _string_list_dropdown(["30 seconds", "1 minute", "2 minutes", "5 minutes", "10 minutes", "Never"], 3)))
    box.append(create_setting_row("system-shutdown-symbolic", "Power Button Action",
                                  "When pressing the power button",
                                  _string_list_dropdown(["Suspend", "Shutdown", "Hibernate", "Lock Screen", "Nothing"], 0)))

    box.append(_section_label("Usage (last 24 h)"))
    da = Gtk.DrawingArea()
    da.set_size_request(-1, 180)
    da.add_css_class("chart-area")
    da.set_draw_func(_battery_chart_draw)
    box.append(da)

    return box


def _build_storage_page():
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.add_css_class("settings-page")

    box.append(_section_label("Disk Usage"))
    categories = [
        ("System",  15, "#7C3AED"),
        ("Apps",    28, "#6D28D9"),
        ("Media",   35, "#9F7AEA"),
        ("Documents", 8, "#5B21B6"),
        ("Other",   6, "#3A3354"),
    ]
    total_gb = 256
    used_gb = sum(c[1] for c in categories)
    free_gb = total_gb - used_gb

    overall_lbl = _label(f"{used_gb} GB used of {total_gb} GB  —  {free_gb} GB free", "setting-subtitle")
    overall_lbl.set_margin_bottom(8)
    box.append(overall_lbl)

    for name, gb, _colour in categories:
        frac = gb / total_gb
        row = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        row.add_css_class("setting-row")
        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        top.append(_label(name, "setting-title"))
        size_lbl = _label(f"{gb} GB", "setting-subtitle")
        size_lbl.set_hexpand(False)
        size_lbl.set_xalign(1.0)
        top.append(size_lbl)
        row.append(top)
        bar = Gtk.LevelBar()
        bar.set_min_value(0)
        bar.set_max_value(1.0)
        bar.set_value(frac)
        bar.set_size_request(-1, 8)
        row.append(bar)
        box.append(row)

    box.append(_section_label("Cleanup"))
    trash_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    trash_row.add_css_class("setting-row")
    trash_row.append(_icon("user-trash-full-symbolic", 22))
    tbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    tbox.set_hexpand(True)
    tbox.append(_label("Trash", "setting-title"))
    tbox.append(_label("1.2 GB", "setting-subtitle"))
    trash_row.append(tbox)
    empty_btn = Gtk.Button(label="Empty")
    empty_btn.add_css_class("destructive-action")
    empty_btn.set_valign(Gtk.Align.CENTER)
    trash_row.append(empty_btn)
    box.append(trash_row)

    tmp_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    tmp_row.add_css_class("setting-row")
    tmp_row.append(_icon("edit-clear-all-symbolic", 22))
    tbox2 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    tbox2.set_hexpand(True)
    tbox2.append(_label("Temporary Files", "setting-title"))
    tbox2.append(_label("640 MB — cache and temp data", "setting-subtitle"))
    tmp_row.append(tbox2)
    clean_btn = Gtk.Button(label="Clean Up")
    clean_btn.add_css_class("suggested-action")
    clean_btn.set_valign(Gtk.Align.CENTER)
    tmp_row.append(clean_btn)
    box.append(tmp_row)

    return box


def _build_apps_page():
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.add_css_class("settings-page")

    box.append(_section_label("Installed Applications"))
    apps = [
        ("utilities-terminal-symbolic",   "Terminal",       "1.2 MB"),
        ("web-browser-symbolic",          "Web Browser",    "185 MB"),
        ("text-editor-symbolic",          "Text Editor",    "4.8 MB"),
        ("folder-symbolic",               "Files",          "3.1 MB"),
        ("mail-unread-symbolic",          "Mail",           "12 MB"),
        ("media-playback-start-symbolic", "Media Player",   "22 MB"),
        ("accessories-calculator-symbolic","Calculator",    "0.8 MB"),
        ("preferences-system-symbolic",   "Settings",       "2.4 MB"),
    ]
    for icon_name, name, size in apps:
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.add_css_class("app-row")
        row.append(_icon(icon_name, 24))
        tbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        tbox.set_hexpand(True)
        tbox.append(_label(name, "setting-title"))
        tbox.append(_label(size, "setting-subtitle"))
        row.append(tbox)
        info_btn = Gtk.Button()
        info_btn.set_icon_name("view-more-symbolic")
        info_btn.set_valign(Gtk.Align.CENTER)
        info_btn.set_has_frame(False)
        row.append(info_btn)
        box.append(row)

    box.append(_section_label("Default Applications"))
    defaults = [
        ("web-browser-symbolic",          "Browser",       "Web Browser"),
        ("mail-unread-symbolic",          "Email",         "Mail"),
        ("folder-symbolic",               "File Manager",  "Files"),
        ("utilities-terminal-symbolic",   "Terminal",      "Terminal"),
    ]
    for icon_name, role, current in defaults:
        box.append(create_setting_row(icon_name, role, f"Currently: {current}",
                                      _string_list_dropdown([current, "Other…"], 0)))

    box.append(_section_label("Startup Applications"))
    startup = [
        ("cloud-symbolic",  "Cloud Sync",     True),
        ("mail-unread-symbolic", "Mail Notifier", True),
        ("network-vpn-symbolic", "VPN Client",   False),
    ]
    for icon_name, name, active in startup:
        box.append(create_setting_row(icon_name, name, "Run at login", _make_switch(active)))

    return box


def _build_appearance_page():
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.add_css_class("settings-page")

    box.append(_section_label("Theme"))
    dark_switch = _make_switch(True)
    box.append(create_setting_row("weather-clear-night-symbolic", "Dark Mode", "Use dark colour scheme", dark_switch))

    box.append(_section_label("Accent Colour"))
    colour_box = Gtk.FlowBox()
    colour_box.set_max_children_per_line(8)
    colour_box.set_selection_mode(Gtk.SelectionMode.SINGLE)
    colour_box.set_homogeneous(True)
    colour_box.set_column_spacing(8)
    colour_box.set_row_spacing(8)
    colours = [
        ("#7C3AED", "Purple"),
        ("#2563EB", "Blue"),
        ("#059669", "Green"),
        ("#D97706", "Amber"),
        ("#DC2626", "Red"),
        ("#DB2777", "Pink"),
        ("#0891B2", "Cyan"),
        ("#4B5563", "Grey"),
    ]
    for hex_colour, cname in colours:
        btn = Gtk.Button()
        btn.set_tooltip_text(cname)
        btn.add_css_class("accent-btn")
        btn.set_size_request(36, 36)
        provider = Gtk.CssProvider()
        css = f".accent-btn {{ background-color: {hex_colour}; }}"
        provider.load_from_data(css.encode())
        btn.get_style_context().add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)
        colour_box.append(btn)
    box.append(colour_box)

    box.append(_section_label("Wallpaper"))
    wp_flow = Gtk.FlowBox()
    wp_flow.set_max_children_per_line(4)
    wp_flow.set_selection_mode(Gtk.SelectionMode.SINGLE)
    wp_flow.set_homogeneous(True)
    wp_flow.set_column_spacing(10)
    wp_flow.set_row_spacing(10)
    wallpaper_names = [
        "Aurora", "Mountain", "Ocean", "Galaxy",
        "Forest", "Desert", "City", "Abstract",
    ]
    wp_colours = [
        "#5B21B6", "#1D4ED8", "#047857", "#7E22CE",
        "#15803D", "#B45309", "#1E3A5F", "#6D28D9",
    ]
    for wname, wcolour in zip(wallpaper_names, wp_colours):
        frame = Gtk.Frame()
        overlay = Gtk.Overlay()
        da = Gtk.DrawingArea()
        da.set_size_request(120, 80)
        provider = Gtk.CssProvider()
        css_str = f"drawingarea {{ background-color: {wcolour}; border-radius: 8px; }}"
        provider.load_from_data(css_str.encode())
        da.get_style_context().add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)
        overlay.set_child(da)
        lbl = Gtk.Label(label=wname)
        lbl.set_valign(Gtk.Align.END)
        lbl.set_margin_bottom(6)
        lbl.add_css_class("setting-subtitle")
        overlay.add_overlay(lbl)
        frame.set_child(overlay)
        wp_flow.append(frame)
    box.append(wp_flow)

    browse_btn = Gtk.Button(label="Browse…")
    browse_btn.add_css_class("suggested-action")
    browse_btn.set_halign(Gtk.Align.START)
    browse_btn.set_margin_top(4)
    box.append(browse_btn)

    box.append(_section_label("Icons & Fonts"))
    box.append(create_setting_row("preferences-desktop-theme-symbolic", "Icon Theme",
                                  "Select icon pack",
                                  _string_list_dropdown(["SatasOS Default", "Adwaita", "Papirus", "Numix"], 0)))

    font_btn = Gtk.FontButton()
    font_btn.set_font("Inter 11")
    box.append(create_setting_row("font-x-generic-symbolic", "Font", "System font family and size", font_btn))

    box.append(create_setting_row("input-mouse-symbolic", "Cursor Theme",
                                  "Select cursor style",
                                  _string_list_dropdown(["SatasOS Default", "Adwaita", "Breeze", "DMZ"], 0)))

    return box


def _build_system_page():
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.add_css_class("settings-page")

    box.append(_section_label("Locale"))
    box.append(create_setting_row("preferences-desktop-locale-symbolic", "Language",
                                  "Display language",
                                  _string_list_dropdown(["English (US)", "English (UK)", "Español", "Français", "Deutsch", "日本語", "العربية"], 0)))
    box.append(create_setting_row("mark-location-symbolic", "Region / Timezone",
                                  "Set your timezone",
                                  _string_list_dropdown(["UTC", "America/New_York", "America/Los_Angeles",
                                                          "Europe/London", "Europe/Berlin", "Asia/Tokyo",
                                                          "Asia/Karachi", "Australia/Sydney"], 0)))
    box.append(create_setting_row("input-keyboard-symbolic", "Keyboard Layout",
                                  "Physical keyboard layout",
                                  _string_list_dropdown(["US (QWERTY)", "UK", "Dvorak", "Colemak", "AZERTY"], 0)))

    box.append(_section_label("Date & Time"))
    box.append(create_setting_row("preferences-system-time-symbolic", "Automatic Date & Time",
                                  "Use network time", _make_switch(True)))
    box.append(create_setting_row("preferences-system-time-symbolic", "Time Format",
                                  "12-hour or 24-hour clock",
                                  _string_list_dropdown(["24-hour", "12-hour"], 0)))

    box.append(_section_label("Accessibility"))
    box.append(create_setting_row("preferences-desktop-font-symbolic", "Large Text",
                                  "Increase default text size", _make_switch(False)))
    box.append(create_setting_row("preferences-color-symbolic", "High Contrast",
                                  "Improve readability with higher contrast", _make_switch(False)))
    box.append(create_setting_row("audio-volume-high-symbolic", "Screen Reader",
                                  "Read interface elements aloud", _make_switch(False)))
    box.append(create_setting_row("input-mouse-symbolic", "Sticky Keys",
                                  "Press modifier keys sequentially", _make_switch(False)))

    return box


def _build_about_page():
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
    box.add_css_class("settings-page")
    box.set_halign(Gtk.Align.FILL)

    # Logo / branding
    logo_lbl = Gtk.Label(label="SatasOS")
    logo_lbl.add_css_class("about-logo")
    logo_lbl.set_margin_top(16)
    box.append(logo_lbl)

    ver_lbl = Gtk.Label(label="Version 1.0")
    ver_lbl.add_css_class("about-version")
    ver_lbl.set_margin_bottom(16)
    box.append(ver_lbl)

    # Gather system info
    try:
        uname = os.uname()
        kernel = f"{uname.sysname} {uname.release}"
        hostname = uname.nodename
    except AttributeError:
        kernel = platform.platform()
        hostname = platform.node()

    cpu_model, mem_total = _read_proc_info()

    info_items = [
        ("OS Name",        "SatasOS"),
        ("Version",        "1.0"),
        ("Kernel",         kernel),
        ("Architecture",   platform.machine()),
        ("CPU",            cpu_model),
        ("Memory",         mem_total),
        ("Hostname",       hostname),
    ]

    box.append(_section_label("Device Information"))
    for key, value in info_items:
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.add_css_class("about-info-row")
        row.append(_label(key, "setting-title"))
        val_lbl = _label(value, "setting-subtitle")
        val_lbl.set_xalign(1.0)
        val_lbl.set_hexpand(True)
        row.append(val_lbl)
        box.append(row)

    # Editable hostname
    box.append(_section_label("Edit Hostname"))
    host_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
    host_box.add_css_class("setting-row")
    host_entry = Gtk.Entry()
    host_entry.set_text(hostname)
    host_entry.set_hexpand(True)
    host_box.append(host_entry)
    save_btn = Gtk.Button(label="Save")
    save_btn.add_css_class("suggested-action")
    host_box.append(save_btn)
    box.append(host_box)

    # Legal
    box.append(_section_label("Legal"))
    legal_btn = Gtk.Button(label="Open-Source Licences")
    legal_btn.set_halign(Gtk.Align.START)
    box.append(legal_btn)

    return box


# ===================================================================
# Main Window
# ===================================================================

PAGE_BUILDERS = {
    "Network":    _build_network_page,
    "Display":    _build_display_page,
    "Sound":      _build_sound_page,
    "Battery":    _build_battery_page,
    "Storage":    _build_storage_page,
    "Apps":       _build_apps_page,
    "Appearance": _build_appearance_page,
    "System":     _build_system_page,
    "About":      _build_about_page,
}


class SettingsWindow(Gtk.ApplicationWindow):
    """Main settings window with sidebar + stack layout."""

    def __init__(self, app):
        super().__init__(application=app, title="Settings")
        self.set_default_size(1000, 700)

        # --- Apply CSS -------------------------------------------------
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(SATASOS_CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        # --- Header bar ------------------------------------------------
        header = Gtk.HeaderBar()
        header.set_show_title_buttons(True)
        title_label = Gtk.Label(label="Settings")
        title_label.add_css_class("title")
        header.set_title_widget(title_label)

        self._search_button = Gtk.ToggleButton()
        self._search_button.set_icon_name("edit-find-symbolic")
        self._search_button.connect("toggled", self._on_search_toggled)
        header.pack_end(self._search_button)

        self.set_titlebar(header)

        # --- Root layout ------------------------------------------------
        root_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        root_box.add_css_class("main-box")

        # Search bar
        self._search_bar = Gtk.SearchBar()
        self._search_bar.add_css_class("search-bar")
        self._search_entry = Gtk.SearchEntry()
        self._search_entry.set_hexpand(True)
        self._search_entry.connect("search-changed", self._on_search_changed)
        self._search_bar.set_child(self._search_entry)
        self._search_bar.connect_entry(self._search_entry)
        root_box.append(self._search_bar)

        # Search results overlay
        self._search_results_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self._search_results_box.add_css_class("settings-page")
        self._search_scroll = Gtk.ScrolledWindow()
        self._search_scroll.set_child(self._search_results_box)
        self._search_scroll.set_vexpand(True)
        self._search_scroll.set_visible(False)

        # Paned layout
        self._content_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self._content_box.set_vexpand(True)

        # -- Left sidebar -----------------------------------------------
        sidebar_scroll = Gtk.ScrolledWindow()
        sidebar_scroll.set_size_request(240, -1)
        sidebar_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

        self._sidebar = Gtk.ListBox()
        self._sidebar.add_css_class("category-sidebar")
        self._sidebar.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self._sidebar.connect("row-selected", self._on_category_selected)

        for icon_name, title, subtitle in CATEGORIES:
            row = Gtk.ListBoxRow()
            hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            hbox.append(_icon(icon_name, 20))
            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
            vbox.append(_label(title, "setting-title"))
            vbox.append(_label(subtitle, "setting-subtitle"))
            hbox.append(vbox)
            row.set_child(hbox)
            row._category_name = title
            self._sidebar.append(row)

        sidebar_scroll.set_child(self._sidebar)
        self._content_box.append(sidebar_scroll)

        # Separator
        sep = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        self._content_box.append(sep)

        # -- Right stack -------------------------------------------------
        self._stack = Gtk.Stack()
        self._stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self._stack.set_transition_duration(200)
        self._stack.set_hexpand(True)
        self._stack.set_vexpand(True)

        for _icon_name, title, _subtitle in CATEGORIES:
            page = PAGE_BUILDERS[title]()
            scroll = Gtk.ScrolledWindow()
            scroll.set_child(page)
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            self._stack.add_named(scroll, title)

        self._content_box.append(self._stack)

        # Overlay for search vs normal content
        self._overlay_stack = Gtk.Stack()
        self._overlay_stack.add_named(self._content_box, "main")
        self._overlay_stack.add_named(self._search_scroll, "search")
        self._overlay_stack.set_visible_child_name("main")
        root_box.append(self._overlay_stack)

        self.set_child(root_box)

        # Select first category
        first = self._sidebar.get_row_at_index(0)
        if first:
            self._sidebar.select_row(first)

    # ---- Callbacks ----------------------------------------------------

    def _on_category_selected(self, listbox, row):
        if row is not None:
            name = row._category_name
            self._stack.set_visible_child_name(name)

    def _on_search_toggled(self, btn):
        active = btn.get_active()
        self._search_bar.set_search_mode(active)
        if active:
            self._search_entry.grab_focus()
            self._overlay_stack.set_visible_child_name("search")
        else:
            self._search_entry.set_text("")
            self._overlay_stack.set_visible_child_name("main")

    def _on_search_changed(self, entry):
        query = entry.get_text().strip().lower()
        # Clear previous results
        child = self._search_results_box.get_first_child()
        while child:
            nxt = child.get_next_sibling()
            self._search_results_box.remove(child)
            child = nxt

        if not query:
            self._overlay_stack.set_visible_child_name("main")
            return

        self._overlay_stack.set_visible_child_name("search")

        found = False
        for cat, title, desc in SEARCH_ENTRIES:
            if query in title.lower() or query in desc.lower() or query in cat.lower():
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
                row.add_css_class("search-result-row")
                cat_icon = None
                for ic, c, _s in CATEGORIES:
                    if c == cat:
                        cat_icon = ic
                        break
                if cat_icon:
                    row.append(_icon(cat_icon, 20))
                vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
                vbox.set_hexpand(True)
                vbox.append(_label(title, "setting-title"))
                vbox.append(_label(f"{cat}  ·  {desc}", "setting-subtitle"))
                row.append(vbox)

                # Make clickable
                click = Gtk.GestureClick()
                click.connect("released", self._on_search_result_click, cat)
                row.add_controller(click)

                self._search_results_box.append(row)
                found = True

        if not found:
            self._search_results_box.append(_label("No results found.", "setting-subtitle"))

    def _on_search_result_click(self, gesture, _n, _x, _y, cat):
        """Navigate to category when search result is clicked."""
        self._search_button.set_active(False)
        for i, (_ic, name, _s) in enumerate(CATEGORIES):
            if name == cat:
                row = self._sidebar.get_row_at_index(i)
                if row:
                    self._sidebar.select_row(row)
                break


# ===================================================================
# Application
# ===================================================================

class SatasOSSettings(Gtk.Application):
    """GTK4 Application wrapper."""

    def __init__(self):
        super().__init__(
            application_id="org.satasos.settings",
            flags=Gio.ApplicationFlags.FLAGS_NONE,
        )

    def do_activate(self):
        win = SettingsWindow(self)
        win.present()


def main():
    app = SatasOSSettings()
    app.run(sys.argv)


if __name__ == "__main__":
    main()
