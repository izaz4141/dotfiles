import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

FocusScope {
    id: root

    property string digits: secondsToDigits(ClockService.timerDuration)
    property int inputCount: 0
    readonly property bool idle: !ClockService.timerRunning && !ClockService.timerPaused
    readonly property int editedSeconds: parseDigits(digits)

    function secondsToDigits(sec) {
        const hh = Math.floor(sec / 3600).toString().padStart(2, "0");
        const mm = Math.floor(sec / 60) % 60;
        const ss = sec % 60;
        return `${hh}${mm.toString().padStart(2, "0")}${ss.toString().padStart(2, "0")}`;
    }

    function parseDigits(d) {
        const s = (d || "0").padStart(6, "0");
        return (parseInt(s.slice(0, 2)) * 3600) + (parseInt(s.slice(2, 4)) * 60) + parseInt(s.slice(4, 6));
    }

    function isValidDigits(d) {
        const s = d.padStart(6, "0");
        return parseInt(s.slice(0, 2)) <= 99 && parseInt(s.slice(2, 4)) < 60 && parseInt(s.slice(4, 6)) < 60;
    }

    function appendStroke(stroke) {
        if (!root.idle || ClockService.timerRinging) return;
        if (root.inputCount + stroke.length > 6) return;
        const next = (digits + stroke).slice(-6);
        if (isValidDigits(next)) {
            digits = next;
            inputCount += stroke.length;
        }
    }

    function backspaceStroke() {
        if (!root.idle || ClockService.timerRinging) return;
        if (inputCount <= 0) return;
        digits = digits.slice(0, -1).padStart(6, "0");
        inputCount = Math.max(0, inputCount - 1);
    }

    function formatHMSS(sec) {
        const hh = Math.floor(sec / 3600).toString().padStart(2, "0");
        const mm = Math.floor(sec / 60) % 60;
        const ss = sec % 60;
        return `${hh}:${mm.toString().padStart(2, "0")}:${ss.toString().padStart(2, "0")}`;
    }

    Component {
        id: numpadKey

        Rectangle {
            id: keyItem
            required property var modelData

            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property string label: modelData === "backspace" ? "" : modelData
            readonly property string icon: modelData === "backspace" ? "backspace" : ""

            width: 96
            height: 46
            radius: Theme.cornerRadius
            color: mouseArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerHighest

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shorterDuration
                    easing.type: Theme.standardEasing
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: keyItem.label
                font.pixelSize: Theme.fontSizeXLarge * 1.3
                font.weight: Font.Light
                color: Theme.surfaceText
                visible: keyItem.icon === ""
            }

            DankIcon {
                anchors.centerIn: parent
                name: keyItem.icon
                size: Theme.iconSize
                color: Theme.surfaceText
                visible: keyItem.icon !== ""
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: keyItem.modelData === "backspace" ? root.backspaceStroke() : root.appendStroke(keyItem.modelData)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: ClockService.timerRinging ? 180 : 110

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingM
                visible: !ClockService.timerRinging

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: Theme.fontSizeXLarge * 2.5
                    font.family: SettingsData.monoFontFamily
                    font.weight: Font.Light
                    color: Theme.surfaceText
                    horizontalAlignment: Text.AlignHCenter
                    text: root.idle ? root.formatHMSS(root.editedSeconds) : root.formatHMSS(ClockService.timerRemaining)
                }

                M3WaveProgress {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.85
                    height: 28
                    value: ClockService.timerDuration > 0 ? ClockService.timerRemaining / ClockService.timerDuration : 0
                    isPlaying: ClockService.timerRunning
                    visible: ClockService.timerRunning
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 140
                radius: Theme.cornerRadius
                color: Theme.primaryContainer
                visible: ClockService.timerRinging

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: Theme.fontSizeXLarge * 1.5
                        font.weight: Font.Medium
                        color: Theme.primary
                        text: I18n.tr("Timer finished")
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.primary
                        text: root.formatHMSS(0)
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingM

                        DankButton {
                            text: I18n.tr("Silence")
                            buttonHeight: 36
                            onClicked: ClockService.silenceTimer()
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.idle && !ClockService.timerRinging ? 208 : 0
            visible: root.idle && !ClockService.timerRinging

            GridLayout {
                anchors.fill: parent
                columns: 3
                rowSpacing: Theme.spacingS
                columnSpacing: Theme.spacingS

                Repeater {
                    model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "00", "0", "backspace"]
                    delegate: numpadKey
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 60

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingM

                DankButton {
                    text: ClockService.timerRunning ? I18n.tr("Pause") : ClockService.timerPaused ? I18n.tr("Resume") : I18n.tr("Start")
                    enableScaleAnimation: true
                    enabled: !ClockService.timerRinging && (ClockService.timerRunning || ClockService.timerPaused || root.editedSeconds > 0)
                    onClicked: {
                        if (root.idle && root.editedSeconds <= 0)
                            return;
                        if (root.idle)
                            ClockService.setTimerDuration(root.editedSeconds);
                        ClockService.toggleTimer();
                    }
                }

                DankButton {
                    text: I18n.tr("Reset")
                    backgroundColor: Theme.surfaceContainerHighest
                    textColor: Theme.surfaceText
                    enabled: !root.idle && !ClockService.timerRinging
                    onClicked: {
                        ClockService.resetTimer();
                        digits = secondsToDigits(ClockService.timerDuration);
                        inputCount = 0;
                    }
                }
            }
        }
    }
}