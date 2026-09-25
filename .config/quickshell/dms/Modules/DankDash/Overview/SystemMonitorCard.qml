import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Card {
    id: root

    Component.onCompleted: {
        SysMonitorService.addRef(["cpu", "memory", "system"])
    }
    Component.onDestruction: {
        SysMonitorService.removeRef(["cpu", "memory", "system"])
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
                    height: parent.height * Math.min((SysMonitorService.cpuUsage || 6) / 100, 1)
                    radius: parent.radius
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: {
                        if (SysMonitorService.cpuUsage > 80) return Theme.error
                        if (SysMonitorService.cpuUsage > 60) return Theme.warning
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
                        if (SysMonitorService.cpuUsage > 80) return Theme.error
                        if (SysMonitorService.cpuUsage > 60) return Theme.warning
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
                    height: parent.height * Math.min(Math.max((SysMonitorService.cpuTemperature || 40) / 100, 0), 1)
                    radius: parent.radius
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: {
                        if (SysMonitorService.cpuTemperature > 85) return Theme.error
                        if (SysMonitorService.cpuTemperature > 69) return Theme.warning
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
                        if (SysMonitorService.cpuTemperature > 85) return Theme.error
                        if (SysMonitorService.cpuTemperature > 69) return Theme.warning
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
                    height: parent.height * Math.min((SysMonitorService.memoryUsage || 42) / 100, 1)
                    radius: parent.radius
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: {
                        if (SysMonitorService.memoryUsage > 90) return Theme.error
                        if (SysMonitorService.memoryUsage > 75) return Theme.warning
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
                        if (SysMonitorService.memoryUsage > 90) return Theme.error
                        if (SysMonitorService.memoryUsage > 75) return Theme.warning
                        return Theme.primary
                    }
                }
            }
        }
    }
}
