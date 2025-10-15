import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    osdWidth: Theme.iconSize + Theme.spacingS * 2
    osdHeight: Math.min(240, Screen.height - Theme.spacingM * 2)
    autoHideInterval: 2000
    enableMouseInteraction: true
    position: "left"

    Connections {
        target: AudioService.source && AudioService.source.audio ? AudioService.source.audio : null
        function onVolumeChanged() {
            if (!AudioService.suppressOSD) {
                root.show()
            }
        }
        function onMutedChanged() {
            if (!AudioService.suppressOSD) {
                root.show()
            }
        }
    }
    property string volumeIcon: {
        const audio = AudioService.source?.audio;
        if (!audio) return Quickshell.iconPath("microphone-sensitivity-muted-symbolic");

        if (audio.muted) {
            return Quickshell.iconPath("microphone-sensitivity-muted-symbolic");
        } else if (audio.volume <= 0.3) {
            return Quickshell.iconPath("microphone-sensitivity-low-symbolic");
        } else if (audio.volume <= 0.7) {
            return Quickshell.iconPath("microphone-sensitivity-medium-symbolic");
        } else {
            return Quickshell.iconPath("microphone-sensitivity-high-symbolic");
        }
    }

    content: Item {
        anchors.fill: parent

        Item {
            property int gap: Theme.spacingS

            anchors.centerIn: parent
            height: parent.height - Theme.spacingS * 2
            width: 40

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                y: parent.gap
                anchors.horizontalCenter: parent.horizontalCenter

                IconImage {
                    implicitSize: Theme.iconSize
                    anchors.centerIn: parent
                    source: root.volumeIcon
                }

                // DankIcon {
                //     anchors.centerIn: parent
                //     name: AudioService.sink && AudioService.sink.audio && AudioService.sink.audio.muted ? "volume_off" : "volume_up"
                //     size: Theme.iconSize
                //     color: muteButton.containsMouse ? Theme.primary : Theme.surfaceText
                // }

                MouseArea {
                    id: muteButton

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        AudioService.toggleMicMute()
                    }
                    onContainsMouseChanged: {
                        setChildHovered(containsMouse || volumeSlider.containsMouse)
                    }
                }
            }

            VerticalSlider {
                id: volumeSlider

                readonly property real actualVolumePercent: AudioService.source && AudioService.source.audio ? Math.round(AudioService.source.audio.volume * 100) : 0
                readonly property real displayPercent: actualVolumePercent

                height: parent.height - Theme.iconSize * 2 - parent.gap * 3
                width: 40
                y: parent.gap * 2 + Theme.iconSize
                anchors.horizontalCenter: parent.horizontalCenter
                minimum: 0
                maximum: 100
                enabled: AudioService.source && AudioService.source.audio
                showValue: true
                unit: "%"
                thumbOutlineColor: Theme.surfaceContainer
                valueOverride: displayPercent
                alwaysShowValue: SettingsData.osdAlwaysShowValue

                Component.onCompleted: {
                    if (AudioService.source && AudioService.source.audio) {
                        value = Math.min(100, Math.round(AudioService.source.audio.volume * 100))
                    }
                }

                onSliderValueChanged: newValue => {
                                          if (AudioService.source && AudioService.source.audio) {
                                              AudioService.suppressOSD = true
                                              AudioService.setMicVolume(newValue)
                                              AudioService.suppressOSD = false
                                          }
                                      }

                onContainsMouseChanged: {
                    setChildHovered(containsMouse || muteButton.containsMouse)
                }

                Connections {
                    target: AudioService.source && AudioService.source.audio ? AudioService.source.audio : null

                    function onVolumeChanged() {
                        if (volumeSlider && !volumeSlider.pressed) {
                            volumeSlider.value = Math.min(100, Math.round(AudioService.source.audio.volume * 100))
                        }
                    }
                }
            }
            StyledText {
                anchors.top: volumeSlider.bottom
                anchors.topMargin: parent.gap
                anchors.horizontalCenter: parent.horizontalCenter
                text: volumeSlider.actualVolumePercent
                width: Theme.IconSize
                
            }
        }
    }

    onOsdShown: {
        if (AudioService.sink && AudioService.sink.audio && contentLoader.item) {
            const slider = contentLoader.item.children[0].children[1]
            if (slider) {
                slider.value = Math.min(100, Math.round(AudioService.sink.audio.volume * 100))
            }
        }
    }
}
