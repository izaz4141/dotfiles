import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 1024)
            return bytesPerSec.toFixed(0) + " B/s";
        if (bytesPerSec < 1024 * 1024)
            return (bytesPerSec / 1024).toFixed(1) + " KB/s";
        if (bytesPerSec < 1024 * 1024 * 1024)
            return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s";
        return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(2) + " GB/s";
    }

    function formatSize(bytes) {
        if (bytes <= 0)
            return "";
        if (bytes < 1024 * 1024 * 1024)
            return Math.round(bytes / (1024 * 1024)) + " MB";
        if (bytes < 1024 * 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
        return (bytes / (1024 * 1024 * 1024 * 1024)).toFixed(2) + " TB";
    }

    Component.onCompleted: {
        SysMonitorService.addRef(["disk", "diskmounts"]);
    }

    Component.onDestruction: {
        SysMonitorService.removeRef(["disk", "diskmounts"]);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingM

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingXL

                Column {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXS

                    Row {
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "storage"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Disk I/O", "disk io header in system monitor")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: Theme.spacingL

                        Row {
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Read:", "disk read label")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: root.formatSpeed(SysMonitorService.diskReadRate)
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                font.weight: Font.Bold
                                color: Theme.primary
                            }
                        }

                        Row {
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Write:", "disk write label")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: root.formatSpeed(SysMonitorService.diskWriteRate)
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                font.weight: Font.Bold
                                color: Theme.warning
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(190, Math.max(140, root.height * 0.45))
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                Row {
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "storage"
                        size: Theme.iconSize - 2
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Disks", "Disks")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "(" + (SysMonitorService.diskDevices?.length ?? 0) + ")"
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: SettingsData.monoFontFamily
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.outlineLight
                }

                DankListView {
                    id: diskListView

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4

                    model: SysMonitorService.diskDevices

                    delegate: Rectangle {
                        required property var modelData

                        width: diskListView.width
                        height: 60
                        radius: Theme.cornerRadius
                        color: diskMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06) : "transparent"

                        readonly property real busyFraction: (modelData?.busyPercent ?? 0) / 100

                        MouseArea {
                            id: diskMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            spacing: Theme.spacingM

                            Column {
                                Layout.fillWidth: true
                                spacing: Theme.spacingXS

                                Row {
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: modelData?.removable === true ? "usb" : "storage"
                                        size: Theme.iconSize - 4
                                        color: Theme.surfaceText
                                        opacity: 0.8
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: modelData?.name ?? ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: SettingsData.monoFontFamily
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: modelData?.model ?? ""
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Row {
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: root.formatSize(modelData?.sizeBytes ?? 0)
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: "•"
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: modelData?.rotational === true ? "HDD" : "SSD"
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }

                            Column {
                                Layout.preferredWidth: 200
                                spacing: Theme.spacingXS

                                Rectangle {
                                    width: parent.width
                                    height: 8
                                    radius: 4
                                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)

                                    Rectangle {
                                        width: parent.width * busyFraction
                                        height: parent.height
                                        radius: 4
                                        color: {
                                            if (busyFraction > 0.8)
                                                return Theme.error;
                                            if (busyFraction > 0.5)
                                                return Theme.warning;
                                            return Theme.primary;
                                        }

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: Theme.shortDuration
                                            }
                                        }
                                    }
                                }

                                Row {
                                    anchors.right: parent.right
                                    spacing: Theme.spacingS

                                    Row {
                                        spacing: 2

                                        StyledText {
                                            width: 10
                                            text: "R"
                                            horizontalAlignment: Text.AlignRight
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            font.family: SettingsData.monoFontFamily
                                            font.weight: Font.Bold
                                            color: Theme.primary
                                            opacity: 0.7
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: root.formatSpeed(modelData?.readRate ?? 0)
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            font.family: SettingsData.monoFontFamily
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Row {
                                        spacing: 2

                                        StyledText {
                                            width: 10
                                            text: "W"
                                            horizontalAlignment: Text.AlignRight
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            font.family: SettingsData.monoFontFamily
                                            font.weight: Font.Bold
                                            color: Theme.warning
                                            opacity: 0.7
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: root.formatSpeed(modelData?.writeRate ?? 0)
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            font.family: SettingsData.monoFontFamily
                                            color: Theme.warning
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            StyledText {
                                Layout.preferredWidth: 50
                                text: (modelData?.busyPercent ?? 0) + "%"
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                font.weight: Font.Bold
                                color: {
                                    if (busyFraction > 0.8)
                                        return Theme.error;
                                    if (busyFraction > 0.5)
                                        return Theme.warning;
                                    return Theme.surfaceText;
                                }
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 300
                        height: 80
                        radius: Theme.cornerRadius
                        color: "transparent"
                        visible: SysMonitorService.diskDevices.length === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "storage"
                                size: 32
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: I18n.tr("No disk data", "No disk data")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                Row {
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "folder"
                        size: Theme.iconSize - 2
                        color: Theme.secondary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Mount Points", "mount points header in system monitor")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.outlineLight
                }

                DankListView {
                    id: mountListView

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4

                    model: SysMonitorService.diskMounts

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: mountListView.width
                        height: 60
                        radius: Theme.cornerRadius
                        color: mountMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06) : "transparent"

                        readonly property real usedPct: {
                            const pctStr = modelData?.percent ?? "0%";
                            return parseFloat(pctStr.replace("%", "")) / 100;
                        }

                        MouseArea {
                            id: mountMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            spacing: Theme.spacingM

                            Column {
                                Layout.fillWidth: true
                                spacing: Theme.spacingXS

                                Row {
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: {
                                            const mp = modelData?.mount ?? "";
                                            if (mp === "/")
                                                return "home";
                                            if (mp === "/home")
                                                return "person";
                                            if (mp.includes("boot"))
                                                return "memory";
                                            if (mp.includes("media") || mp.includes("mnt"))
                                                return "usb";
                                            return "folder";
                                        }
                                        size: Theme.iconSize - 4
                                        color: Theme.surfaceText
                                        opacity: 0.8
                                    }

                                    StyledText {
                                        text: modelData?.mount ?? ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: SettingsData.monoFontFamily
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }
                                }

                                Row {
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: modelData?.device ?? ""
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: "•"
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: modelData?.fstype ?? ""
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }

                            Column {
                                Layout.preferredWidth: 200
                                spacing: Theme.spacingXS

                                Rectangle {
                                    width: parent.width
                                    height: 8
                                    radius: 4
                                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)

                                    Rectangle {
                                        width: parent.width * Math.min(1, parent.parent.parent.parent.usedPct)
                                        height: parent.height
                                        radius: 4
                                        color: {
                                            const pct = parent.parent.parent.parent.usedPct;
                                            if (pct > 0.95)
                                                return Theme.error;
                                            if (pct > 0.85)
                                                return Theme.warning;
                                            return Theme.primary;
                                        }

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: Theme.shortDuration
                                            }
                                        }
                                    }
                                }

                                Row {
                                    anchors.right: parent.right
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: modelData?.usedLabel ?? ""
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: "/"
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: modelData?.sizeLabel ?? ""
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }

                            StyledText {
                                Layout.preferredWidth: 50
                                text: modelData?.percent ?? ""
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                font.weight: Font.Bold
                                color: {
                                    const pct = parent.parent.usedPct;
                                    if (pct > 0.95)
                                        return Theme.error;
                                    if (pct > 0.85)
                                        return Theme.warning;
                                    return Theme.surfaceText;
                                }
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 300
                        height: 80
                        radius: Theme.cornerRadius
                        color: "transparent"
                        visible: SysMonitorService.diskMounts.length === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "storage"
                                size: 32
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: I18n.tr("No mount points found", "empty state in disk mounts list")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
