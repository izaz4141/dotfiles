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

    signal cpuClicked

    Component.onCompleted: {
        SysMonitorService.addRef(["cpu"]);
    }
    Component.onDestruction: {
        SysMonitorService.removeRef(["cpu"]);
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : cpuContent.implicitWidth
            implicitHeight: root.isVerticalOrientation ? cpuColumn.implicitHeight : cpuContent.implicitHeight

            Column {
                id: cpuColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "memory"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: {
                        if (SysMonitorService.cpuUsage > 80) {
                            return Theme.tempDanger;
                        }

                        if (SysMonitorService.cpuUsage > 60) {
                            return Theme.tempWarning;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (SysMonitorService.cpuUsage === undefined || SysMonitorService.cpuUsage === null || SysMonitorService.cpuUsage === 0) {
                            return "--";
                        }

                        return SysMonitorService.cpuUsage.toFixed(0);
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: cpuContent
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    id: cpuIcon
                    name: "memory"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: {
                        if (SysMonitorService.cpuUsage > 80) {
                            return Theme.tempDanger;
                        }

                        if (SysMonitorService.cpuUsage > 60) {
                            return Theme.tempWarning;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: textBox
                    anchors.verticalCenter: parent.verticalCenter

                    implicitWidth: root.minimumWidth ? Math.max(cpuBaseline.width, cpuCurrent.width) : cpuCurrent.width
                    implicitHeight: cpuText.implicitHeight

                    width: implicitWidth
                    height: implicitHeight

                    StyledTextMetrics {
                        id: cpuBaseline
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        text: "88%"
                    }

                    StyledTextMetrics {
                        id: cpuCurrent
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        text: cpuText.text
                    }

                    StyledText {
                        id: cpuText
                        text: {
                            const v = SysMonitorService.cpuUsage;
                            if (v === undefined || v === null || v === 0) {
                                return "--%";
                            }
                            return v.toFixed(0) + "%";
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor

                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideNone
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
            SysMonitorService.setSortBy("cpu");
            cpuClicked();
        }
    }
}
