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
    id: page

    property int cfg_workMinutes
    property int cfg_shortMinutes
    property int cfg_longMinutes
    property int cfg_intervals
    property string cfg_panelFontFamily
    property int cfg_panelFontSize
    property string cfg_customSoundPath
    property bool cfg_persistentNotifications

    // Plasma also sets a cfg_<key>Default for every key and logs a
    // warning for each one the page doesn't declare.
    property int cfg_workMinutesDefault
    property int cfg_shortMinutesDefault
    property int cfg_longMinutesDefault
    property int cfg_intervalsDefault
    property string cfg_panelFontFamilyDefault
    property int cfg_panelFontSizeDefault
    property string cfg_customSoundPathDefault
    property bool cfg_persistentNotificationsDefault

    // The sound is stored as a file:// URL; show it as a plain path.
    function displayPath(url) {
        var p = String(url).replace(/^file:\/\//, "");
        try {
            return decodeURIComponent(p);
        } catch (e) {
            return p;
        }
    }

    Kirigami.FormLayout {
        SpinBox {
            id: workSpin
            Kirigami.FormData.label: i18n("Work (minutes):")
            from: 1
            to: 180
            value: page.cfg_workMinutes
            onValueChanged: page.cfg_workMinutes = value
        }
        SpinBox {
            id: shortSpin
            Kirigami.FormData.label: i18n("Short break (minutes):")
            from: 1
            to: 60
            value: page.cfg_shortMinutes
            onValueChanged: page.cfg_shortMinutes = value
        }
        SpinBox {
            id: longSpin
            Kirigami.FormData.label: i18n("Long break (minutes):")
            from: 1
            to: 90
            value: page.cfg_longMinutes
            onValueChanged: page.cfg_longMinutes = value
        }
        SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: i18n("Intervals before long break:")
            from: 1
            to: 12
            value: page.cfg_intervals
            onValueChanged: page.cfg_intervals = value
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Panel font:")
            Label {
                id: fontPreview
                Layout.fillWidth: true
                text: page.cfg_panelFontSize > 0
                    ? i18n("%1 %2pt", page.cfg_panelFontFamily, page.cfg_panelFontSize)
                    : i18n("%1 (system size)", page.cfg_panelFontFamily)
                font.family: page.cfg_panelFontFamily
                elide: Text.ElideRight
            }
            Button {
                text: i18n("Choose…")
                icon.name: "preferences-desktop-font"
                onClicked: {
                    fontDialog.selectedFont = Qt.font({
                        family: page.cfg_panelFontFamily,
                        pointSize: page.cfg_panelFontSize > 0 ? page.cfg_panelFontSize : Kirigami.Theme.defaultFont.pointSize
                    });
                    fontDialog.open();
                }
            }
            Button {
                text: i18n("Default")
                onClicked: {
                    page.cfg_panelFontFamily = "monospace";
                    page.cfg_panelFontSize = -1;
                }
            }
        }

        FontDialog {
            id: fontDialog
            title: i18n("Choose panel font")
            // Lists every font installed on the system.
            onAccepted: {
                page.cfg_panelFontFamily = selectedFont.family;
                page.cfg_panelFontSize = selectedFont.pointSize > 0 ? selectedFont.pointSize : -1;
            }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Alarm sound:")
            Label {
                Layout.fillWidth: true
                text: page.cfg_customSoundPath !== "" ? page.displayPath(page.cfg_customSoundPath) : i18n("Bundled sound (tililili.mp3)")
                elide: Text.ElideMiddle
            }
            Button {
                text: i18n("Browse…")
                icon.name: "document-open"
                onClicked: soundDialog.open()
            }
            Button {
                text: i18n("Bundled")
                onClicked: page.cfg_customSoundPath = ""
            }
        }

        FileDialog {
            id: soundDialog
            title: i18n("Choose alarm sound")
            fileMode: FileDialog.OpenFile
            nameFilters: [i18n("Audio files (*.mp3 *.wav *.ogg *.flac *.m4a)"), i18n("All files (*)")]
            currentFolder: StandardPaths.writableLocation(StandardPaths.MusicLocation)
            onAccepted: page.cfg_customSoundPath = String(selectedFile)
        }
        CheckBox {
            Kirigami.FormData.label: i18n("Notifications:")
            text: i18n("Stay until dismissed, even in Do Not Disturb")
            checked: page.cfg_persistentNotifications
            onToggled: page.cfg_persistentNotifications = checked
        }
    }
}
