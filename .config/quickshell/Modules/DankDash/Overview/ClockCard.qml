import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets

Card {
    id: root

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingS

        ColumnLayout {
            spacing: 0
            anchors.horizontalCenter: parent.horizontalCenter

            StyledText {
                text: {
                    if (SettingsData.use24HourClock) {
                        return String(systemClock?.date?.getHours()).padStart(2, '0')
                    } else {
                        const hours = systemClock?.date?.getHours()
                        const display = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours
                        return String(display).padStart(2, '0')
                    }
                }
                font.pixelSize: 48
                color: Theme.primary
                font.weight: Font.Medium
                width: 56
                Layout.alignment: Qt.AlignHCenter
            }

            StyledText {
                text: "•••"
                color: Theme.primary
                font.weight: Font.Medium
                font.pointSize: 48
                width: 56
                Layout.alignment: Qt.AlignHCenter
            }

            StyledText {
                text: String(systemClock?.date?.getMinutes()).padStart(2, '0')
                font.pixelSize: 48
                color: Theme.primary
                font.weight: Font.Medium
                width: 56
                Layout.alignment: Qt.AlignHCenter
            }
            
        }
        
        
        StyledText {
            text: systemClock?.date?.toLocaleDateString(Qt.locale(), "MMM dd")
            font.pixelSize: Theme.fontSizeSmall
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }
}