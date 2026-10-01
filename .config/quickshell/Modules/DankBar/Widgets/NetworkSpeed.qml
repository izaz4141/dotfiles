import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null

    property string selectedInterface: widgetData?.selectedInterface || "all"
    property int updateInterval: widgetData?.updateInterval || 1000
    property bool showIcon: widgetData?.showIcon !== false
    property bool showLabels: widgetData?.showLabels !== false
    property bool compactMode: widgetData?.compactMode || false
    property int unitPrecision: widgetData?.unitPrecision ?? 1
    property int hideThreshold: widgetData?.hideThreshold ?? 0

    readonly property bool aboveThreshold: {
        const speeds = getCurrentSpeeds();
        const thresholdBytes = hideThreshold * 1024;
        return hideThreshold <= 0 || speeds.rx >= thresholdBytes || speeds.tx >= thresholdBytes;
    }

    opacity: aboveThreshold ? 1 : 0

    states: [
        State {
            name: "hidden_horizontal"
            when: !aboveThreshold && !isVerticalOrientation
            PropertyChanges {
                target: root
                width: 0
            }
        },
        State {
            name: "hidden_vertical"
            when: !aboveThreshold && isVerticalOrientation
            PropertyChanges {
                target: root
                height: 0
            }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation {
                properties: "width,height"
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
    ]

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

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
        const speeds = NetworkSpeedService.networkInterfaceSpeeds;
        if (speeds && speeds[ifaceName]) {
            return { rx: speeds[ifaceName].rxSpeed, tx: speeds[ifaceName].txSpeed };
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

    function getNetworkIconName() {
        if (NetworkService.wifiToggling)
            return "sync";
        switch (NetworkService.networkStatus) {
        case "ethernet":
            return "lan";
        case "vpn":
            return NetworkService.ethernetConnected ? "lan" : NetworkService.wifiSignalIcon;
        default:
            return NetworkService.wifiSignalIcon;
        }
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
                    name: root.getNetworkIconName()
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
                    name: root.getNetworkIconName()
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