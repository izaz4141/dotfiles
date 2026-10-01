import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Item {
    id: root

    property string icon: "api"
    property string text: ""
    property string tooltipText: ""
    property bool hovered: false

    implicitHeight: rowLayout.implicitHeight + 8
    implicitWidth: rowLayout.implicitWidth + 8

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4

        DankIcon {
            name: root.icon
            size: Theme.fontSizeMedium
            color: Theme.surfaceText
        }

        StyledText {
            text: root.text
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    HoverHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onHoveredChanged: {
            root.hovered = hovered
        }
    }

    DankHoverTooltip {
        target: root
        text: root.tooltipText
        side: "bottom"
    }
}