import QtQuick
import qs.Common
import qs.Widgets

DankButton {
    id: root

    required property ListView target

    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottomMargin: 10

    opacity: !target.atYEnd ? 1 : 0
    scale: !target.atYEnd ? 1 : 0.7
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.durations.quick
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Appearance.anim.durations.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }

    width: 30
    height: 30
    minWidth: 0
    horizontalPadding: 0

    radius: Appearance.rounding.full
    backgroundColor: Theme.primary
    textColor: Theme.primaryText
    tooltipText: I18n.tr("Scroll to Bottom", "AiChat interface")

    downAction: () => target.positionViewAtEnd()

    contentItem: Item {
        anchors.centerIn: parent
        width: 24
        height: 24

        DankIcon {
            anchors.centerIn: parent
            name: "arrow_downward"
            size: Theme.fontSizeLarge
            color: Theme.primaryText
        }
    }
}