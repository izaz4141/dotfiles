import QtQuick
import qs.Common

Rectangle {
    id: root

    property real progress: 0
    property real barHeight: 6

    implicitHeight: barHeight
    radius: barHeight / 2
    color: Theme.surfaceContainerHighest

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: parent.width * Math.max(0, Math.min(1, root.progress))
        radius: barHeight / 2
        color: Theme.primary

        Behavior on width {
            NumberAnimation {
                duration: Theme.shorterDuration
                easing.type: Theme.standardEasing
            }
        }
    }
}