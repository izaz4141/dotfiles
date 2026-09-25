import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property string key: ""

    implicitWidth: Math.max(18, keyHintBackground.implicitWidth)
    implicitHeight: 20

    Rectangle {
        id: keyHintBackground
        implicitWidth: keyHintText.implicitWidth + 8
        implicitHeight: keyHintText.implicitHeight + 4
        anchors.centerIn: parent
        radius: Math.max(4, Appearance.rounding.small - 4)
        color: Theme.surfaceContainerHighest
        border.color: Theme.outlineVariant
        border.width: 1

        StyledText {
            id: keyHintText
            anchors.centerIn: parent
            text: root.key
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            horizontalAlignment: Text.AlignHCenter
        }
    }
}