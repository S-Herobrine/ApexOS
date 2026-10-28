#!/usr/bin/env python3
"""
SatasOS Android App Launcher & Intent Bridge
Handles launching Android apps in multi-window mode and routing intents.
"""

import sys
import subprocess
import shutil

def check_waydroid_status():
    res = subprocess.run(["waydroid", "status"], capture_output=True, text=True)
    return "RUNNING" in res.stdout

def start_waydroid_session():
    if not check_waydroid_status():
        subprocess.Popen(["waydroid", "session", "start"])

def launch_app(package_name):
    start_waydroid_session()
    cmd = ["waydroid", "app", "launch", package_name]
    subprocess.Popen(cmd)

def install_apk(apk_path):
    cmd = ["waydroid", "app", "install", apk_path]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode == 0

def main():
    if len(sys.argv) < 2:
        print("Usage: waydroid-launcher.py <package_name|file.apk>")
        sys.exit(1)

    target = sys.argv[1]
    if target.endswith(".apk"):
        print(f"Installing APK: {target}")
        if install_apk(target):
            print("APK installed successfully.")
        else:
            print("Failed to install APK.")
    else:
        print(f"Launching Android application: {target}")
        launch_app(target)

if __name__ == "__main__":
    main()
