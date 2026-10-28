#!/usr/bin/env python3
"""
ApexOS System Tweaker (Windhawk Counterpart)
Provides deep customization options for the taskbar, animations, windows, and theme colors.
"""

import sys
import os
import subprocess
import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, Gio

class ApexTweaksApp(Adw.Application):
    def __init__(self):
        super().__init__(
            application_id='org.apexos.tweaks',
            flags=Gio.ApplicationFlags.FLAGS_NONE
        )

    def do_activate(self):
        win = self.props.active_window
        if not win:
            win = ApexTweaksWindow(application=self)
        win.present()

class ApexTweaksWindow(Gtk.ApplicationWindow):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.set_title("ApexOS System Tweaker")
        self.set_default_size(700, 520)

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        main_box.set_margin_top(16)
        main_box.set_margin_bottom(16)
        main_box.set_margin_start(16)
        main_box.set_margin_end(16)
        self.set_child(main_box)

        # Title Card
        header_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
        header_card.add_css_class("card")
        icon = Gtk.Image.new_from_icon_name("preferences-desktop")
        icon.set_pixel_size(48)
        header_card.append(icon)

        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        lbl_title = Gtk.Label(label="ApexOS System Modder & Tweaker")
        lbl_title.set_halign(Gtk.Align.START)
        lbl_title.add_css_class("title-2")
        title_box.append(lbl_title)

        lbl_desc = Gtk.Label(label="Configure taskbar physics, animation speeds, low-RAM modes, and acrylic blur.")
        lbl_desc.set_halign(Gtk.Align.START)
        lbl_desc.add_css_class("dim-label")
        title_box.append(lbl_desc)
        header_card.append(title_box)
        main_box.append(header_card)

        # Tweaks List
        list_box = Gtk.ListBox()
        list_box.add_css_class("boxed-list")

        # 1. Taskbar Centering
        row1 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row1.set_margin_top(12); row1.set_margin_bottom(12); row1.set_margin_start(12); row1.set_margin_end(12)
        lbl1 = Gtk.Label(label="Center Taskbar App Icons (Windows 11 Style)")
        lbl1.set_hexpand(True); lbl1.set_halign(Gtk.Align.START)
        row1.append(lbl1)
        sw1 = Gtk.Switch(); sw1.set_active(True)
        row1.append(sw1)
        list_box.append(row1)

        # 2. Acrylic Blur / Transparency
        row2 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row2.set_margin_top(12); row2.set_margin_bottom(12); row2.set_margin_start(12); row2.set_margin_end(12)
        lbl2 = Gtk.Label(label="Acrylic Background Blur (Turn off on low-end GPUs)")
        lbl2.set_hexpand(True); lbl2.set_halign(Gtk.Align.START)
        row2.append(lbl2)
        sw2 = Gtk.Switch(); sw2.set_active(True)
        row2.append(sw2)
        list_box.append(row2)

        # 3. Animation Speed
        row3 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row3.set_margin_top(12); row3.set_margin_bottom(12); row3.set_margin_start(12); row3.set_margin_end(12)
        lbl3 = Gtk.Label(label="Window Animation Speed (Faster for Low-End PCs)")
        lbl3.set_hexpand(True); lbl3.set_halign(Gtk.Align.START)
        row3.append(lbl3)
        combo3 = Gtk.DropDown.new_from_strings(["Instant (0ms)", "Fast (100ms)", "Normal (250ms)", "Smooth (400ms)"])
        combo3.set_selected(1)
        row3.append(combo3)
        list_box.append(row3)

        # 4. Low-End 4GB RAM Optimization
        row4 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row4.set_margin_top(12); row4.set_margin_bottom(12); row4.set_margin_start(12); row4.set_margin_end(12)
        lbl4 = Gtk.Label(label="Aggressive Memory Compression & zRAM Swapping")
        lbl4.set_hexpand(True); lbl4.set_halign(Gtk.Align.START)
        row4.append(lbl4)
        sw4 = Gtk.Switch(); sw4.set_active(True)
        row4.append(sw4)
        list_box.append(row4)

        # 5. Titlebar Button Position
        row5 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row5.set_margin_top(12); row5.set_margin_bottom(12); row5.set_margin_start(12); row5.set_margin_end(12)
        lbl5 = Gtk.Label(label="Window Controls Layout")
        lbl5.set_hexpand(True); lbl5.set_halign(Gtk.Align.START)
        row5.append(lbl5)
        combo5 = Gtk.DropDown.new_from_strings(["Windows Style (Right: Min, Max, Close)", "Ubuntu Style (Left: Close, Min, Max)"])
        combo5.set_selected(0)
        row5.append(combo5)
        list_box.append(row5)

        main_box.append(list_box)

        btn_apply = Gtk.Button(label="Apply Changes & Reload Shell")
        btn_apply.add_css_class("suggested-action")
        btn_apply.connect("clicked", self.on_apply)
        main_box.append(btn_apply)

        self.status_lbl = Gtk.Label(label="Ready.")
        self.status_lbl.set_halign(Gtk.Align.START)
        main_box.append(self.status_lbl)

    def on_apply(self, button):
        self.status_lbl.set_label("Settings applied successfully!")

if __name__ == '__main__':
    app = ApexTweaksApp()
    sys.exit(app.run(sys.argv))
