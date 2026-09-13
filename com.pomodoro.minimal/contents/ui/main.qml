import QtQuick
import QtQuick.Layouts
import QtMultimedia

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Minimalist pomodoro timer for the Plasma 6 panel / top bar.
// 50m work / 10m short / 20m long, 4 intervals.
// C globals -> QML properties:
//   state (PAUSED/RUNNING) -> running (bool)
//   cycle (WORK/SHORT_BREAK/LONG_BREAK) -> cycle (0/1/2)
//   interval -> intervalCount, elapsed -> elapsed
// Signals -> inputs:
//   SIGUSR1 (toggle) -> left-click / Start-Pause button / contextual action
//   SIGUSR2 (reset)  -> middle-click / Reset button / contextual action
PlasmoidItem {
    id: root

    // --- state (mirrors pomodoro.c globals) ---
    property bool running: false
    property int cycle: 0 // 0 = WORK, 1 = SHORT_BREAK, 2 = LONG_BREAK
    property int elapsed: 0 // seconds into current cycle
    property int intervalCount: 0 // completed work sessions (C: interval)

    // --- durations (C #defines become config, same defaults) ---
    // WORK_SECS 50*60, SHORT_SECS 10*60, LONG_SECS 20*60, INTERVALS 4
    readonly property int workSecs: (Plasmoid.configuration.workMinutes || 50) * 60
    readonly property int shortSecs: (Plasmoid.configuration.shortMinutes || 10) * 60
    readonly property int longSecs: (Plasmoid.configuration.longMinutes || 20) * 60
    readonly property int intervals: Plasmoid.configuration.intervals || 4
    readonly property string panelFontFamily: Plasmoid.configuration.panelFontFamily || "monospace"
    readonly property int panelFontSize: Plasmoid.configuration.panelFontSize || -1
    // Empty = bundled sound; otherwise an absolute path to the user's audio file.
    readonly property string customSoundPath: Plasmoid.configuration.customSoundPath || ""

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

    // Mirrors the printf in main(): "⏸/▶ MM:SS cycle_icon"
    function displayText() {
        var rem = remainingSecs();
        var m = Math.floor(rem / 60);
        var s = rem % 60;
        var toggleIcon = running ? "⏸" : "▶";
        var cycleIcon = (cycle === 0) ? "󰔟" : "";
        return toggleIcon + " " + pad(m) + ":" + pad(s) + " " + cycleIcon;
    }

    function cycleName() {
        if (cycle === 1) return "Short Break";
        if (cycle === 2) return "Long Break";
        return "Work";
    }

    // SIGUSR1 handler
    function toggle() {
        running = !running;
    }

    // SIGUSR2 handler
    function reset() {
        elapsed = 0;
        cycle = 0;
        intervalCount = 0;
        running = false;
    }

    // advance_cycle() from pomodoro.c
    function advanceCycle() {
        if (cycle === 0) {
            intervalCount++;
            cycle = (intervalCount % intervals === 0) ? 2 : 1;
            notify("Time for a break!");
        } else {
            cycle = 0;
            notify("Time to work!");
        }
        playSound();
        elapsed = 0;
    }

    // --- side effects: same notify-send + sound commands as the C version ---
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

    function notify(body) {
        executable.exec("notify-send -u critical 'Pomodoro' '" + body + "'");
    }

    // Bundled alarm sound (contents/sounds/tililili.mp3), or the user's
    // own file when one is picked in the settings.
    // Primary: QtMultimedia. Fallback: mpv (original behavior).
    // MediaDevices binding keeps playback on the system default sink
    // (e.g. Bluetooth earphones) even when it changes after load.
    MediaDevices {
        id: mediaDevices
    }
    MediaPlayer {
        id: player
        source: root.customSoundPath !== "" ? "file://" + root.customSoundPath : "../sounds/tililili.mp3"
        audioOutput: AudioOutput {
            device: mediaDevices.defaultAudioOutput
        }
        onErrorOccurred: function(error, errorString) {
            mpvFallback();
        }
    }

    function bundledSoundFile() {
        return String(Qt.resolvedUrl("../sounds/tililili.mp3")).replace(/^file:\/\//, "");
    }

    function mpvFallback() {
        var f = root.customSoundPath !== "" ? root.customSoundPath : bundledSoundFile();
        var quoted = "'" + String(f).replace(/'/g, "'\\''") + "'";
        executable.exec("sh -c 'mpv --no-terminal " + quoted + " >/dev/null 2>&1 &'");
    }

    function playSound() {
        // Primary path; mpv only fires if MediaPlayer reports an error.
        try {
            player.play();
        } catch (e) {
            mpvFallback();
        }
    }

    // 1s tick: mirrors sleep(1) + elapsed++ loop in main().
    Timer {
        id: tick
        interval: 1000
        running: root.running
        repeat: true
        onTriggered: {
            if (!root.running) return;
            root.elapsed++;
            if (root.elapsed >= root.secsFor(root.cycle)) {
                root.advanceCycle();
            }
        }
    }

    // If the user shortens durations below the current elapsed, clamp.
    onWorkSecsChanged: if (elapsed > secsFor(cycle)) elapsed = 0;
    onShortSecsChanged: if (elapsed > secsFor(cycle)) elapsed = 0;
    onLongSecsChanged: if (elapsed > secsFor(cycle)) elapsed = 0;

    // --- panel integration (top bar) ---
    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: false

    toolTipMainText: displayText()
    toolTipSubText: (running ? "Running" : "Paused") + " • " + cycleName()
        + " • " + intervalCount + " pomodoro" + (intervalCount === 1 ? "" : "s") + " done"
        + "\nLeft-click: start/pause • Middle-click: reset"

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: root.running ? "Pause" : "Start"
            icon.name: root.running ? "media-playback-pause" : "media-playback-start"
            onTriggered: root.toggle()
        },
        PlasmaCore.Action {
            text: "Reset"
            icon.name: "view-refresh"
            onTriggered: root.reset()
        }
    ]

    compactRepresentation: MouseArea {
        id: compactMouse
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        Layout.minimumWidth: compactLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: compactLabel.implicitHeight
        Layout.preferredWidth: compactLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredHeight: compactLabel.implicitHeight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        PlasmaComponents.Label {
            id: compactLabel
            anchors.centerIn: parent
            text: root.displayText()
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
        onDoubleClicked: function(mouse) {
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
            text: {
                var rem = root.remainingSecs();
                return root.pad(Math.floor(rem / 60)) + ":" + root.pad(rem % 60);
            }
            font.pointSize: 42
            font.family: root.panelFontFamily
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.intervalCount + " / " + root.intervals + " pomodoros"
            font.family: root.panelFontFamily
            opacity: 0.7
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            PlasmaComponents.Button {
                text: root.running ? "Pause" : "Start"
                icon.name: root.running ? "media-playback-pause" : "media-playback-start"
                onClicked: root.toggle()
            }
            PlasmaComponents.Button {
                text: "Reset"
                icon.name: "view-refresh"
                onClicked: root.reset()
            }
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: "50/10/20 • left-click panel icon toggles"
            opacity: 0.5
            font.pointSize: 8
        }
    }
}
