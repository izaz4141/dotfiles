import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property bool showPercentage: true
    property bool showIcon: true
    property var toggleProcessList
    property var popoutTarget: null
    property var widgetData: null
    property bool minimumWidth: (widgetData && widgetData.minimumWidth !== undefined) ? widgetData.minimumWidth : true
    property bool showSwap: (widgetData && widgetData.showSwap !== undefined) ? widgetData.showSwap : false
    property bool showInGb: (widgetData && widgetData.showInGb !== undefined) ? widgetData.showInGb : false
    readonly property real swapUsage: SysMonitorService.totalSwapKB > 0 ? (SysMonitorService.usedSwapKB / SysMonitorService.totalSwapKB) * 100 : 0

    signal ramClicked

    Component.onCompleted: {
        SysMonitorService.addRef(["memory"]);
    }
    Component.onDestruction: {
        SysMonitorService.removeRef(["memory"]);
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : ramContent.implicitWidth
            implicitHeight: root.isVerticalOrientation ? ramColumn.implicitHeight : ramContent.implicitHeight

            Column {
                id: ramColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "developer_board"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: {
                        if (SysMonitorService.memoryUsage > 90) {
                            return Theme.tempDanger;
                        }

                        if (SysMonitorService.memoryUsage > 75) {
                            return Theme.tempWarning;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (SysMonitorService.memoryUsage === undefined || SysMonitorService.memoryUsage === null || SysMonitorService.memoryUsage === 0) {
                            return "--";
                        }

                        if (root.showInGb) {
                            return (SysMonitorService.usedMemoryMB / 1024).toFixed(1);
                        }

                        return SysMonitorService.memoryUsage.toFixed(0);
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    visible: root.showSwap && SysMonitorService.totalSwapKB > 0
                    text: root.swapUsage.toFixed(0)
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: ramContent
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    id: ramIcon
                    name: "developer_board"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: {
                        if (SysMonitorService.memoryUsage > 90) {
                            return Theme.tempDanger;
                        }

                        if (SysMonitorService.memoryUsage > 75) {
                            return Theme.tempWarning;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: textBox
                    anchors.verticalCenter: parent.verticalCenter

                    implicitWidth: root.minimumWidth ? Math.max(ramBaseline.width, ramText.paintedWidth) : ramText.paintedWidth
                    implicitHeight: ramText.implicitHeight

                    width: implicitWidth
                    height: implicitHeight

                    StyledTextMetrics {
                        id: ramBaseline
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        text: {
                            let baseText = root.showInGb ? "88.8 GB" : "88%";
                            if (!root.showSwap) {
                                return baseText;
                            }
                            if (root.swapUsage < 10) {
                                return baseText + " · 0%";
                            }
                            return baseText + " · 88%";
                        }
                    }

                    StyledText {
                        id: ramText
                        text: {
                            if (SysMonitorService.memoryUsage === undefined || SysMonitorService.memoryUsage === null || SysMonitorService.memoryUsage === 0) {
                                return root.showInGb ? "-- GB" : "--%";
                            }

                            let ramText = "";
                            if (root.showInGb) {
                                ramText = (SysMonitorService.usedMemoryMB / 1024).toFixed(1) + " GB";
                            } else {
                                ramText = SysMonitorService.memoryUsage.toFixed(0) + "%";
                            }

                            if (root.showSwap && SysMonitorService.totalSwapKB > 0) {
                                return ramText + " · " + root.swapUsage.toFixed(0) + "%";
                            }
                            return ramText;
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor

                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {
            root.triggerRipple(this, mouse.x, mouse.y);
            SysMonitorService.setSortBy("memory");
            ramClicked();
        }
    }
}
