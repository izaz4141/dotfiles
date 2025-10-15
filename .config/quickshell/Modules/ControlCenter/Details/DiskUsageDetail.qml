import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string currentMountPath: "/"
    property string instanceId: ""

    signal mountPathChanged(string newMountPath)

    implicitHeight: diskContent.height + Theme.spacingM
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0

    Component.onCompleted: {
        MoboService.refCount++
    }

    Component.onDestruction: {
        MoboService.refCount--
    }

    DankFlickable {
        id: diskContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        contentHeight: diskColumn.height
        clip: true

        Column {
            id: diskColumn
            width: parent.width
            spacing: Theme.spacingS

            Item {
                width: parent.width
                height: 100
                visible: !MoboService.storagePerc

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM

                    DankIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: MoboService.storagePerc ? "storage" : "error"
                        size: 32
                        color: MoboService.storagePerc ? Theme.primary : Theme.error
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: MoboService.storagePerc ? "No disk data available" : "dgop not available"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Repeater {
                model: MoboService.storageMap|| []
                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 80
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHighest
                    border.color: modelData.device === currentMountPath ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: modelData.device === currentMountPath ? 2 : 0

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            DankIcon {
                                name: "storage"
                                size: Theme.iconSize
                                color: {
                                    const percent = modelData.percent || 0
                                    if (percent > 0.9) return Theme.error
                                    if (percent > 0.75) return Theme.warning
                                    return modelData.mountPoint === currentMountPath ? Theme.primary : Theme.surfaceText
                                }
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: {
                                    const percent = modelData.percent * 100 || 0
                                    return percent.toFixed(0) + "%"
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.parent.width - parent.parent.anchors.leftMargin - parent.spacing - 50 - Theme.spacingM

                            StyledText {
                                text: modelData.device === "/" ? "Root Filesystem" : modelData.device
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: modelData.mountPoint === currentMountPath ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            StyledText {
                                text: modelData.mountPoint
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            StyledText {
                                text: `${MoboService.formatKib(modelData.used) || "?"} / ${MoboService.formatKib(modelData.total) || "?"}`
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            currentMountPath = modelData.device
                            mountPathChanged(modelData.device)
                        }
                    }

                }
            }
        }
    }
}