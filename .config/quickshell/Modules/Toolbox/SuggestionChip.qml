import QtQuick
import qs.Common
import qs.Widgets

DankButton {
    id: root

    expandOnPress: false
    minWidth: 0
    buttonHeight: 30
    horizontalPadding: 10
    radius: Appearance.rounding.normal
    backgroundColor: Theme.primaryContainer
    toggledBackgroundColor: Theme.primary
    textColor: Theme.primary
    toggledTextColor: Theme.primaryText
    textSize: Theme.fontSizeSmall
    iconSize: Math.round(Appearance.fontSize.small * 1.1)
}