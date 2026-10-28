#!/bin/bash
# ==============================================================================
# ApexOS System-Wide Dark / Light Theme Switcher
# ==============================================================================

CURRENT=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "'prefer-dark'")

if [ "$CURRENT" = "'prefer-dark'" ]; then
    echo "Switching to ApexOS Light Mode..."
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    gsettings set org.gnome.desktop.interface gtk-theme 'ApexOS-Light'
    gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/apexos/apexos-default-light.svg'
    notify-send "ApexOS Theme" "Switched to Light Mode" -i weather-clear
else
    echo "Switching to ApexOS Dark Mode..."
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme 'ApexOS-Dark'
    gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/apexos/apexos-default-dark.svg'
    notify-send "ApexOS Theme" "Switched to Dark Mode" -i weather-clear-night
fi
