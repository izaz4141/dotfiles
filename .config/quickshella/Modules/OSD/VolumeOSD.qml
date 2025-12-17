import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    osdWidth: Math.min(300, Screen.width - Theme.spacingM * 2)
    osdHeight: Theme.iconSize + Theme.spacingS * 2
    autoHideInterval: 3000
    enableMouseInteraction: true
    position: "bottom"

    Connections {
        target: AudioService.sink && AudioService.sink.audio ? AudioService.sink.audio : null

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

    Connections {
        target: AudioService

        function onSinkChanged() {
            if (root.shouldBeVisible) {
                root.show()
            }
        }
    }
    property string volumeIcon: {
        const audio = AudioService.sink?.audio;
        if (!audio) return Quickshell.iconPath("audio-volume-muted-symbolic");

        if (audio.muted) {
            return Quickshell.iconPath("audio-volume-muted-symbolic");
        } else if (audio.volume <= 0.3) {
            return Quickshell.iconPath("audio-volume-low-symbolic");
        } else if (audio.volume <= 0.7) {
            return Quickshell.iconPath("audio-volume-medium-symbolic");
        } else {
            return Quickshell.iconPath("audio-volume-high-symbolic");
        }
    }

    content: Item {
        anchors.fill: parent

        Item {
            property int gap: Theme.spacingS

            anchors.centerIn: parent
            width: parent.width - Theme.spacingS * 2
            height: Theme.iconSize

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                x: parent.gap
                anchors.verticalCenter: parent.verticalCenter

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
                        AudioService.toggleMute()
                    }
                    onContainsMouseChanged: {
                        setChildHovered(containsMouse || volumeSlider.containsMouse)
                    }
                }
            }

            DankSlider {
                id: volumeSlider

                readonly property real actualVolumePercent: AudioService.sink && AudioService.sink.audio ? Math.round(AudioService.sink.audio.volume * 100) : 0
                readonly property real displayPercent: actualVolumePercent

                width: parent.width - Theme.iconSize * 2 - parent.gap * 3
                height: 40
                x: parent.gap * 2 + Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter
                minimum: 0
                maximum: 100
                enabled: AudioService.sink && AudioService.sink.audio
                showValue: true
                unit: "%"
                thumbOutlineColor: Theme.surfaceContainer
                valueOverride: displayPercent
                alwaysShowValue: SettingsData.osdAlwaysShowValue

                Component.onCompleted: {
                    if (AudioService.sink && AudioService.sink.audio) {
                        value = Math.min(100, Math.round(AudioService.sink.audio.volume * 100))
                    }
                }

                onSliderValueChanged: newValue => {
                                          if (AudioService.sink && AudioService.sink.audio) {
                                              AudioService.suppressOSD = true
                                              AudioService.sink.audio.volume = newValue / 100
                                              AudioService.suppressOSD = false
                                          }
                                      }

                onContainsMouseChanged: {
                    setChildHovered(containsMouse || muteButton.containsMouse)
                }

                Connections {
                    target: AudioService.sink && AudioService.sink.audio ? AudioService.sink.audio : null

                    function onVolumeChanged() {
                        if (volumeSlider && !volumeSlider.pressed) {
                            volumeSlider.value = Math.min(100, Math.round(AudioService.sink.audio.volume * 100))
                        }
                    }
                }
            }
            StyledText {
                anchors.left: volumeSlider.right
                anchors.leftMargin: parent.gap
                anchors.verticalCenter: parent.verticalCenter
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
