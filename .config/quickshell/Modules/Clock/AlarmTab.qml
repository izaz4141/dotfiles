import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

FocusScope {
    id: root

    property var editing: null
    property int editingHour: 6
    property int editingMinute: 0
    property var editingDays: []
    property var dayNames: [
        I18n.tr("Mon"), I18n.tr("Tue"), I18n.tr("Wed"), I18n.tr("Thu"), I18n.tr("Fri"), I18n.tr("Sat"), I18n.tr("Sun")
    ]
    property var sortedAlarms: []

    function resortAlarms() {
        sortedAlarms = Array.from(ClockService.alarms || []).sort((a, b) => {
            if (a.enabled !== b.enabled) return a.enabled ? -1 : 1;
            return (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute);
        });
    }

    Component.onCompleted: root.resortAlarms()

    Connections {
        target: ClockService
        function onAlarmsChanged() { root.resortAlarms() }
    }

    function prepareNewAlarm() {
        editingHour = 6;
        editingMinute = 0;
        editingDays = [];
        labelField.text = "";
        editing = {};
    }

    function prepareEditAlarm(alarm) {
        if (!alarm) return;
        editing = alarm;
        editingHour = alarm.hour;
        editingMinute = alarm.minute;
        editingDays = (alarm.days || []).map(day => root.dayIndexToName(day));
        labelField.text = alarm.label || "";
    }

    function saveAlarm() {
        const dayIndices = editingDays.length
            ? editingDays.map(name => root.dayNames.indexOf(name))
            : [];
        if (editing && editing.id !== undefined && editing.id !== null)
            ClockService.updateAlarm(editing.id, { hour: editingHour, minute: editingMinute, label: labelField.text, days: dayIndices });
        else
            ClockService.addAlarm(editingHour, editingMinute, labelField.text, dayIndices);
        editing = null;
    }

    function dayIndexToName(day) {
        if (typeof day === "number")
            return root.dayNames[day];
        return day;
    }

    function describeDays(days, label) {
        const parts = [];
        if (label && label !== "")
            parts.push(label);
        if (!days || days.length === 0)
            parts.push(I18n.tr("Once"));
        else if (days.length === 7)
            parts.push(I18n.tr("Every day"));
        else
            parts.push(days.map(d => dayIndexToName(d)).join(" "));
        return parts.join(" · ");
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: ClockService.ringingAlarmIndex >= 0 ? 150 : 0
            visible: ClockService.ringingAlarmIndex >= 0

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: Theme.primaryContainer

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: Theme.fontSizeXLarge * 1.5
                        font.weight: Font.Medium
                        color: Theme.primary
                        text: {
                            const a = ClockService.ringingAlarm;
                            if (!a) return "";
                            return `${a.hour.toString().padStart(2, "0")}:${a.minute.toString().padStart(2, "0")}`;
                        }
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.primary
                        text: ClockService.ringingAlarm?.label || I18n.tr("Alarm")
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingM

                        DankButton {
                            text: I18n.tr("Snooze")
                            backgroundColor: Theme.surfaceContainerHighest
                            textColor: Theme.surfaceText
                            buttonHeight: 36
                            onClicked: ClockService.snoozeAlarm()
                        }

                        DankButton {
                            text: I18n.tr("Dismiss")
                            buttonHeight: 36
                            onClicked: ClockService.dismissRingingAlarm()
                        }
                    }
                }
            }
        }

        Row {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacingM
            spacing: Theme.spacingS

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Theme.fontSizeXLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
                text: I18n.tr("Alarms")
            }

            Item { width: Theme.spacingXS; height: 1 }
            Item { Layout.fillWidth: true; height: 1 }

            DankButton {
                iconName: "add"
                text: I18n.tr("Add alarm")
                backgroundColor: Theme.surfaceContainerHighest
                textColor: Theme.surfaceText
                buttonHeight: 30
                horizontalPadding: Theme.spacingM
                onClicked: root.prepareNewAlarm()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: editor.visible ? 340 : 0
            visible: true

            Rectangle {
                id: editor
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHighest
                visible: root.editing !== null

                Row {
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingL
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM

                    DankNumberStepper {
                        text: root.editingHour.toString().padStart(2, "0")
                        textSize: Theme.fontSizeXLarge * 1.4
                        incrementEnabled: true
                        decrementEnabled: true
                        onIncrement: () => root.editingHour = (root.editingHour + 1) % 24
                        onDecrement: () => root.editingHour = (root.editingHour + 23) % 24
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: Theme.fontSizeXLarge * 1.4
                        color: Theme.surfaceText
                        text: ":"
                    }

                    DankNumberStepper {
                        text: root.editingMinute.toString().padStart(2, "0")
                        textSize: Theme.fontSizeXLarge * 1.4
                        incrementEnabled: true
                        decrementEnabled: true
                        onIncrement: () => root.editingMinute = (root.editingMinute + 1) % 60
                        onDecrement: () => root.editingMinute = (root.editingMinute + 59) % 60
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingXL * 4
                    spacing: Theme.spacingS

                    StyledText {
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        text: I18n.tr("Repeat")
                    }

                    DankButtonGroup {
                        id: repeatGroup
                        width: parent.width
                        model: root.dayNames
                        multiSelect: true
                        selectionMode: "multi"
                        currentSelection: root.editingDays
                        onCurrentSelectionChanged: root.editingDays = currentSelection
                    }

                    Row {
                        spacing: Theme.spacingS

                        StyledText {
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            text: I18n.tr("Label")
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankTextField {
                            id: labelField
                            width: 150
                            height: 32
                            placeholderText: I18n.tr("Alarm label")
                            text: ""
                        }
                    }
                }

                Row {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.spacingL
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingS

                    DankButton {
                        text: I18n.tr("Cancel")
                        backgroundColor: Theme.surfaceContainerHighest
                        textColor: Theme.surfaceText
                        buttonHeight: 36
                        onClicked: root.editing = null
                    }

                    DankButton {
                        text: I18n.tr("Save")
                        buttonHeight: 36
                        onClicked: root.saveAlarm()
                    }
                }
            }
        }

        DankListView {
            id: alarmList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.spacingXS

            model: root.sortedAlarms

            delegate: Rectangle {
                id: alarmItem
                required property var modelData
                height: 56
                width: alarmList.width
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHighest
                opacity: modelData.enabled ? 1.0 : 0.5

                readonly property bool isRinging: ClockService.ringingAlarm && ClockService.ringingAlarm.id === modelData.id

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.primary
                    visible: alarmItem.isRinging

                    SequentialAnimation on opacity {
                        running: alarmItem.isRinging
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 350; easing.type: Theme.standardEasing }
                        NumberAnimation { to: 0.9; duration: 350; easing.type: Theme.standardEasing }
                    }
                }

                SequentialAnimation on x {
                    running: alarmItem.isRinging
                    loops: Animation.Infinite
                    NumberAnimation { to: 2; duration: 60 }
                    NumberAnimation { to: -2; duration: 60 }
                    NumberAnimation { to: 0; duration: 60 }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: alarmItem.isRinging ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (alarmItem.isRinging)
                            ClockService.dismissRingingAlarm();
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        font.pixelSize: Theme.fontSizeXLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        text: `${modelData.hour.toString().padStart(2, "0")}:${modelData.minute.toString().padStart(2, "0")}`
                    }

                    StyledText {
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        text: root.describeDays(modelData.days, modelData.label)
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    DankToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: modelData.enabled
                        onClicked: ClockService.toggleAlarmEnabled(modelData.id)
                    }

                    DankActionButton {
                        iconName: "edit"
                        iconColor: Theme.surfaceVariantText
                        onClicked: root.prepareEditAlarm(modelData)
                    }

                    DankActionButton {
                        iconName: "delete_outline"
                        iconColor: Theme.surfaceVariantText
                        onClicked: ClockService.removeAlarm(modelData.id)
                    }
                }
            }
        }
    }
}
