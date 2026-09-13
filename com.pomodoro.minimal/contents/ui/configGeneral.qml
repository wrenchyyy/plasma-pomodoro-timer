import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Durations default to 50m work / 10m short / 20m long, 4 intervals.
// Font defaults to system monospace; -1 size means "follow the system".
KCM.SimpleKCM {
    property int cfg_workMinutes
    property int cfg_shortMinutes
    property int cfg_longMinutes
    property int cfg_intervals
    property string cfg_panelFontFamily
    property int cfg_panelFontSize
    property string cfg_customSoundPath

    Kirigami.FormLayout {
        SpinBox {
            id: workSpin
            Kirigami.FormData.label: "Work (minutes):"
            from: 1
            to: 180
            value: cfg_workMinutes
            onValueChanged: cfg_workMinutes = value
        }
        SpinBox {
            id: shortSpin
            Kirigami.FormData.label: "Short break (minutes):"
            from: 1
            to: 60
            value: cfg_shortMinutes
            onValueChanged: cfg_shortMinutes = value
        }
        SpinBox {
            id: longSpin
            Kirigami.FormData.label: "Long break (minutes):"
            from: 1
            to: 90
            value: cfg_longMinutes
            onValueChanged: cfg_longMinutes = value
        }
        SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: "Intervals before long break:"
            from: 1
            to: 12
            value: cfg_intervals
            onValueChanged: cfg_intervals = value
        }
        RowLayout {
            Kirigami.FormData.label: "Panel font:"
            Label {
                id: fontPreview
                Layout.fillWidth: true
                text: cfg_panelFontFamily + (cfg_panelFontSize > 0 ? " " + cfg_panelFontSize + "pt" : " (system size)")
                font.family: cfg_panelFontFamily
                elide: Text.ElideRight
            }
            Button {
                text: "Choose…"
                icon.name: "preferences-desktop-font"
                onClicked: fontDialog.open()
            }
            Button {
                text: "Default"
                onClicked: {
                    cfg_panelFontFamily = "monospace";
                    cfg_panelFontSize = -1;
                }
            }
        }

        FontDialog {
            id: fontDialog
            title: "Choose panel font"
            // Lists every font installed on the system.
            currentFont: Qt.font({
                family: cfg_panelFontFamily,
                pointSize: cfg_panelFontSize > 0 ? cfg_panelFontSize : 10
            })
            onAccepted: {
                cfg_panelFontFamily = font.family;
                cfg_panelFontSize = font.pointSize;
            }
        }
        RowLayout {
            Kirigami.FormData.label: "Alarm sound:"
            Label {
                Layout.fillWidth: true
                text: cfg_customSoundPath !== "" ? cfg_customSoundPath : "Bundled sound (tililili.mp3)"
                elide: Text.ElideMiddle
            }
            Button {
                text: "Browse…"
                icon.name: "document-open"
                onClicked: soundDialog.open()
            }
            Button {
                text: "Bundled"
                onClicked: cfg_customSoundPath = ""
            }
        }

        FileDialog {
            id: soundDialog
            title: "Choose alarm sound"
            fileMode: FileDialog.OpenFile
            nameFilters: ["Audio files (*.mp3 *.wav *.ogg *.flac *.m4a)", "All files (*)"]
            currentFolder: StandardPaths.writableLocation(StandardPaths.MusicLocation)
            onAccepted: cfg_customSoundPath = String(selectedFile).replace(/^file:\/\//, "")
        }
    }
}
