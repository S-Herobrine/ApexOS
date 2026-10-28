// SatasOS Lock Screen - Android-style lock screen for GNOME Shell
// Full GJS implementation using GNOME Shell APIs (GNOME 45+ ESM)

import St from 'gi://St';
import Clutter from 'gi://Clutter';
import Shell from 'gi://Shell';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import GnomeDesktop from 'gi://GnomeDesktop';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const BRAND_PRIMARY = '#7C3AED';
const BRAND_HOVER = '#6D28D9';
const BRAND_ACTIVE = '#5B21B6';
const BRAND_DARK_BG = '#1E1B2E';
const BRAND_DARK_SURFACE = '#2D2640';
const BRAND_LIGHT_TEXT = '#E8E0F0';

const CORRECT_PIN = '1234';
const MAX_PIN_LENGTH = 6;
const MIN_PIN_LENGTH = 4;
const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_DURATION_SECS = 30;
const IDLE_LOCK_TIMEOUT_SECS = 300;

const PinDotsWidget = GObject.registerClass(
class PinDotsWidget extends St.BoxLayout {
    _init() {
        super._init({
            style_class: 'pin-dots-container',
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            style: 'spacing: 16px; padding: 20px 0;',
        });
        this._dots = [];
        this._enteredCount = 0;
        for (let i = 0; i < MAX_PIN_LENGTH; i++) {
            const dot = new St.Widget({
                style: `width: 16px; height: 16px; border-radius: 8px;
                        border: 2px solid ${BRAND_LIGHT_TEXT};
                        background-color: transparent;`,
                x_align: Clutter.ActorAlign.CENTER,
                y_align: Clutter.ActorAlign.CENTER,
            });
            this._dots.push(dot);
            this.add_child(dot);
        }
    }

    updateDots(count) {
        this._enteredCount = count;
        for (let i = 0; i < MAX_PIN_LENGTH; i++) {
            if (i < count) {
                this._dots[i].set_style(
                    `width: 16px; height: 16px; border-radius: 8px;
                     border: 2px solid ${BRAND_PRIMARY};
                     background-color: ${BRAND_PRIMARY};`
                );
            } else {
                this._dots[i].set_style(
                    `width: 16px; height: 16px; border-radius: 8px;
                     border: 2px solid ${BRAND_LIGHT_TEXT};
                     background-color: transparent;`
                );
            }
        }
    }

    shakeAnimation() {
        this.save_easing_state();
        this.set_easing_duration(80);
        this.set_easing_mode(Clutter.AnimationMode.EASE_IN_OUT_SINE);
        this.set_translation(20, 0, 0);
        this.restore_easing_state();

        let step = 0;
        const shakeOffsets = [20, -20, 15, -15, 10, -10, 5, -5, 0];
        const shakeTimer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 80, () => {
            step++;
            if (step >= shakeOffsets.length) {
                this.set_translation(0, 0, 0);
                return GLib.SOURCE_REMOVE;
            }
            this.set_translation(shakeOffsets[step], 0, 0);
            return GLib.SOURCE_CONTINUE;
        });
        return shakeTimer;
    }

    resetDots() {
        this.updateDots(0);
    }
});

