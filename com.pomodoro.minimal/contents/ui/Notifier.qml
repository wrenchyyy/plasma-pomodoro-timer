import QtQuick

import org.kde.notification

// Phase-change notification, loaded by main.qml through a Loader.
// One Notification object is reused, so a new phase replaces the popup
// of the previous one instead of stacking another.
Item {
    property alias iconName: popup.iconName

    function send(body, persistent) {
        popup.text = body;
        popup.urgency = persistent ? Notification.CriticalUrgency : Notification.NormalUrgency;
        popup.sendEvent();
    }

    Notification {
        id: popup
        componentName: "plasma_workspace"
        eventId: "notification"
        title: i18n("Pomodoro")
    }
}
