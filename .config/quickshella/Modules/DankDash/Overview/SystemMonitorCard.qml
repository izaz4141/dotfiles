import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Card {
    id: root

    Component.onCompleted: {
        MoboService.refCount++
    }
    Component.onDestruction: {
        MoboService.refCount--
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingM

        // CPU Bar
        Column {
            width: (parent.width - 2 * Theme.spacingM) / 3
            height: parent.height
            spacing: Theme.spacingS

            Rectangle {
                width: 8
                height: parent.height - Theme.iconSizeSmall - Theme.spacingS
                radius: 4
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)

                Rectangle {
                    width: parent.width
                    height: parent.height * Math.min((MoboService.cpuPerc * 100 || 6) / 100, 1)
                    radius: parent.radius
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: {
                        if (MoboService.cpuPerc * 100 > 80) return Theme.error
                        if (MoboService.cpuPerc * 100 > 60) return Theme.warning
                        return Theme.primary
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.iconSizeSmall

                DankIcon {
                    name: "memory"
                    size: Theme.iconSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    color: {
                        if (MoboService.cpuPerc * 100 > 80) return Theme.error
                        if (MoboService.cpuPerc * 100 > 60) return Theme.warning
                        return Theme.primary
                    }
                }
            }
        }

        // Temperature Bar
        Column {
            width: (parent.width - 2 * Theme.spacingM) / 3
            height: parent.height
            spacing: Theme.spacingS

            Rectangle {
                width: 8
                height: parent.height - Theme.iconSizeSmall - Theme.spacingS
                radius: 4
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)

                Rectangle {
                    width: parent.width
                    height: parent.height * Math.min(Math.max((MoboService.gpuTemp || 20) / 100, 0), 1)
                    radius: parent.radius
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: {
                        if (MoboService.gpuTemp > 85) return Theme.error
                        if (MoboService.gpuTemp > 69) return Theme.warning
                        return Theme.primary
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.iconSizeSmall

                DankIcon {
                    name: "device_thermostat"
                    size: Theme.iconSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    color: {
                        if (MoboService.gpuTemp > 85) return Theme.error
                        if (MoboService.gpuTemp > 69) return Theme.warning
                        return Theme.primary
                    }
                }
            }
        }

        // RAM Bar
        Column {
            width: (parent.width - 2 * Theme.spacingM) / 3
            height: parent.height
            spacing: Theme.spacingS

            Rectangle {
                width: 8
                height: parent.height - Theme.iconSizeSmall - Theme.spacingS
                radius: 4
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)

                Rectangle {
                    width: parent.width
                    height: parent.height * Math.min((MoboService.memPerc * 100 || 42) / 100, 1)
                    radius: parent.radius
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: {
                        if (MoboService.memPerc * 100 > 90) return Theme.error
                        if (MoboService.memPerc * 100 > 75) return Theme.warning
                        return Theme.primary
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.iconSizeSmall

                DankIcon {
                    name: "developer_board"
                    size: Theme.iconSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    color: {
                        if (MoboService.memPerc * 100 > 90) return Theme.error
                        if (MoboService.memPerc * 100 > 75) return Theme.warning
                        return Theme.primary
                    }
                }
            }
        }
    }
}