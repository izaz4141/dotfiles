import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property Item target
    property string text: ""
    property string side: ""
    property bool multiLine: false
    property real maxWidth: 500

    Connections {
        target: root.target
        function onHoveredChanged() {
            if (root.target.hovered) {
                if (root.text)
                    tooltipDelay.restart();
            } else {
                tooltipDelay.stop();
                tooltip.hide();
            }
        }
    }

    Timer {
        id: tooltipDelay
        interval: 400
        onTriggered: tooltip.show(root.text, root.target, 0, 0, root.side)
    }

    DankTooltipV2 {
        id: tooltip
        multiLine: root.multiLine
        maxWidth: root.maxWidth
    }
}