import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

FocusScope {
    id: root

    function formatDynamic(ms) {
        const h = Math.floor(ms / 3600000);
        const m = Math.floor(ms / 60000) % 60;
        const s = Math.floor(ms / 1000) % 60;
        const frac = Math.floor(ms % 1000).toString().padStart(3, "0");
        if (h > 0)
            return `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}.${frac}`;
        if (m > 0)
            return `${m}:${s.toString().padStart(2, "0")}.${frac}`;
        return `${s}.${frac}`;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 180

            Column {
                anchors.centerIn: parent
                spacing: 0

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: Theme.fontSizeXLarge * 2.5
                    font.family: SettingsData.monoFontFamily
                    font.weight: Font.Light
                    color: Theme.surfaceText
                    horizontalAlignment: Text.AlignHCenter
                    text: root.formatDynamic(ClockService.stopwatchTime)
                }
            }
        }

        DankListView {
            id: lapsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.spacingXS

            model: ScriptModel {
                values: ClockService.stopwatchLaps.map((v, i, arr) => arr[arr.length - 1 - i])
            }

            delegate: Rectangle {
                id: lapItem
                required property int index
                required property var modelData
                height: 40
                width: lapsList.width
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHighest

                readonly property int originalIndex: ClockService.stopwatchLaps.length - index - 1
                readonly property int previousCumulative: originalIndex > 0 ? ClockService.stopwatchLaps[originalIndex - 1] : 0
                readonly property int segmentTime: modelData - previousCumulative

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    text: `${ClockService.stopwatchLaps.length - lapItem.index}.`
                }

                StyledText {
                    anchors.centerIn: parent
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.primary
                    text: `+${root.formatDynamic(lapItem.segmentTime)}`
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    text: root.formatDynamic(lapItem.modelData)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            spacing: Theme.spacingM

            Item {
                Layout.fillWidth: true

                DankButton {
                    text: I18n.tr("Reset")
                    backgroundColor: Theme.surfaceContainerHighest
                    textColor: Theme.surfaceText
                    visible: ClockService.stopwatchRunning || ClockService.stopwatchTime > 0
                    anchors.centerIn: parent
                    onClicked: ClockService.resetStopwatch()
                }
            }

            Item {
                Layout.fillWidth: true

                DankButton {
                    text: ClockService.stopwatchRunning ? I18n.tr("Pause") : ClockService.stopwatchTime === 0 ? I18n.tr("Start") : I18n.tr("Resume")
                    enableScaleAnimation: true
                    anchors.centerIn: parent
                    onClicked: ClockService.toggleStopwatch()
                }
            }

            Item {
                Layout.fillWidth: true

                DankButton {
                    text: I18n.tr("Lap")
                    backgroundColor: Theme.surfaceContainerHighest
                    textColor: Theme.surfaceText
                    visible: ClockService.stopwatchRunning
                    anchors.centerIn: parent
                    onClicked: ClockService.recordLap()
                }
            }
        }
    }
}