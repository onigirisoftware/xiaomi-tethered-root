# xiaomi-tethered-root

A tethered root solution for Xiaomi devices.

## Features
- Selectable Manager
- Zygisk Fix

## Tested Device
- **Device:** Xiaomi Pad 8
- **Manager:** [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)

## Supported Host OS
- **macOS:** Supported (Test Environment: macOS Tahoe)
- **Linux:** Unknown
- **Windows:** Not supported yet

## Requirements
- **Firmware:** Highly likely requires firmware from **BEFORE the February patch**.

## Usage
```bash
chmod +x ./root_device
./root_device
```

## Update Blocker Guide
To prevent unwanted OTA updates that might patch the vulnerability, run the following commands via ADB:

- **If you do NOT have root yet:**
    ```bash
    adb shell pm suspend --user 0 com.android.updater
    adb shell pm uninstall --user 0 com.xiaomi.joyose
    ```

- **If you already have root:**
    ```bash
    adb shell su -c "pm uninstall --user 0 com.android.updater"
    adb shell su -c "pm uninstall --user 0 com.xiaomi.joyose"
    ```

## Credits & Shoutouts
- **KernelSU:** Huge shoutout to [KernelSU](https://github.com/tiann/KernelSU) for their incredible work.
- **Vulnerability:** The original discoverer of the Xiaomi Privilege Escalation vulnerability.
- **LSPosed Fix:** Thanks to [xunchahaha/mi_nobl_root](https://github.com/xunchahaha/mi_nobl_root).
- **My Best Friends:** Thanks to `Claude`, `Gemini` and `Antigravity` for making this tool possible.