const NumberPadButton = GObject.registerClass(
class NumberPadButton extends St.Button {
    _init(label, callback) {
        super._init({
            style_class: 'numpad-button',
            style: `width: 80px; height: 80px; border-radius: 40px;
                    background-color: ${BRAND_DARK_SURFACE};
                    color: ${BRAND_LIGHT_TEXT}; font-size: 28px;
                    font-weight: 600; text-align: center;
                    border: 1px solid rgba(124, 58, 237, 0.3);
                    margin: 8px;`,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
        });

        if (label === '⌫') {
            this.set_child(new St.Icon({
                icon_name: 'edit-clear-symbolic',
                icon_size: 24,
                style: `color: ${BRAND_LIGHT_TEXT};`,
            }));
        } else if (label === '✓') {
            this.set_child(new St.Icon({
                icon_name: 'object-select-symbolic',
                icon_size: 24,
                style: `color: ${BRAND_PRIMARY};`,
            }));
        } else {
            this.set_label(label);
        }

        this.connect('clicked', () => {
            this._animatePress();
            callback(label);
        });

        this.connect('enter-event', () => {
            this.set_style(
                `width: 80px; height: 80px; border-radius: 40px;
                 background-color: ${BRAND_HOVER};
                 color: ${BRAND_LIGHT_TEXT}; font-size: 28px;
                 font-weight: 600; text-align: center;
                 border: 1px solid rgba(124, 58, 237, 0.6);
                 margin: 8px;`
            );
        });

        this.connect('leave-event', () => {
            this.set_style(
                `width: 80px; height: 80px; border-radius: 40px;
                 background-color: ${BRAND_DARK_SURFACE};
                 color: ${BRAND_LIGHT_TEXT}; font-size: 28px;
                 font-weight: 600; text-align: center;
                 border: 1px solid rgba(124, 58, 237, 0.3);
                 margin: 8px;`
            );
        });
    }

    _animatePress() {
        this.save_easing_state();
        this.set_easing_duration(100);
        this.set_easing_mode(Clutter.AnimationMode.EASE_OUT_QUAD);
        this.set_scale(0.9, 0.9);
        this.restore_easing_state();

        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
            this.save_easing_state();
            this.set_easing_duration(100);
            this.set_easing_mode(Clutter.AnimationMode.EASE_OUT_QUAD);
            this.set_scale(1.0, 1.0);
            this.restore_easing_state();
            return GLib.SOURCE_REMOVE;
        });
    }
});

