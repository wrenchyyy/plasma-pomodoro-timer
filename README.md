# Pomodoro Timer — Plasma 6 Widget

[![KDE Store](https://img.shields.io/badge/KDE_Store-download-blue)](https://store.kde.org/p/2371261/)

> Ported from https://github.com/Atornous12/waybar-pomodoro-module-c —
> a minimalist Pomodoro module for Waybar, re-implemented here as a native
> Plasma 6 panel widget.

A minimalist Pomodoro timer widget for the KDE Plasma 6 panel (top bar included).
It shows a live countdown in your panel, notifies you on phase changes, and plays
a sound when it's time to work or take a break.

## Features

- Lives in the panel: compact `⏸/▶ MM:SS` countdown, ideal for a top bar
- Classic cycle: 50 min work / 10 min short break / 20 min long break, long break
  after every 4 completed pomodoros (all configurable)
- Left-click the panel icon to start/pause, middle-click to reset
- Popup view with a large timer, current phase, session progress, and Start/Pause
  and Reset buttons (double-click the icon or press-and-hold to open it)
- Desktop notifications on every phase change, kept on screen until dismissed
  (can be turned off in the settings)
- Bundled alarm sound (or point it at your own audio file). If your file can't
  be played the bundled sound is used, and `mpv` is the last resort
- Countdown follows the clock, so a busy desktop doesn't make it run slow; time
  spent suspended is not counted
- Works in vertical panels: the text is stacked (minutes over seconds) and
  shrinks if the panel is very narrow
- Custom panel font: pick any font installed on your system, plus size
- Tooltip with state, phase, and completed pomodoro count
- Right-click context actions: Start/Pause and Reset
- Keyboard: with the widget focused in the panel, Space or Enter starts/pauses

## Requirements

| Dependency | Why | Usually preinstalled on Plasma 6? |
|---|---|---|
| KDE Plasma 6 (`plasmashell`) | The widget host | Yes |
| `kpackagetool6` | Installs/updates the widget | Yes |
| Qt 6 QML: `QtQuick`, `QtQuick.Layouts`, `QtQuick.Controls`, `QtQuick.Dialogs` | UI + font picker dialog | Yes |
| `QtMultimedia` (+ FFmpeg backend) | Plays the bundled alarm sound | Yes |
| `org.kde.plasma.plasmoid`, `org.kde.plasma.core`, `org.kde.plasma.components` | Plasmoid API | Yes |
| `org.kde.plasma.plasma5support` | Runs the `notify-send` / `mpv` fallback commands | Yes |
| `org.kde.kirigami`, `org.kde.kcmutils` | Settings page | Yes |
| `org.kde.notification` (KNotifications) | Phase-change notifications | Yes |
| `libnotify` (`notify-send`) | Notifications when the `org.kde.notification` QML module is missing | Yes, on most distros |
| `mpv` | Optional fallback sound player | No — install if you want the fallback (`sudo pacman -S mpv` / `sudo apt install mpv` / `sudo dnf install mpv`) |
| A Nerd Font (optional) | Renders the work-phase glyph (`󰔟`) | No — without one a plain Unicode hourglass (`⏳`) is shown instead |

## Install

- **KDE Store:** grab the `.plasmoid` from
  [store.kde.org/p/2371261](https://store.kde.org/p/2371261/), then
  right-click the panel → **Edit Panel** → **Add Widgets** → **Get New
  Widgets** → **Install from file…**
- **From source:**

```bash
git clone https://github.com/wrenchyyy/plasma-pomodoro-timer.git
cd plasma-pomodoro-timer
./install.sh
```

Then add it to your bar:

1. Right-click the top panel → **Edit Panel** → **Add Widgets**
2. Search **Pomodoro Timer**, drag it onto the panel

To update after pulling new changes, just run `./install.sh` again.
To remove the widget and its icon, run `./install.sh --uninstall`.

## Usage

- **Left-click** the panel icon: start / pause (same as the classic toggle signal)
- **Middle-click** the panel icon: full reset (timer back to 50:00 work, paused)
- **Double-click** (or press-and-hold): open the expanded view with the big timer
  and Start/Pause + Reset buttons; the timer keeps its state
- **Right-click**: standard widget menu plus Start/Pause and Reset actions,
  and **Configure…** for settings

## Configuration

Right-click the widget → **Configure…**:

- **Work / Short break / Long break (minutes)** — phase lengths, defaults 50 / 10 / 20
- **Intervals before long break** — default 4
- **Panel font** — **Choose…** opens the system font dialog listing every font on
  your PC; pick a family and size, or **Default** to go back to system monospace.
  The choice applies to the panel countdown and the popup timer text.
- **Alarm sound** — **Browse…** to point the widget at your own MP3/audio file,
  or **Bundled** to restore the built-in sound. Please keep custom sounds short —
  **5–10 seconds max** — so the alarm finishes cleanly instead of blaring over
  your next phase.
- **Notifications** — **Stay until dismissed, even in Do Not Disturb** is on by
  default. Turn it off for normal notifications that time out and respect
  Do Not Disturb.

## Project structure

```
.
├── com.pomodoro.minimal/          # The Plasma 6 widget 
│   ├── metadata.json              # Plasmoid metadata
│   └── contents/
│       ├── ui/
│       │   ├── main.qml           # Timer state machine + panel/popup UI
│       │   ├── Notifier.qml       # Phase-change notification
│       │   └── configGeneral.qml  # Settings page (durations, font, sound, notifications)
│       ├── config/
│       │   ├── main.xml           # Config key definitions + defaults
│       │   └── config.qml         # Registers the settings page
│       ├── icons/
│       │   └── pomodoro.svg       # Widget icon (browser + About page)
│       └── sounds/
│           └── tililili.mp3       # Bundled alarm sound
├── install.sh                     # Installs/updates/removes the widget via kpackagetool6
├── lint.sh                        # Checks run by CI: metadata, config XML, qmllint
```

## License

MIT License — Copyright (c) 2026 Wrenchy. See `LICENSE` for the full text.
