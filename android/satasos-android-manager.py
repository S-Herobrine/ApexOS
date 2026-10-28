#!/usr/bin/env python3
"""
SatasOS Android Subsystem Manager
Graphical management tool for Waydroid container, Google Play Store, and Android Apps.
"""

import sys
import subprocess
import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib, Gio

class SatasOSAndroidManager(Adw.Application):
    def __init__(self):
        super().__init__(
            application_id='org.satasos.androidmanager',
            flags=Gio.ApplicationFlags.FLAGS_NONE
        )

    def do_activate(self):
        win = self.props.active_window
        if not win:
            win = AndroidManagerWindow(application=self)
        win.present()

class AndroidManagerWindow(Gtk.ApplicationWindow):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.set_title("SatasOS Android Subsystem Manager")
        self.set_default_size(750, 520)

        # Main Layout
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        main_box.set_margin_top(16)
        main_box.set_margin_bottom(16)
        main_box.set_margin_start(16)
        main_box.set_margin_end(16)
        self.set_child(main_box)

        # Header card
        header_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
        header_card.add_css_class("card")
        header_card.set_margin_bottom(8)

        icon = Gtk.Image.new_from_icon_name("android")
        icon.set_pixel_size(48)
        header_card.append(icon)

        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        title_lbl = Gtk.Label(label="Android Subsystem & Google Play Services")
        title_lbl.set_halign(Gtk.Align.START)
        title_lbl.add_css_class("title-2")
        title_box.append(title_lbl)

        status_lbl = Gtk.Label(label="Powered by Waydroid Container Architecture (Android 13/14)")
        status_lbl.set_halign(Gtk.Align.START)
        status_lbl.add_css_class("dim-label")
        title_box.append(status_lbl)
        header_card.append(title_box)

        main_box.append(header_card)

        # Controls list
        action_list = Gtk.ListBox()
        action_list.add_css_class("boxed-list")

        # 1. Start Subsystem
        row1 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row1.set_margin_top(12)
        row1.set_margin_bottom(12)
        row1.set_margin_start(12)
        row1.set_margin_end(12)
        lbl1 = Gtk.Label(label="Android Container Status")
        lbl1.set_hexpand(True)
        lbl1.set_halign(Gtk.Align.START)
        row1.append(lbl1)

        self.btn_toggle = Gtk.Button(label="Start Subsystem")
        self.btn_toggle.add_css_class("suggested-action")
        self.btn_toggle.connect("clicked", self.on_toggle_subsystem)
        row1.append(self.btn_toggle)
        action_list.append(row1)

        # 2. Launch Google Play Store
        row2 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row2.set_margin_top(12)
        row2.set_margin_bottom(12)
        row2.set_margin_start(12)
        row2.set_margin_end(12)
        lbl2 = Gtk.Label(label="Google Play Store")
        lbl2.set_hexpand(True)
        lbl2.set_halign(Gtk.Align.START)
        row2.append(lbl2)

        btn_play = Gtk.Button(label="Open Play Store")
        btn_play.connect("clicked", self.on_open_playstore)
        row2.append(btn_play)
        action_list.append(row2)

        # 3. Install APK
        row3 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row3.set_margin_top(12)
        row3.set_margin_bottom(12)
        row3.set_margin_start(12)
        row3.set_margin_end(12)
        lbl3 = Gtk.Label(label="Sideload Android Application (.apk)")
        lbl3.set_hexpand(True)
        lbl3.set_halign(Gtk.Align.START)
        row3.append(lbl3)

        btn_apk = Gtk.Button(label="Choose & Install APK")
        btn_apk.connect("clicked", self.on_choose_apk)
        row3.append(btn_apk)
        action_list.append(row3)

        # 4. Multi-window Mode
        row4 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row4.set_margin_top(12)
        row4.set_margin_bottom(12)
        row4.set_margin_start(12)
        row4.set_margin_end(12)
        lbl4 = Gtk.Label(label="Multi-Window Desktop Mode")
        lbl4.set_hexpand(True)
        lbl4.set_halign(Gtk.Align.START)
        row4.append(lbl4)

        sw_multi = Gtk.Switch()
        sw_multi.set_active(True)
        row4.append(sw_multi)
        action_list.append(row4)

        main_box.append(action_list)

        # Log or info view
        self.info_lbl = Gtk.Label(label="Status: Ready. SatasOS Android Bridge active.")
        self.info_lbl.set_halign(Gtk.Align.START)
        main_box.append(self.info_lbl)

    def on_toggle_subsystem(self, button):
        try:
            subprocess.Popen(["waydroid", "session", "start"])
            self.info_lbl.set_label("Status: Waydroid session starting...")
        except Exception as e:
            self.info_lbl.set_label(f"Status error: {str(e)}")

    def on_open_playstore(self, button):
        try:
            subprocess.Popen(["waydroid", "app", "launch", "com.android.vending"])
            self.info_lbl.set_label("Status: Opening Google Play Store...")
        except Exception as e:
            self.info_lbl.set_label(f"Status error: {str(e)}")

    def on_choose_apk(self, button):
        # Open file chooser dialog
        dialog = Gtk.FileDialog()
        dialog.set_title("Select Android APK File")
        filter_apk = Gtk.FileFilter()
        filter_apk.set_name("Android Package (*.apk)")
        filter_apk.add_pattern("*.apk")
        filters = Gio.ListStore.new(Gtk.FileFilter)
        filters.append(filter_apk)
        dialog.set_filters(filters)

        dialog.open(self, None, self.on_apk_selected)

    def on_apk_selected(self, dialog, result):
        try:
            file = dialog.open_finish(result)
            if file:
                path = file.get_path()
                self.info_lbl.set_label(f"Installing {path}...")
                subprocess.Popen(["waydroid", "app", "install", path])
        except Exception as e:
            self.info_lbl.set_label(f"Selection cancelled or error: {str(e)}")

if __name__ == '__main__':
    app = SatasOSAndroidManager()
    sys.exit(app.run(sys.argv))