const LockScreen = GObject.registerClass(
class LockScreen extends St.Widget {
    _init() {
        const monitor = Main.layoutManager.primaryMonitor;
        super._init({
            reactive: true,
            can_focus: true,
            x: monitor.x,
            y: monitor.y,
            width: monitor.width,
            height: monitor.height,
            style: `background-color: ${BRAND_DARK_BG};`,
        });

        this._enteredPin = '';
        this._failedAttempts = 0;
        this._isLockedOut = false;
        this._lockoutTimerId = 0;
        this._lockoutRemaining = 0;
        this._clockTimerId = 0;
        this._pinPadRevealed = false;
        this._dragStartY = 0;
        this._isLocked = false;
        this._idleWatchId = 0;
        this._shakeTimerId = 0;
        this._keyBindingId = 0;
        this._lidSignalId = 0;
        this._inputBlocker = null;

        this._buildBackground();
        this._buildClockDisplay();
        this._buildDateDisplay();
        this._buildWeatherInfo();
        this._buildNotificationSummary();
        this._buildPinEntry();
        this._buildSwipeIndicator();
        this._buildQuickAccessShortcuts();
        this._buildStatusText();
        this._setupInputCapture();
    }

    _buildBackground() {
        this._bgWidget = new St.Widget({
            x: 0, y: 0,
            width: this.width,
            height: this.height,
            style: `background-color: ${BRAND_DARK_BG};
                    background-image: url("resource:///org/gnome/shell/theme/noise-texture.png");
                    background-size: cover;`,
        });

        try {
            const blurEffect = new Shell.BlurEffect({
                brightness: 0.55,
                sigma: 40,
                mode: Shell.BlurMode.BACKGROUND,
            });
            this._bgWidget.add_effect_with_name('blur', blurEffect);
        } catch (_e) {
            try {
                const clutterBlur = new Clutter.BlurEffect();
                this._bgWidget.add_effect_with_name('blur', clutterBlur);
            } catch (_e2) {
                // Blur unavailable; solid background is fine
            }
        }

        this.add_child(this._bgWidget);

        this._overlay = new St.Widget({
            x: 0, y: 0,
            width: this.width,
            height: this.height,
            style: `background-color: rgba(30, 27, 46, 0.75);`,
        });
        this.add_child(this._overlay);
    }

    _buildClockDisplay() {
        this._clockLabel = new St.Label({
            style: `color: ${BRAND_LIGHT_TEXT}; font-size: 96px;
                    font-weight: 200; letter-spacing: 4px;
                    text-shadow: 0 2px 8px rgba(0,0,0,0.4);`,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            x_expand: true,
        });
        this._clockLabel.set_position(
            (this.width - 400) / 2,
            this.height * 0.15
        );
        this._clockLabel.set_size(400, 120);
        this._clockLabel.clutter_text.set_line_alignment(0);
        this._updateClock();
        this.add_child(this._clockLabel);

        this._clockTimerId = GLib.timeout_add_seconds(
            GLib.PRIORITY_DEFAULT, 1, () => {
                this._updateClock();
                return GLib.SOURCE_CONTINUE;
            }
        );
    }

    _updateClock() {
        const now = GLib.DateTime.new_now_local();
        const hours = now.get_hour().toString().padStart(2, '0');
        const minutes = now.get_minute().toString().padStart(2, '0');
        this._clockLabel.set_text(`${hours}:${minutes}`);
        if (this._dateLabel) {
            this._updateDate(now);
        }
    }

    _buildDateDisplay() {
        this._dateLabel = new St.Label({
            style: `color: rgba(232, 224, 240, 0.8); font-size: 22px;
                    font-weight: 400; letter-spacing: 1px;`,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            x_expand: true,
        });
        this._dateLabel.set_position(
            (this.width - 400) / 2,
            this.height * 0.15 + 120
        );
        this._dateLabel.set_size(400, 36);
        const now = GLib.DateTime.new_now_local();
        this._updateDate(now);
        this.add_child(this._dateLabel);
    }

    _updateDate(dateTime) {
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        const months = ['January', 'February', 'March', 'April', 'May', 'June',
                        'July', 'August', 'September', 'October', 'November', 'December'];
        const dayName = days[dateTime.get_day_of_week() % 7];
        const monthName = months[dateTime.get_month() - 1];
        const dayNum = dateTime.get_day_of_month();
        this._dateLabel.set_text(`${dayName}, ${monthName} ${dayNum}`);
    }

    _buildWeatherInfo() {
        this._weatherBox = new St.BoxLayout({
            style: `padding: 12px 20px; border-radius: 16px;
                    background-color: rgba(45, 38, 64, 0.6);
                    margin-top: 12px;`,
            x_align: Clutter.ActorAlign.CENTER,
            vertical: false,
        });
        this._weatherBox.set_position(
            (this.width - 220) / 2,
            this.height * 0.15 + 168
        );
        this._weatherBox.set_size(220, 48);

        const weatherIcon = new St.Icon({
            icon_name: 'weather-clear-symbolic',
            icon_size: 22,
            style: `color: ${BRAND_LIGHT_TEXT}; margin-right: 10px;`,
        });
        this._weatherBox.add_child(weatherIcon);

        const weatherText = new St.Label({
            text: '72°F  Sunny',
            style: `color: ${BRAND_LIGHT_TEXT}; font-size: 16px;
                    font-weight: 400;`,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._weatherBox.add_child(weatherText);
        this.add_child(this._weatherBox);
    }

    _buildNotificationSummary() {
        this._notifBox = new St.BoxLayout({
            style: `padding: 8px 16px; border-radius: 12px;
                    background-color: rgba(45, 38, 64, 0.5);
                    margin-top: 8px;`,
            x_align: Clutter.ActorAlign.CENTER,
            vertical: false,
        });
        this._notifBox.set_position(
            (this.width - 200) / 2,
            this.height * 0.15 + 228
        );
        this._notifBox.set_size(200, 40);

        const notifIcon = new St.Icon({
            icon_name: 'preferences-system-notifications-symbolic',
            icon_size: 18,
            style: `color: ${BRAND_LIGHT_TEXT}; margin-right: 8px;`,
        });
        this._notifBox.add_child(notifIcon);

        this._notifCountLabel = new St.Label({
            text: '3 notifications',
            style: `color: rgba(232, 224, 240, 0.7); font-size: 14px;`,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._notifBox.add_child(this._notifCountLabel);

        const notifBadge = new St.Label({
            text: '3',
            style: `background-color: ${BRAND_PRIMARY}; color: white;
                    font-size: 11px; font-weight: 700;
                    border-radius: 10px; padding: 2px 7px;
                    margin-left: 8px; min-width: 20px; text-align: center;`,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._notifBox.add_child(notifBadge);
        this.add_child(this._notifBox);

        this._updateNotificationCount();
    }

    _updateNotificationCount() {
        try {
            const sources = Main.messageTray.getSources();
            const count = sources.length;
            this._notifCountLabel.set_text(
                count === 0 ? 'No notifications' :
                count === 1 ? '1 notification' :
                `${count} notifications`
            );
        } catch (_e) {
            this._notifCountLabel.set_text('3 notifications');
        }
    }

    _buildPinEntry() {
        this._pinContainer = new St.BoxLayout({
            vertical: true,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            style: `padding: 24px; border-radius: 24px;
                    background-color: rgba(30, 27, 46, 0.9);`,
            opacity: 0,
            reactive: true,
        });
        this._pinContainer.set_position(
            (this.width - 320) / 2,
            this.height * 0.38
        );
        this._pinContainer.set_size(320, 500);

        const pinTitle = new St.Label({
            text: 'Enter PIN',
            style: `color: ${BRAND_LIGHT_TEXT}; font-size: 20px;
                    font-weight: 500; margin-bottom: 8px;`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._pinContainer.add_child(pinTitle);

        this._pinDots = new PinDotsWidget();
        this._pinContainer.add_child(this._pinDots);

        this._pinStatusLabel = new St.Label({
            text: '',
            style: `color: #EF4444; font-size: 13px; margin-bottom: 8px;
                    min-height: 20px;`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._pinContainer.add_child(this._pinStatusLabel);

        const padLayout = [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['⌫', '0', '✓'],
        ];

        for (const row of padLayout) {
            const rowBox = new St.BoxLayout({
                x_align: Clutter.ActorAlign.CENTER,
                style: 'spacing: 4px;',
            });
            for (const key of row) {
                const btn = new NumberPadButton(key, (k) => this._onPadKey(k));
                rowBox.add_child(btn);
            }
            this._pinContainer.add_child(rowBox);
        }

        this.add_child(this._pinContainer);
    }

    _onPadKey(key) {
        if (this._isLockedOut) return;

        if (key === '⌫') {
            if (this._enteredPin.length > 0) {
                this._enteredPin = this._enteredPin.slice(0, -1);
                this._pinDots.updateDots(this._enteredPin.length);
            }
        } else if (key === '✓') {
            if (this._enteredPin.length >= MIN_PIN_LENGTH) {
                this._verifyPin();
            }
        } else {
            if (this._enteredPin.length < MAX_PIN_LENGTH) {
                this._enteredPin += key;
                this._pinDots.updateDots(this._enteredPin.length);
                if (this._enteredPin.length === MAX_PIN_LENGTH) {
                    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
                        this._verifyPin();
                        return GLib.SOURCE_REMOVE;
                    });
                }
            }
        }
    }

    _verifyPin() {
        if (this._enteredPin === CORRECT_PIN) {
            this._pinStatusLabel.set_text('');
            this._failedAttempts = 0;
            this.unlock();
        } else {
            this._failedAttempts++;
            this._pinStatusLabel.set_text('Wrong PIN');
            this._shakeTimerId = this._pinDots.shakeAnimation();

            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 600, () => {
                this._enteredPin = '';
                this._pinDots.resetDots();
                return GLib.SOURCE_REMOVE;
            });

            if (this._failedAttempts >= MAX_FAILED_ATTEMPTS) {
                this._triggerLockout();
            }
        }
    }

    _triggerLockout() {
        this._isLockedOut = true;
        this._lockoutRemaining = LOCKOUT_DURATION_SECS;
        this._pinStatusLabel.set_text(
            `Too many attempts. Try again in ${this._lockoutRemaining}s`
        );

        this._lockoutTimerId = GLib.timeout_add_seconds(
            GLib.PRIORITY_DEFAULT, 1, () => {
                this._lockoutRemaining--;
                if (this._lockoutRemaining <= 0) {
                    this._isLockedOut = false;
                    this._failedAttempts = 0;
                    this._pinStatusLabel.set_text('');
                    this._lockoutTimerId = 0;
                    return GLib.SOURCE_REMOVE;
                }
                this._pinStatusLabel.set_text(
                    `Too many attempts. Try again in ${this._lockoutRemaining}s`
                );
                return GLib.SOURCE_CONTINUE;
            }
        );
    }

    _buildSwipeIndicator() {
        this._swipeBox = new St.BoxLayout({
            vertical: true,
            x_align: Clutter.ActorAlign.CENTER,
            style: 'spacing: 8px;',
        });
        this._swipeBox.set_position(
            (this.width - 200) / 2,
            this.height - 120
        );
        this._swipeBox.set_size(200, 100);

        const arrowIcon = new St.Icon({
            icon_name: 'pan-up-symbolic',
            icon_size: 28,
            style: `color: rgba(232, 224, 240, 0.6);`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._swipeBox.add_child(arrowIcon);

        const swipeLabel = new St.Label({
            text: 'Swipe up to unlock',
            style: `color: rgba(232, 224, 240, 0.5); font-size: 14px;
                    font-weight: 400; letter-spacing: 0.5px;`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._swipeBox.add_child(swipeLabel);

        this._pulseArrow(arrowIcon);
        this.add_child(this._swipeBox);

        this._dragHandle = new St.Widget({
            reactive: true,
            style: `width: 48px; height: 6px; border-radius: 3px;
                    background-color: rgba(232, 224, 240, 0.4);`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._dragHandle.set_position(
            (this.width - 48) / 2,
            this.height - 28
        );
        this._dragHandle.set_size(48, 6);

        const dragAction = new Clutter.DragAction();
        dragAction.set_drag_axis(Clutter.DragAxis.Y_AXIS);
        dragAction.connect('drag-begin', (_action, _actor, _eventX, eventY) => {
            this._dragStartY = eventY;
        });
        dragAction.connect('drag-end', (_action, _actor, _eventX, eventY) => {
            const delta = this._dragStartY - eventY;
            if (delta > this.height * 0.25) {
                this._revealPinPad();
            }
        });
        this._dragHandle.add_action(dragAction);
        this.add_child(this._dragHandle);
    }

    _pulseArrow(icon) {
        const pulse = () => {
            icon.save_easing_state();
            icon.set_easing_duration(1200);
            icon.set_easing_mode(Clutter.AnimationMode.EASE_IN_OUT_SINE);
            icon.set_opacity(100);
            icon.restore_easing_state();

            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1200, () => {
                icon.save_easing_state();
                icon.set_easing_duration(1200);
                icon.set_easing_mode(Clutter.AnimationMode.EASE_IN_OUT_SINE);
                icon.set_opacity(200);
                icon.restore_easing_state();

                GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1200, () => {
                    if (this._isLocked) pulse();
                    return GLib.SOURCE_REMOVE;
                });
                return GLib.SOURCE_REMOVE;
            });
        };
        pulse();
    }

    _revealPinPad() {
        if (this._pinPadRevealed) return;
        this._pinPadRevealed = true;

        this._swipeBox.save_easing_state();
        this._swipeBox.set_easing_duration(300);
        this._swipeBox.set_easing_mode(Clutter.AnimationMode.EASE_OUT_QUAD);
        this._swipeBox.set_opacity(0);
        this._swipeBox.restore_easing_state();

        this._dragHandle.save_easing_state();
        this._dragHandle.set_easing_duration(300);
        this._dragHandle.set_opacity(0);
        this._dragHandle.restore_easing_state();

        this._weatherBox.save_easing_state();
        this._weatherBox.set_easing_duration(300);
        this._weatherBox.set_opacity(0);
        this._weatherBox.restore_easing_state();

        this._notifBox.save_easing_state();
        this._notifBox.set_easing_duration(300);
        this._notifBox.set_opacity(0);
        this._notifBox.restore_easing_state();

        this._clockLabel.save_easing_state();
        this._clockLabel.set_easing_duration(400);
        this._clockLabel.set_easing_mode(Clutter.AnimationMode.EASE_OUT_QUAD);
        this._clockLabel.set_position(
            this._clockLabel.x,
            this.height * 0.06
        );
        this._clockLabel.set_style(
            `color: ${BRAND_LIGHT_TEXT}; font-size: 56px;
             font-weight: 200; letter-spacing: 2px;
             text-shadow: 0 2px 8px rgba(0,0,0,0.4);`
        );
        this._clockLabel.restore_easing_state();

        this._dateLabel.save_easing_state();
        this._dateLabel.set_easing_duration(400);
        this._dateLabel.set_position(
            this._dateLabel.x,
            this.height * 0.06 + 72
        );
        this._dateLabel.set_style(
            `color: rgba(232, 224, 240, 0.8); font-size: 16px;
             font-weight: 400; letter-spacing: 1px;`
        );
        this._dateLabel.restore_easing_state();

        this._pinContainer.save_easing_state();
        this._pinContainer.set_easing_duration(400);
        this._pinContainer.set_easing_mode(Clutter.AnimationMode.EASE_OUT_QUAD);
        this._pinContainer.set_opacity(255);
        this._pinContainer.set_translation(0, 0, 0);
        this._pinContainer.restore_easing_state();
    }

    _hidePinPad() {
        if (!this._pinPadRevealed) return;
        this._pinPadRevealed = false;

        this._pinContainer.save_easing_state();
        this._pinContainer.set_easing_duration(300);
        this._pinContainer.set_opacity(0);
        this._pinContainer.restore_easing_state();

        this._swipeBox.save_easing_state();
        this._swipeBox.set_easing_duration(400);
        this._swipeBox.set_opacity(255);
        this._swipeBox.restore_easing_state();

        this._dragHandle.save_easing_state();
        this._dragHandle.set_easing_duration(400);
        this._dragHandle.set_opacity(255);
        this._dragHandle.restore_easing_state();

        this._weatherBox.save_easing_state();
        this._weatherBox.set_easing_duration(400);
        this._weatherBox.set_opacity(255);
        this._weatherBox.restore_easing_state();

        this._notifBox.save_easing_state();
        this._notifBox.set_easing_duration(400);
        this._notifBox.set_opacity(255);
        this._notifBox.restore_easing_state();

        this._clockLabel.save_easing_state();
        this._clockLabel.set_easing_duration(400);
        this._clockLabel.set_position(
            this._clockLabel.x,
            this.height * 0.15
        );
        this._clockLabel.set_style(
            `color: ${BRAND_LIGHT_TEXT}; font-size: 96px;
             font-weight: 200; letter-spacing: 4px;
             text-shadow: 0 2px 8px rgba(0,0,0,0.4);`
        );
        this._clockLabel.restore_easing_state();

        this._dateLabel.save_easing_state();
        this._dateLabel.set_easing_duration(400);
        this._dateLabel.set_position(
            this._dateLabel.x,
            this.height * 0.15 + 120
        );
        this._dateLabel.set_style(
            `color: rgba(232, 224, 240, 0.8); font-size: 22px;
             font-weight: 400; letter-spacing: 1px;`
        );
        this._dateLabel.restore_easing_state();

        this._enteredPin = '';
        this._pinDots.resetDots();
        this._pinStatusLabel.set_text('');
    }

    _buildQuickAccessShortcuts() {
        const cameraBtn = new St.Button({
            style: `width: 52px; height: 52px; border-radius: 26px;
                    background-color: rgba(45, 38, 64, 0.5);
                    border: 1px solid rgba(124, 58, 237, 0.2);`,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
        });
        cameraBtn.set_child(new St.Icon({
            icon_name: 'camera-photo-symbolic',
            icon_size: 22,
            style: `color: ${BRAND_LIGHT_TEXT};`,
        }));
        cameraBtn.set_position(32, this.height - 72);
        cameraBtn.connect('clicked', () => {
            try {
                const appInfo = Gio.AppInfo.create_from_commandline(
                    'gnome-camera', 'Camera',
                    Gio.AppInfoCreateFlags.NONE
                );
                appInfo.launch([], null);
            } catch (_e) {
                try {
                    const appInfo = Gio.AppInfo.create_from_commandline(
                        'cheese', 'Camera',
                        Gio.AppInfoCreateFlags.NONE
                    );
                    appInfo.launch([], null);
                } catch (_e2) {
                    // No camera app available
                }
            }
        });
        this.add_child(cameraBtn);

        const emergencyBtn = new St.Button({
            style: `width: 52px; height: 52px; border-radius: 26px;
                    background-color: rgba(45, 38, 64, 0.5);
                    border: 1px solid rgba(124, 58, 237, 0.2);`,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
        });
        emergencyBtn.set_child(new St.Icon({
            icon_name: 'call-start-symbolic',
            icon_size: 22,
            style: `color: #EF4444;`,
        }));
        emergencyBtn.set_position(this.width - 84, this.height - 72);
        emergencyBtn.connect('clicked', () => {
            const dialog = new St.Label({
                text: 'Emergency: 911',
                style: `color: #EF4444; font-size: 24px; font-weight: 700;
                        background-color: rgba(30, 27, 46, 0.95);
                        padding: 24px 48px; border-radius: 16px;
                        border: 2px solid #EF4444;`,
                x_align: Clutter.ActorAlign.CENTER,
                y_align: Clutter.ActorAlign.CENTER,
            });
            dialog.set_position(
                (this.width - 240) / 2,
                (this.height - 80) / 2
            );
            this.add_child(dialog);
            GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 3, () => {
                dialog.save_easing_state();
                dialog.set_easing_duration(300);
                dialog.set_opacity(0);
                dialog.restore_easing_state();
                GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
                    dialog.destroy();
                    return GLib.SOURCE_REMOVE;
                });
                return GLib.SOURCE_REMOVE;
            });
        });
        this.add_child(emergencyBtn);
    }

    _buildStatusText() {
        this._statusLabel = new St.Label({
            text: '',
            style: `color: rgba(232, 224, 240, 0.5); font-size: 12px;
                    font-weight: 400;`,
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._statusLabel.set_position(
            (this.width - 200) / 2,
            this.height - 16
        );
        this._statusLabel.set_size(200, 16);
        this.add_child(this._statusLabel);
    }

    _setupInputCapture() {
        this.connect('key-press-event', (_actor, event) => {
            if (!this._isLocked) return Clutter.EVENT_PROPAGATE;

            const keySym = event.get_key_symbol();
            if (!this._pinPadRevealed) {
                this._revealPinPad();
                return Clutter.EVENT_STOP;
            }

            if (keySym >= Clutter.KEY_0 && keySym <= Clutter.KEY_9) {
                const digit = String.fromCharCode(keySym);
                this._onPadKey(digit);
            } else if (keySym >= Clutter.KEY_KP_0 && keySym <= Clutter.KEY_KP_9) {
                const digit = (keySym - Clutter.KEY_KP_0).toString();
                this._onPadKey(digit);
            } else if (keySym === Clutter.KEY_BackSpace) {
                this._onPadKey('⌫');
            } else if (keySym === Clutter.KEY_Return || keySym === Clutter.KEY_KP_Enter) {
                this._onPadKey('✓');
            } else if (keySym === Clutter.KEY_Escape) {
                this._hidePinPad();
            }
            return Clutter.EVENT_STOP;
        });

        this.connect('button-press-event', (_actor, event) => {
            if (!this._isLocked) return Clutter.EVENT_PROPAGATE;
            if (!this._pinPadRevealed) {
                this._revealPinPad();
            }
            return Clutter.EVENT_STOP;
        });

        this.connect('scroll-event', (_actor, event) => {
            if (!this._isLocked) return Clutter.EVENT_PROPAGATE;
            const direction = event.get_scroll_direction();
            if (direction === Clutter.ScrollDirection.UP) {
                this._revealPinPad();
            } else if (direction === Clutter.ScrollDirection.DOWN) {
                this._hidePinPad();
            }
            return Clutter.EVENT_STOP;
        });
    }

    lock() {
        if (this._isLocked) return;
        this._isLocked = true;

        this._enteredPin = '';
        this._pinDots.resetDots();
        this._pinStatusLabel.set_text('');
        this._pinPadRevealed = false;
        this._pinContainer.set_opacity(0);
        this._swipeBox.set_opacity(255);
        this._dragHandle.set_opacity(255);
        this._weatherBox.set_opacity(255);
        this._notifBox.set_opacity(255);

        this._updateNotificationCount();

        Main.layoutManager.addTopChrome(this);
        this.set_opacity(0);
        this.save_easing_state();
        this.set_easing_duration(350);
        this.set_easing_mode(Clutter.AnimationMode.EASE_OUT_QUAD);
        this.set_opacity(255);
        this.restore_easing_state();

        this.grab_key_focus();

        this._inputBlocker = new Clutter.Actor({
            reactive: true,
            x: 0, y: 0,
            width: this.width,
            height: this.height,
        });
        this._inputBlocker.connect('button-press-event', () => Clutter.EVENT_STOP);
        this._inputBlocker.connect('key-press-event', () => Clutter.EVENT_STOP);
        global.stage.insert_child_below(this._inputBlocker, this);
    }

    unlock() {
        if (!this._isLocked) return;
        this._isLocked = false;

        this.save_easing_state();
        this.set_easing_duration(300);
        this.set_easing_mode(Clutter.AnimationMode.EASE_IN_QUAD);
        this.set_opacity(0);
        this.restore_easing_state();

        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
            Main.layoutManager.removeChrome(this);
            if (this._inputBlocker) {
                global.stage.remove_child(this._inputBlocker);
                this._inputBlocker.destroy();
                this._inputBlocker = null;
            }
            this._hidePinPad();
            return GLib.SOURCE_REMOVE;
        });
    }

    _setupLockTriggers() {
        try {
            Main.wm.addKeybinding(
                'satas-lock-screen',
                new Gio.Settings({ schema_id: 'org.gnome.shell.keybindings' }),
                Meta.KeyBindingFlags.NONE,
                Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW,
                () => this.lock()
            );
            this._keyBindingId = 'satas-lock-screen';
        } catch (_e) {
            // Keybinding registration may fail if schema doesn't exist; use global key handler
            this._globalKeyHandlerId = global.display.connect(
                'accelerator-activated',
                (_display, _action, _deviceId, _timestamp) => {
                    this.lock();
                }
            );
        }

        try {
            this._idleMonitor = global.backend.get_core_idle_monitor
                ? global.backend.get_core_idle_monitor()
                : Meta.IdleMonitor.get_core();

            if (this._idleMonitor) {
                this._idleWatchId = this._idleMonitor.add_idle_watch(
                    IDLE_LOCK_TIMEOUT_SECS * 1000,
                    () => {
                        if (!this._isLocked) this.lock();
                    }
                );
            }
        } catch (_e) {
            // Idle monitor unavailable on some configurations
        }

        try {
            this._uPowerProxy = Gio.DBusProxy.new_for_bus_sync(
                Gio.BusType.SYSTEM,
                Gio.DBusProxyFlags.NONE,
                null,
                'org.freedesktop.UPower',
                '/org/freedesktop/UPower',
                'org.freedesktop.UPower',
                null
            );
            this._lidSignalId = this._uPowerProxy.connect(
                'g-properties-changed',
                (_proxy, changed) => {
                    const lidClosed = changed.lookup_value('LidIsClosed', null);
                    if (lidClosed && lidClosed.get_boolean()) {
                        if (!this._isLocked) this.lock();
                    }
                }
            );
        } catch (_e) {
            // UPower not available, lid-close lock disabled
        }
    }

    destroy() {
        if (this._clockTimerId) {
            GLib.source_remove(this._clockTimerId);
            this._clockTimerId = 0;
        }
        if (this._lockoutTimerId) {
            GLib.source_remove(this._lockoutTimerId);
            this._lockoutTimerId = 0;
        }
        if (this._shakeTimerId) {
            GLib.source_remove(this._shakeTimerId);
            this._shakeTimerId = 0;
        }

        if (this._keyBindingId) {
            try {
                Main.wm.removeKeybinding(this._keyBindingId);
            } catch (_e) {
                // Keybinding may not have been registered
            }
            this._keyBindingId = null;
        }

        if (this._globalKeyHandlerId) {
            global.display.disconnect(this._globalKeyHandlerId);
            this._globalKeyHandlerId = 0;
        }

        if (this._idleMonitor && this._idleWatchId) {
            try {
                this._idleMonitor.remove_watch(this._idleWatchId);
            } catch (_e) {
                // Watch may already be removed
            }
            this._idleWatchId = 0;
        }

        if (this._uPowerProxy && this._lidSignalId) {
            this._uPowerProxy.disconnect(this._lidSignalId);
            this._lidSignalId = 0;
        }

        if (this._inputBlocker) {
            try {
                global.stage.remove_child(this._inputBlocker);
                this._inputBlocker.destroy();
            } catch (_e) {
                // Input blocker may already be removed
            }
            this._inputBlocker = null;
        }

        super.destroy();
    }
});

let _lockScreenInstance = null;

export function init() {
    // Extension initialization
}

export function enable() {
    const monitor = Main.layoutManager.primaryMonitor;
    if (!monitor) return;

    _lockScreenInstance = new LockScreen();
    _lockScreenInstance._setupLockTriggers();
}

export function disable() {
    if (_lockScreenInstance) {
        if (_lockScreenInstance._isLocked) {
            _lockScreenInstance.unlock();
        }
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 400, () => {
            if (_lockScreenInstance) {
                _lockScreenInstance.destroy();
                _lockScreenInstance = null;
            }
            return GLib.SOURCE_REMOVE;
        });
    }
}

export function lockScreen() {
    if (_lockScreenInstance && !_lockScreenInstance._isLocked) {
        _lockScreenInstance.lock();
    }
}

export function unlockScreen() {
    if (_lockScreenInstance && _lockScreenInstance._isLocked) {
        _lockScreenInstance.unlock();
    }
}

export function isLocked() {
    return _lockScreenInstance ? _lockScreenInstance._isLocked : false;
}

export default { init, enable, disable, lockScreen, unlockScreen, isLocked };
