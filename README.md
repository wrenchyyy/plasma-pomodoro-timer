# Pomodoro Timer — Plasma 6 Widget

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
- Critical desktop notifications on every phase change
- Bundled alarm sound (or point it at your own audio file), with `mpv` fallback
- Custom panel font: pick any font installed on your system, plus size
- Tooltip with state, phase, and completed pomodoro count
- Right-click context actions: Start/Pause and Reset

## Requirements

| Dependency | Why | Usually preinstalled on Plasma 6? |
|---|---|---|
| KDE Plasma 6 (`plasmashell`) | The widget host | Yes |
| `kpackagetool6` | Installs/updates the widget | Yes |
| Qt 6 QML: `QtQuick`, `QtQuick.Layouts`, `QtQuick.Controls`, `QtQuick.Dialogs` | UI + font picker dialog | Yes |
| `QtMultimedia` (+ FFmpeg backend) | Plays the bundled alarm sound | Yes |
| `org.kde.plasma.plasmoid`, `org.kde.plasma.core`, `org.kde.plasma.components` | Plasmoid API | Yes |
| `org.kde.plasma.plasma5support` | Runs `notify-send` / `mpv` commands | Yes |
| `org.kde.kirigami`, `org.kde.kcmutils` | Settings page | Yes |
| `libnotify` (`notify-send`) | Phase-change notifications | Yes, on most distros |
| `mpv` | Optional fallback sound player | No — install if you want the fallback (`sudo pacman -S mpv` / `sudo apt install mpv` / / `sudo dnf install mpv`) |
| A Nerd Font (optional) | Renders the work-phase glyph (`󰔟`) correctly | No — without one you'll see a placeholder box for that icon only |

## Install

```bash
git clone <your-repo-url>
cd pomodoro-timer
chmod +x install.sh
./install.sh
```

Then add it to your bar:

1. Right-click the top panel → **Edit Panel** → **Add Widgets**
2. Search **Pomodoro Timer**, drag it onto the panel

To update after pulling new changes, just run `./install.sh` again.

## Usage

- **Left-click** the panel icon: start / pause (same as the classic toggle signal)
- **Middle-click** the panel icon: full reset (timer back to 50:00 work, paused)
- **Double-click** (or press-and-hold): open the expanded view with the big timer
  and Start/Pause + Reset buttons
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

## Project structure

```
.
├── com.pomodoro.minimal/          # The Plasma 6 widget 
│   ├── metadata.json              # Plasmoid metadata
│   └── contents/
│       ├── ui/
│       │   ├── main.qml           # Timer state machine + panel/popup UI
│       │   └── configGeneral.qml  # Settings page (durations + font picker)
│       ├── config/
│       │   ├── main.xml           # Config key definitions + defaults
│       │   └── config.qml         # Registers the settings page
│       └── sounds/
│           └── tililili.mp3       # Bundled alarm sound
├── install.sh                     # Installs/updates the widget via kpackagetool6
```

## License

MIT License — Copyright (c) 2026 Wrenchy. See `LICENSE` for the full text.
