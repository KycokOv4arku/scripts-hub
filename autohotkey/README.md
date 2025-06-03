## AutoHotkey

A collection of my personal AutoHotkey scripts—custom binds I use daily.

---

To get started:

- install [AutoHotkey v2.0](https://www.autohotkey.com/)
- place the `.ahk` files in your preferred scripts folder and run them.
- Each script will create its own settings file (if needed) and register the hotkeys automatically

---

### Quick overview and usage for each:

- **`adjust_window_transparenc.ahk`**

  - **What it does**: Change active window transparency with Ctrl + Shift + Alt + Mouse Wheel.
  - **Usage**:
    - Hover over any window.
    - Press **Ctrl+Shift+Alt + WheelUp** to increase opacity (up to 255).
    - Press **Ctrl+Shift+Alt + WheelDown** to decrease opacity (down to 1).
    - Transparency value is saved in `transparency.ini` so it’s restored on script launch.

- **`search_clipboard_image_yandex.ahk`**

  - **What it does**: Opens Yandex Images and pastes whatever image is in your clipboard.
  - **Usage**:
    - Copy an image (e.g., PrintScreen → select region → Ctrl+C).
    - Press **Win + Y** to automatically open `yandex.ru/images/` and send Ctrl+V.

- **`toggle_telegram_window.ahk`**

  - **What it does**: Cycles Telegram between launched/hidden/active states and shows a notification on both monitors.
  - **Usage**:
    - Press **Win + Q**.
      1. If Telegram is active → hides it, resets transparency, shows “TG hidden to tray.”
      2. If hidden (stored handle exists) → shows & activates it, resets transparency, shows “TG is now active.”
      3. If not running → launches Telegram executable, waits for window, resets transparency, shows “TG is launching.”

- **`toggle_vscode_window.ahk`**
  - **What it does**: Same toggle/notification logic for VS Code (cycles launch/hide/activate).
  - **Usage**:
    - Press **Win + C**.
      1. If VS Code is active → hides it, resets transparency to 240, shows “Code hidden to tray.”
      2. If hidden → shows & activates it, resets transparency to 240, shows “Code is now active.”
      3. If not running → runs VS Code, waits for window, resets transparency, shows “Code is launching.”
