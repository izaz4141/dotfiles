import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root
    property string key: ""
    property int pixelSize: 14 // Default size
    property color textColor: Theme.surfaceText

    implicitWidth: keyText.implicitWidth + 10
    implicitHeight: keyText.implicitHeight + 6
    color: Theme.surfaceContainerHighest
    radius: 4
    border.color: Theme.outlineVariant
    border.width: 1

    StyledText {
        id: keyText
        anchors.centerIn: parent
        text: root.key
        font.pixelSize: root.pixelSize
        color: root.textColor
        font.bold: true
    }
}
