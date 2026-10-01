import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: root

    property bool disablePopupTransparency: true
    property int processPid: 0
    property var processInfo: null
    property var groupInfo: null
    property bool gone: false
    property alias shouldBeVisible: root.visible

    signal closingModal

    readonly property string cpu: processInfo ? SysMonitorService.formatCpuUsage(processInfo.cpu ?? 0) : "--"
    readonly property string memory: processInfo
        ? SysMonitorService.formatMemoryUsage(processInfo.memoryKB ?? 0) + " (" + (processInfo.memoryPercent ?? 0).toFixed(1) + "%)"
        : "--"
    readonly property string user: processInfo?.username ?? "--"
    readonly property string ppid: (processInfo?.ppid ?? 0) > 0 ? processInfo.ppid.toString() : "--"
    readonly property string threadCount: (SysMonitorService.processDetails.threads > 0
            ? SysMonitorService.processDetails.threads
            : (processInfo?.threads ?? 0)).toString()
    readonly property string fdCount: (SysMonitorService.processDetails.fds ?? 0) > 0
        ? SysMonitorService.processDetails.fds.toString()
        : "--"
    readonly property string state: SysMonitorService.processDetails.state ?? "--"
    readonly property string cwd: SysMonitorService.processDetails.cwd ?? "--"
    readonly property string executable: SysMonitorService.processDetails.exe ?? "--"
    readonly property string command: SysMonitorService.processDetails.cmdline
        || processInfo?.fullCommand
        || processInfo?.command
        || ""
    readonly property string displayName: processInfo?.command ?? I18n.tr("Process", "fallback process name")
    readonly property string subtitle: {
        if (gone)
            return I18n.tr("Process no longer running", "shown when the inspected process has exited");
        const parts = [];
        if (user !== "--")
            parts.push(user);
        if (groupInfo)
            parts.push(groupInfo.childCount + " " + I18n.tr("Children", "child process count"));
        if (ppid !== "--")
            parts.push(I18n.tr("PPID") + " " + ppid);
        return parts.join("  •  ");
    }

    objectName: "processDetailsModal"
    title: I18n.tr("Process Details", "process details window title")
    minimumSize: Qt.size(460, 420)
    implicitWidth: 520
    implicitHeight: 640
    color: Theme.surfaceContainer
    visible: false

    onClosed: visible = false

    onVisibleChanged: {
        if (!visible)
            closingModal();
    }

    function showFor(pid) {
        processPid = pid;
        processInfo = null;
        groupInfo = null;
        gone = false;
        SysMonitorService.processDetails = {};
        visible = true;
        refresh();
    }

    function hide() {
        visible = false;
    }

    function refresh() {
        if (processPid <= 0)
            return;

        SysMonitorService.requestProcessDetails(processPid);

        const rows = SysMonitorService.groupProcesses(SysMonitorService.allProcesses || []);
        const match = rows.find(row => row.pid === processPid);
        if (match) {
            processInfo = match.process;
            groupInfo = match.isGroup ? match : null;
            gone = false;
            return;
        }

        if (rows.length > 0) {
            groupInfo = null;
            gone = true;
        }
    }

    function copyText(value) {
        ClipboardService.copy(value, exitCode => {
            if (exitCode === 0)
                ToastService.showInfo(I18n.tr("Copied to clipboard"));
        });
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        Keys.onEscapePressed: root.hide()

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                id: header
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Theme.fontSizeMedium * 3.4)

                Rectangle {
                    anchors.fill: parent
                    color: Theme.surfaceContainer
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: (e) => windowControls.tryStartMove(e)
                    onDoubleClicked: windowControls.tryToggleMaximize()
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingL
                    anchors.right: headerButtons.left
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    DankIcon {
                        name: SysMonitorService.getProcessIcon(root.displayName)
                        size: Theme.iconSize
                        color: Theme.primary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            width: parent.width
                            text: root.displayName
                            font.pixelSize: Theme.fontSizeXLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            text: root.subtitle
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.gone ? Theme.error : Theme.surfaceVariantText
                            elide: Text.ElideRight
                            visible: root.subtitle.length > 0
                        }
                    }
                }

                Row {
                    id: headerButtons
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    DankActionButton {
                        visible: windowControls.supported
                        circular: false
                        iconName: root.maximized ? "fullscreen_exit" : "fullscreen"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: windowControls.tryToggleMaximize()
                    }

                    DankActionButton {
                        circular: false
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: root.hide()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.outlineLight
            }

            Item {
                id: emptyState
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.gone

                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingL * 2
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "error_outline"
                        size: Theme.iconSizeLarge
                        color: Theme.outline
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Process no longer running", "shown when the inspected process has exited")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("This process has exited. Details are no longer available.", "detail window empty state after process exit")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }
            }

            DankFlickable {
                id: detailScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Theme.spacingL
                Layout.rightMargin: Theme.spacingL
                Layout.topMargin: Theme.spacingM
                Layout.bottomMargin: Theme.spacingM
                clip: true
                contentHeight: sections.implicitHeight
                visible: !root.gone

                Column {
                    id: sections
                    width: parent.width
                    spacing: Theme.spacingL

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "speed"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Resources", "process details resources section")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    GridLayout {
                        width: parent.width
                        columns: 2
                        rowSpacing: Theme.spacingM
                        columnSpacing: Theme.spacingM

                        StyledRect {
                            Layout.fillWidth: true
                            color: Theme.surfaceContainerHigh
                            Layout.preferredHeight: Math.max(56, Math.round(Theme.fontSizeLarge * 2.6))

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: 2

                                StyledText {
                                    width: parent.width
                                    text: root.cpu
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.primary
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    text: I18n.tr("CPU")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            color: Theme.surfaceContainerHigh
                            Layout.preferredHeight: Math.max(56, Math.round(Theme.fontSizeLarge * 2.6))

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: 2

                                StyledText {
                                    width: parent.width
                                    text: root.memory
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    text: I18n.tr("Memory")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            color: Theme.surfaceContainerHigh
                            Layout.preferredHeight: Math.max(56, Math.round(Theme.fontSizeLarge * 2.6))

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: 2

                                StyledText {
                                    width: parent.width
                                    text: root.groupInfo ? SysMonitorService.formatCpuUsage(root.groupInfo.cpu ?? 0) : "--"
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    text: I18n.tr("Subtree CPU", "cpu total including child processes")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            color: Theme.surfaceContainerHigh
                            Layout.preferredHeight: Math.max(56, Math.round(Theme.fontSizeLarge * 2.6))

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: 2

                                StyledText {
                                    width: parent.width
                                    text: root.groupInfo ? SysMonitorService.formatMemoryUsage(root.groupInfo.memoryKB ?? 0) : "--"
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    text: I18n.tr("Subtree Memory", "memory total including child processes")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "info"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("General")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    GridLayout {
                        width: parent.width
                        columns: 2
                        rowSpacing: Theme.spacingS
                        columnSpacing: Theme.spacingXL

                        DetailRow {
                            label: "PID"
                            value: root.processPid.toString()
                        }
                        DetailRow {
                            label: "PPID"
                            value: root.ppid
                        }
                        DetailRow {
                            label: I18n.tr("User")
                            value: root.user
                        }
                        DetailRow {
                            label: I18n.tr("State")
                            value: root.state
                        }
                        DetailRow {
                            label: I18n.tr("Threads", "process detail thread count")
                            value: root.threadCount
                        }
                        DetailRow {
                            label: I18n.tr("File Descriptors", "open file descriptor count")
                            value: root.fdCount
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "folder"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Paths", "process details paths section")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledRect {
                        width: parent.width
                        implicitHeight: pathColumn.implicitHeight + Theme.spacingM * 2
                        color: Theme.surfaceContainerHigh

                        Column {
                            id: pathColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            PathRow {
                                width: parent.width
                                label: I18n.tr("Working Directory", "process current directory")
                                value: root.cwd
                            }

                            PathRow {
                                width: parent.width
                                label: I18n.tr("Executable", "process binary path")
                                value: root.executable
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "terminal"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Command")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            width: Theme.spacingS
                            height: 1
                        }

                        DankActionButton {
                            id: copyCommandButton
                            circular: false
                            buttonSize: 26
                            iconName: "content_copy"
                            iconSize: Theme.iconSizeSmall
                            backgroundColor: "transparent"
                            iconColor: Theme.surfaceText
                            tooltipText: I18n.tr("Copy command", "copy full command line to clipboard")
                            tooltipSide: "bottom"
                            onClicked: root.copyText(root.command)
                        }
                    }

                    StyledRect {
                        width: parent.width
                        implicitHeight: commandText.implicitHeight + Theme.spacingM * 2
                        color: Theme.surfaceContainerHigh

                        TextEdit {
                            id: commandText
                            width: parent.width - Theme.spacingM * 2
                            x: Theme.spacingM
                            y: Theme.spacingM
                            text: root.command.length > 0 ? root.command : I18n.tr("No command line available", "process details when cmdline is unreadable")
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            color: Theme.surfaceText
                            wrapMode: Text.WrapAnywhere
                            readOnly: true
                            selectByMouse: true
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.background
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.outlineLight
                visible: !root.gone
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: pidCopyButton.implicitHeight + Theme.spacingM * 2
                visible: !root.gone

                Rectangle {
                    anchors.fill: parent
                    color: Theme.surfaceContainer
                }

                RowLayout {
                    id: footer
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    anchors.topMargin: Theme.spacingM
                    anchors.bottomMargin: Theme.spacingM
                    spacing: Theme.spacingS

                    DankButton {
                        id: pidCopyButton
                        text: I18n.tr("Copy PID")
                        iconName: "tag"
                        buttonHeight: 36
                        tooltipText: I18n.tr("Copy process id", "copy process id to clipboard")
                        onClicked: root.copyText(root.processPid.toString())
                    }

                    Item {
                        Layout.fillWidth: true
                        height: 1
                    }

                    DankButton {
                        text: I18n.tr("Kill Process")
                        iconName: "close"
                        backgroundColor: Theme.error
                        textColor: Theme.primaryText
                        buttonHeight: 36
                        onClicked: {
                            SysMonitorService.killProcess(root.processPid, false);
                            root.hide();
                        }
                    }

                    DankButton {
                        text: I18n.tr("Force Kill (SIGKILL)")
                        iconName: "dangerous"
                        backgroundColor: "transparent"
                        textColor: Theme.error
                        buttonHeight: 36
                        enabled: root.processPid > 1000 && !root.gone
                        tooltipText: root.processPid > 1000 ? "" : I18n.tr("Not available for system processes", "sigkill disabled for low pids")
                        onClicked: {
                            SysMonitorService.killProcess(root.processPid, true);
                            root.hide();
                        }
                    }
                }
            }
        }
    }

    component DetailRow: RowLayout {
        id: infoRow

        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: Theme.spacingS

        StyledText {
            text: infoRow.label + ":"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceVariantText
            Layout.preferredWidth: 100
        }

        StyledText {
            text: infoRow.value
            font.pixelSize: Theme.fontSizeSmall
            font.family: SettingsData.monoFontFamily
            color: Theme.surfaceText
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }

    component PathRow: Column {
        id: pathRow

        property string label: ""
        property string value: ""

        width: parent ? parent.width : 0
        spacing: 2

        StyledText {
            width: parent.width
            text: pathRow.label
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceVariantText
        }

        TextEdit {
            width: parent.width
            text: pathRow.value
            font.pixelSize: Theme.fontSizeSmall
            font.family: SettingsData.monoFontFamily
            color: Theme.surfaceText
            wrapMode: Text.WrapAnywhere
            readOnly: true
            selectByMouse: true
            selectionColor: Theme.primary
            selectedTextColor: Theme.background
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }
}
