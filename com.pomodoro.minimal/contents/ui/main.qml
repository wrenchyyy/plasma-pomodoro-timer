pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtMultimedia

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Minimalist pomodoro timer for the Plasma 6 panel / top bar.
// Defaults: 50m work / 10m short / 20m long, 4 intervals.
// C globals -> QML properties:
//   state (PAUSED/RUNNING) -> running (bool)
//   cycle (WORK/SHORT_BREAK/LONG_BREAK) -> cycle (0/1/2)
//   interval -> intervalCount, elapsed -> elapsedMs / elapsed
// Signals -> inputs:
//   SIGUSR1 (toggle) -> left-click / Start-Pause button / contextual action
//   SIGUSR2 (reset)  -> middle-click / Reset button / contextual action
PlasmoidItem {
    id: root

    // --- state (mirrors pomodoro.c globals) ---
    property bool running: false
    property int cycle: 0 // 0 = WORK, 1 = SHORT_BREAK, 2 = LONG_BREAK
    property real elapsedMs: 0 // milliseconds into current cycle
    readonly property int elapsed: Math.floor(elapsedMs / 1000) // seconds into current cycle
    property int intervalCount: 0 // completed work sessions (C: interval)
    property real lastTick: 0 // Date.now() when elapsedMs was last updated

    // --- durations (C #defines become config, same defaults) ---
    // WORK_SECS 50*60, SHORT_SECS 10*60, LONG_SECS 20*60, INTERVALS 4
    readonly property int workSecs: (Plasmoid.configuration.workMinutes || 50) * 60
    readonly property int shortSecs: (Plasmoid.configuration.shortMinutes || 10) * 60
    readonly property int longSecs: (Plasmoid.configuration.longMinutes || 20) * 60
    readonly property int intervals: Plasmoid.configuration.intervals || 4
    readonly property string panelFontFamily: Plasmoid.configuration.panelFontFamily || "monospace"
    readonly property int panelFontSize: Plasmoid.configuration.panelFontSize || -1
    // Empty = bundled sound; otherwise a file:// URL to the user's audio file.
    readonly property string customSoundPath: Plasmoid.configuration.customSoundPath || ""
    // true = critical urgency: stays until dismissed, shows in Do Not Disturb.
    readonly property bool persistentNotifications: Plasmoid.configuration.persistentNotifications

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    // The work icon is a Nerd Font glyph. With no Nerd Font installed it
    // would show as an empty box, so use a plain Unicode hourglass then.
    readonly property string workIcon: {
        var families = Qt.fontFamilies();
        for (var i = 0; i < families.length; i++) {
            if (families[i].indexOf("Nerd Font") !== -1) return "󰔟";
        }
        return "⏳";
    }

    function secsFor(c) {
        if (c === 1) return shortSecs;
        if (c === 2) return longSecs;
        return workSecs;
    }

    function remainingSecs() {
        return Math.max(0, secsFor(cycle) - elapsed);
    }

    function pad(n) {
        return (n < 10 ? "0" : "") + n;
    }

    function timeText() {
        var rem = remainingSecs();
        return pad(Math.floor(rem / 60)) + ":" + pad(rem % 60);
    }

    // Mirrors the printf in main(): "⏸/▶ MM:SS cycle_icon"
    // sep is " " on a horizontal panel. On a vertical one it is "\n" and
    // the time goes on two lines too (MM over SS), like the digital clock,
    // so the text doesn't have to shrink much to fit the panel's width.
    function displayText(sep) {
        var time = timeText();
        if (sep === "\n") time = time.replace(":", sep);
        var parts = [running ? "⏸" : "▶", time];
        if (cycle === 0) parts.push(workIcon);
        return parts.join(sep);
    }

    function cycleName() {
        if (cycle === 1) return i18n("Short Break");
        if (cycle === 2) return i18n("Long Break");
        return i18n("Work");
    }

    // Pomodoros done in the current set, for the "n / intervals" label.
    // intervalCount itself keeps counting across sets.
    function doneInSet() {
        var n = intervalCount % intervals;
        return (n === 0 && cycle === 2) ? intervals : n;
    }

    // SIGUSR1 handler
    function toggle() {
        if (running) {
            sync(); // count the part of a second since the last tick
        } else {
            lastTick = Date.now();
        }
        running = !running;
    }

    // SIGUSR2 handler
    function reset() {
        elapsedMs = 0;
        cycle = 0;
        intervalCount = 0;
        running = false;
    }

    // advance_cycle() from pomodoro.c
    function advanceCycle() {
        if (cycle === 0) {
            intervalCount++;
            cycle = (intervalCount % intervals === 0) ? 2 : 1;
            notify(i18n("Time for a break!"));
        } else {
            cycle = 0;
            notify(i18n("Time to work!"));
        }
        playSound();
        elapsedMs = 0;
    }

    // Adds the time since the last call to elapsedMs. Reading the clock
    // instead of counting ticks means a late tick doesn't lose time.
    function sync() {
        var now = Date.now();
        var gap = now - lastTick;
        lastTick = now;
        // A gap this long means the machine was suspended or the clock was
        // changed. Time asleep doesn't count: treat it as one normal tick.
        if (gap < 0 || gap > 10000) gap = 1000;
        advance(gap);
    }

    function advance(ms) {
        elapsedMs += ms;
        if (elapsedMs >= secsFor(cycle) * 1000) {
            advanceCycle();
        }
    }

    // Single-quotes a string for the shell.
    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // file:// URL -> plain path.
    function localPath(url) {
        var p = String(url).replace(/^file:\/\//, "");
        try {
            return decodeURIComponent(p);
        } catch (e) {
            return p;
        }
    }

    // --- side effects: notification + sound, as in the C version ---
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
        }
        function exec(cmd) {
            connectSource(cmd);
        }
    }

    // Native notification. Loaded on its own so that a system without the
    // org.kde.notification module still gets notify-send (original behavior).
    Loader {
        id: notifier
        source: "Notifier.qml"
        onLoaded: item.iconName = root.localPath(Qt.resolvedUrl("../icons/pomodoro.svg"))
    }

    function notify(body) {
        if (notifier.status === Loader.Ready) {
            // qmllint disable missing-property
            notifier.item.send(body, persistentNotifications);
            // qmllint enable missing-property
            return;
        }
        executable.exec("notify-send -u " + (persistentNotifications ? "critical" : "normal")
            + " " + shQuote(i18n("Pomodoro")) + " " + shQuote(body));
    }

    // Bundled alarm sound (contents/sounds/tililili.mp3), or the user's
    // own file when one is picked in the settings.
    // Order: custom file -> bundled sound -> mpv, each one only when the
    // one before it can't be played.
    // MediaDevices binding keeps playback on the system default sink
    // (e.g. Bluetooth earphones) even when it changes after load.
    readonly property url bundledSound: Qt.resolvedUrl("../sounds/tililili.mp3")
    property bool customSoundFailed: false // custom file didn't load or play
    property bool alarmDue: false // playSound() called, nothing playing yet
    onCustomSoundPathChanged: customSoundFailed = false

    // The settings page stores a file:// URL. Older versions stored it
    // without the scheme, so put it back for those.
    function soundUrl(s) {
        return s.indexOf("file://") === 0 ? s : "file://" + s;
    }

    MediaDevices {
        id: mediaDevices
    }
    MediaPlayer {
        id: player
        source: (root.customSoundPath !== "" && !root.customSoundFailed)
            ? root.soundUrl(root.customSoundPath) : root.bundledSound
        audioOutput: AudioOutput {
            device: mediaDevices.defaultAudioOutput
        }
        onPlayingChanged: if (player.playing) root.alarmDue = false
        // A missing or unsupported file reports its error when it is
        // loaded, not at play(), and play() then does nothing.
        onErrorOccurred: function(error, errorString) {
            if (root.customSoundPath !== "" && !root.customSoundFailed) {
                Qt.callLater(root.useBundledSound);
            } else if (root.alarmDue) {
                root.mpvFallback();
            }
        }
    }

    function useBundledSound() {
        customSoundFailed = true; // player.source switches to bundledSound
        if (alarmDue) player.play();
    }

    function mpvFallback() {
        alarmDue = false;
        var cmd = "mpv --no-terminal -- " + shQuote(localPath(bundledSound));
        if (customSoundPath !== "") {
            cmd = "mpv --no-terminal -- " + shQuote(localPath(customSoundPath)) + " || " + cmd;
        }
        executable.exec("(" + cmd + ") >/dev/null 2>&1 &");
    }

    function playSound() {
        alarmDue = true;
        // mpv only when the player has already given up on the file.
        if (player.error !== MediaPlayer.NoError || player.mediaStatus === MediaPlayer.InvalidMedia) {
            mpvFallback();
            return;
        }
        player.stop(); // restart if the previous alarm is still playing
        player.play();
    }

    // 1s tick: mirrors the sleep(1) loop in main(), with the elapsed time
    // taken from the clock in sync(). The interval is trimmed so each tick
    // lands just past a whole second of elapsedMs; a fixed 1000 would drift
    // and make the countdown skip a second now and then.
    Timer {
        id: tick
        interval: 1010 - root.elapsedMs % 1000
        running: root.running
        repeat: true
        onTriggered: root.sync()
    }

    // If the user shortens durations below the current elapsed, clamp.
    onWorkSecsChanged: if (elapsed > secsFor(cycle)) elapsedMs = 0;
    onShortSecsChanged: if (elapsed > secsFor(cycle)) elapsedMs = 0;
    onLongSecsChanged: if (elapsed > secsFor(cycle)) elapsedMs = 0;

    // --- panel integration (top bar) ---
    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: false

    toolTipMainText: displayText(" ")
    toolTipSubText: (running ? i18n("Running") : i18n("Paused")) + " • " + cycleName()
        + " • " + i18np("%1 pomodoro done", "%1 pomodoros done", intervalCount)
        + "\n" + i18n("Left-click: start/pause • Middle-click: reset")

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: root.running ? i18n("Pause") : i18n("Start")
            icon.name: root.running ? "media-playback-pause" : "media-playback-start"
            onTriggered: root.toggle()
        },
        PlasmaCore.Action {
            text: i18n("Reset")
            icon.name: "view-refresh"
            onTriggered: root.reset()
        }
    ]

    compactRepresentation: MouseArea {
        id: compactMouse
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        // Horizontal panel: as wide as the text. Vertical panel: one item
        // per line, shrunk to the panel's width (see compactLabel).
        Layout.minimumWidth: root.vertical ? 0 : compactLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: root.vertical ? compactLabel.contentHeight : compactLabel.implicitHeight
        Layout.preferredWidth: root.vertical ? -1 : compactLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredHeight: root.vertical ? compactLabel.contentHeight : compactLabel.implicitHeight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: root.cycleName() + " " + root.timeText()
        Accessible.description: root.toolTipSubText
        Accessible.onPressAction: root.toggle()
        Keys.onPressed: function(event) {
            switch (event.key) {
            case Qt.Key_Space:
            case Qt.Key_Enter:
            case Qt.Key_Return:
            case Qt.Key_Select:
                root.toggle();
                event.accepted = true;
                break;
            }
        }

        PlasmaComponents.Label {
            id: compactLabel
            anchors.centerIn: parent
            width: root.vertical ? compactMouse.width : undefined
            horizontalAlignment: Text.AlignHCenter
            fontSizeMode: root.vertical ? Text.HorizontalFit : Text.FixedSize
            minimumPointSize: 5
            text: root.displayText(root.vertical ? "\n" : " ")
            font.family: root.panelFontFamily
            font.pointSize: root.panelFontSize
            // "class": running/paused from Waybar CSS -> opacity hint here
            opacity: root.running ? 1.0 : 0.75
            font.bold: root.running && root.cycle === 0
        }

        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.toggle(); // = pkill -SIGUSR1
            } else if (mouse.button === Qt.MiddleButton) {
                root.reset(); // = pkill -SIGUSR2
            }
            mouse.accepted = true;
        }
        // A double-click arrives as clicked, then doubleClicked, so the
        // first click has already toggled the timer: toggle it back.
        onDoubleClicked: function(mouse) {
            if (mouse.button !== Qt.LeftButton) return;
            root.toggle();
            root.expanded = !root.expanded;
            mouse.accepted = true;
        }
        onPressAndHold: root.expanded = !root.expanded
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 10
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.cycleName()
            font.family: root.panelFontFamily
            font.bold: true
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.timeText()
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 4
            font.family: root.panelFontFamily
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("%1 / %2 pomodoros", root.doneInSet(), root.intervals)
            font.family: root.panelFontFamily
            opacity: 0.7
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            PlasmaComponents.Button {
                text: root.running ? i18n("Pause") : i18n("Start")
                icon.name: root.running ? "media-playback-pause" : "media-playback-start"
                onClicked: root.toggle()
            }
            PlasmaComponents.Button {
                text: i18n("Reset")
                icon.name: "view-refresh"
                onClicked: root.reset()
            }
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("%1/%2/%3 • left-click panel icon toggles",
                root.workSecs / 60, root.shortSecs / 60, root.longSecs / 60)
            opacity: 0.5
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }
}
