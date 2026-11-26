
# Ridbowt Drift Clock [![GitHub release](https://img.shields.io/github/v/release/Ridbowt/RidbowtDriftClock?label=version)](https://github.com/Ridbowt/RidbowtDriftClock/releases)

A digital clock screensaver for Windows, featuring a colorful seven-segment display and date.

Ridbowt Drift Clock is a minimalist screensaver that displays the current time and date in a distinctive digital style.

## Features

- **Large Digital Clock:** Easy-to-read seven-segment display.
- **Color-Coded Time:** Hours, minutes, and seconds displayed in distinct colors.
- **Customizable Display:** Optional seconds display and blinking colons.
- **Date Display:** Current date shown below the clock.
- **Multiple Color Schemes:** Choose from several clock color combinations.
- **Adjustable Movement:** Customize the clock's movement and positioning.
- **Optional Background Effects:** Enable or disable atmospheric background effects.
- **Customizable Settings:** Adjust the clock appearance and behavior.

## Screenshots

### Default Clock
![Default Clock](screenshots/01_default_clock.png)

### US Clock (12-Hour Format)
![US Clock](screenshots/02_us_clock.png)

### Background Clock
![Background Clock](screenshots/03_background_clock.png)

### Settings Window
![Settings Window](screenshots/04_settings_window.png)

## Installation

### Installing the Screensaver

1. Download the latest release from the [Releases](https://github.com/Ridbowt/RidbowtDriftClock/releases) page.
2. Extract the downloaded ZIP archive.
3. Double-click `RidbowtDriftClock.exe` to open the Ridbowt Drift Clock Control Panel.
4. Click **Install** to install and register the screensaver with Windows.
5. If Windows displays a User Account Control (UAC) prompt, approve it to continue.

### Control Panel

The Control Panel can be opened by double-clicking `RidbowtDriftClock.exe`.

It provides four options:

- **Install** — installs and registers the screensaver with Windows.
- **Run** — launches the screensaver immediately.
- **Setup** — opens the screensaver configuration window.
- **Uninstall** — removes the installed screensaver from the system.

### Uninstalling

There are two ways to uninstall the screensaver.

**Method 1 — Using the Control Panel**

1. Double-click `RidbowtDriftClock.exe` to open the Control Panel.
2. Click **Uninstall**.

**Method 2 — Using Windows Screen Saver Settings**

If you have already installed the screensaver and deleted the downloaded ZIP archive or the original EXE file:

1. Open the Windows Screen Saver Settings window.
2. Select **Ridbowt Drift Clock** as your screen saver, if it is not already selected.
3. Click **Settings** to open the screensaver configuration window.
4. Click the **Uninstall** link at the bottom of the window.

During uninstallation, you can choose whether to keep or delete your saved user settings.

After installation, the original EXE file and downloaded ZIP archive are no longer required for the screensaver to work. They can be safely deleted. The screensaver can also be uninstalled through Windows Screen Saver Settings without them.

## System Requirements

- **Operating System:** Windows 10 or Windows 11 (64-bit).

## Compatibility and Testing

Ridbowt Drift Clock supports displays with different resolutions and DPI scaling settings. High-DPI font scaling has been improved.

Multi-monitor support has also been improved and tested using a virtual second monitor. However, testing on systems with multiple physical monitors is still needed to confirm compatibility across different display configurations.

If you encounter any display-related issues, please report them on the project's GitHub Issues page.

## Display Burn-in Warning

**Important:** Prolonged display of a static image may cause image retention or permanent burn-in on certain types of displays.

- **OLED displays:** Prolonged static content may cause uneven pixel wear and permanent image retention (burn-in).
- **LCD displays:** Some panels may experience temporary image retention.

To reduce potential risks, it is recommended to keep clock movement enabled rather than displaying the clock in a fixed position for extended periods.

Use this screensaver at your own discretion. The developer is not responsible for display damage or image retention resulting from prolonged static display.

## Building from Source

The project is written in Object Pascal and developed using:

- [Lazarus IDE](https://www.lazarus-ide.org/)
- [Free Pascal Compiler](https://www.freepascal.org/)

To build the application, open `RidbowtDriftClock.lpi` in Lazarus and compile the project.

## Fonts

This project uses the following fonts:

- **DSEG7 Classic** — seven-segment digital display font.
- **Noto Sans SemiBold** — supporting text font.

Both fonts are distributed under the SIL Open Font License 1.1. Their license files are included in the `LICENSES` directory.

## License

The Ridbowt Drift Clock source code is released under the MIT License.

Third-party fonts are distributed under their respective licenses. See the `LICENSES` directory for details.

---

**Ridbowt Drift Clock** — a colorful digital clock for your Windows desktop.

<sub>Windows screensaver, digital clock screensaver, desktop clock, seven-segment display, Windows clock, заставка часы, заставка с часами, цифровые часы, цифровая заставка, часы на рабочий стол, заставка для Windows, семисегментные часы, электронные часы</sub>
