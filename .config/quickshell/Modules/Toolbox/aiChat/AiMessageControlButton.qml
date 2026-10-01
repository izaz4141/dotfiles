import QtQuick
import qs.Common
import qs.Widgets

DankButton {
    id: button

    property string buttonIcon
    property bool activated: false

    toggled: activated
    expandOnPress: true
    minWidth: 0
    horizontalPadding: 0
    vPadding: 6
    buttonHeight: 36
    width: 30
    height: 30
    radius: Appearance.rounding.small
    backgroundColor: "transparent"
    toggledBackgroundColor: Theme.primary

    contentItem: Item {
        anchors.centerIn: parent
        width: 24
        height: 24

        DankIcon {
            anchors.centerIn: parent
            name: button.buttonIcon
            size: Theme.fontSizeLarge
color: button.activated ? Theme.onPrimary :
            button.enabled ? Theme.surfaceText :
            Theme.withAlpha(Theme.surfaceVariantText, 0.3)

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.durations.quick
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }
    }
}