import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property string selectedInterface: widgetData?.selectedInterface || "all"
    property int updateInterval: widgetData?.updateInterval || 1000
    property bool showIcon: widgetData?.showIcon !== false
    property bool showLabels: widgetData?.showLabels !== false
    property bool compactMode: widgetData?.compactMode || false
    property int unitPrecision: widgetData?.unitPrecision ?? 1

    function formatNetworkSpeed(bytesPerSec) {
        if (bytesPerSec < 1024) {
            return bytesPerSec.toFixed(unitPrecision) + " B/s"
        } else if (bytesPerSec < 1024 * 1024) {
            return (bytesPerSec / 1024).toFixed(unitPrecision) + " KB/s"
        } else if (bytesPerSec < 1024 * 1024 * 1024) {
            return (bytesPerSec / (1024 * 1024)).toFixed(unitPrecision) + " MB/s"
        } else {
            return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(unitPrecision) + " GB/s"
        }
    }

    function getInterfaceSpeed(ifaceName) {
        if (!NetworkSpeedService.networkInterfaces)
            return { rx: 0, tx: 0 };

        for (const iface of NetworkSpeedService.networkInterfaces) {
            if (iface.name === ifaceName) {
                return { rx: iface.rxBytes, tx: iface.txBytes };
            }
        }
        return { rx: 0, tx: 0 };
    }

    function getCurrentSpeeds() {
        if (selectedInterface === "all" || !selectedInterface) {
            return {
                rx: NetworkSpeedService.downloadSpeed,
                tx: NetworkSpeedService.uploadSpeed
            };
        } else {
            return getInterfaceSpeed(selectedInterface);
        }
    }

    Component.onCompleted: {
        NetworkSpeedService.addRef(["network"]);
        if (updateInterval !== NetworkSpeedService.updateInterval) {
            NetworkSpeedService.updateInterval = updateInterval;
        }
    }
    Component.onDestruction: {
        NetworkSpeedService.removeRef(["network"]);
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : contentRow.implicitWidth
            implicitHeight: root.isVerticalOrientation ? contentColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: contentColumn
                anchors.centerIn: parent
                spacing: 2
                visible: root.isVerticalOrientation

                DankIcon {
                    name: "network_check"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showIcon
                }

                StyledText {
                    text: {
                        const speeds = root.getCurrentSpeeds();
                        const rate = speeds.rx;
                        if (rate < 1024) return rate.toFixed(root.unitPrecision)
                        if (rate < 1024 * 1024) return (rate / 1024).toFixed(root.unitPrecision) + "K"
                        return (rate / (1024 * 1024)).toFixed(root.unitPrecision) + "M"
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.info
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showLabels
                }

                StyledText {
                    text: {
                        const speeds = root.getCurrentSpeeds();
                        const rate = speeds.tx;
                        if (rate < 1024) return rate.toFixed(root.unitPrecision)
                        if (rate < 1024 * 1024) return (rate / 1024).toFixed(root.unitPrecision) + "K"
                        return (rate / (1024 * 1024)).toFixed(root.unitPrecision) + "M"
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.error
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showLabels
                }
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: Theme.spacingS
                visible: !root.isVerticalOrientation

                DankIcon {
                    name: "network_check"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showIcon
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    visible: root.showLabels

                    StyledText {
                        text: "↓"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.info
                    }

                    StyledText {
                        text: {
                            const speeds = root.getCurrentSpeeds();
                            return speeds.rx > 0 ? root.formatNetworkSpeed(speeds.rx) : "0 B/s"
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap

                        StyledTextMetrics {
                            id: rxBaseline
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                            text: "88.8 MB/s"
                        }

                        width: Math.max(rxBaseline.width, paintedWidth)
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    visible: root.showLabels && !root.compactMode

                    StyledText {
                        text: "↑"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.error
                    }

                    StyledText {
                        text: {
                            const speeds = root.getCurrentSpeeds();
                            return speeds.tx > 0 ? root.formatNetworkSpeed(speeds.tx) : "0 B/s"
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap

                        StyledTextMetrics {
                            id: txBaseline
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                            text: "88.8 MB/s"
                        }

                        width: Math.max(txBaseline.width, paintedWidth)
                    }
                }
            }
        }
    }
}