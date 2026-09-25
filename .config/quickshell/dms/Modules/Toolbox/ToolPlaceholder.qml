import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Item {
    id: root

    property bool shown: false
    property string icon: ""
    property string title: ""
    property string description: ""

    anchors.fill: parent
    opacity: root.shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.durations.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(root.width - 40, 320)
        spacing: 8

        DankIcon {
            Layout.alignment: Qt.AlignHCenter
            name: root.icon
            size: 56
            color: Theme.surfaceVariantText
        }

        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.DemiBold
            color: Theme.surfaceText
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            Layout.fillWidth: true
            text: root.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.description.length > 0
        }
    }
}