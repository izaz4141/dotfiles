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
    autoHideInterval: 3000
    enableMouseInteraction: true
    position: "right"

    property var brightnessDebounceTimer: Timer {
        property int pendingValue: 0

        interval: {
            const deviceInfo = DisplayService.getCurrentDeviceInfo()
            return (deviceInfo && deviceInfo.class === "ddc") ? 200 : 50
        }
        repeat: false
        onTriggered: {
            DisplayService.setBrightnessInternal(pendingValue, DisplayService.lastIpcDevice)
        }
    }

    Connections {
        target: DisplayService
        function onBrightnessChanged() {
            root.show()
        }
    }

    property string brightnessIcon: {
        if (DisplayService.brightnessLevel <= 30)
            return Quickshell.iconPath("display-brightness-low-symbolic");
        else if (DisplayService.brightnessLevel <= 70)
            return Quickshell.iconPath("display-brightness-medium-symbolic");
        else
            return Quickshell.iconPath("display-brightness-high-symbolic");
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
                    source: root.brightnessIcon
                }

                // DankIcon {
                //     anchors.centerIn: parent
                //     name: {
                //         const deviceInfo = DisplayService.getCurrentDeviceInfo()
                //         if (!deviceInfo || deviceInfo.class === "backlight" || deviceInfo.class === "ddc") {
                //             return "brightness_medium"
                //         } else if (deviceInfo.name.includes("kbd")) {
                //             return "keyboard"
                //         } else {
                //             return "lightbulb"
                //         }
                //     }
                //     size: Theme.iconSize
                //     color: Theme.primary
                // }
            }

            VerticalSlider {
                id: brightnessSlider

                height: parent.height - Theme.iconSize * 2 - parent.gap * 3
                width: 40
                y: parent.gap * 2 + Theme.iconSize
                anchors.horizontalCenter: parent.horizontalCenter
                minimum: 1
                maximum: 100
                enabled: DisplayService.brightnessAvailable
                showValue: true
                unit: "%"
                thumbOutlineColor: Theme.surfaceContainer
                alwaysShowValue: SettingsData.osdAlwaysShowValue

                Component.onCompleted: {
                    if (DisplayService.brightnessAvailable) {
                        value = DisplayService.brightnessLevel
                    }
                }

                onSliderValueChanged: newValue => {
                                          if (DisplayService.brightnessAvailable) {
                                              root.brightnessDebounceTimer.pendingValue = newValue
                                              root.brightnessDebounceTimer.restart()
                                              resetHideTimer()
                                          }
                                      }

                onContainsMouseChanged: {
                    setChildHovered(containsMouse)
                }

                onSliderDragFinished: finalValue => {
                                          if (DisplayService.brightnessAvailable) {
                                              root.brightnessDebounceTimer.stop()
                                              DisplayService.setBrightnessInternal(finalValue, DisplayService.lastIpcDevice)
                                          }
                                      }

                Connections {
                    target: DisplayService

                    function onBrightnessChanged() {
                        if (!brightnessSlider.pressed) {
                            brightnessSlider.value = DisplayService.brightnessLevel
                        }
                    }

                    function onDeviceSwitched() {
                        if (!brightnessSlider.pressed) {
                            brightnessSlider.value = DisplayService.brightnessLevel
                        }
                    }
                }
            }
            StyledText {
                anchors.top: brightnessSlider.bottom
                anchors.topMargin: parent.gap
                anchors.horizontalCenter: parent.horizontalCenter
                text: brightnessSlider.value
                width: Theme.IconSize
                
            }
        }
    }

    onOsdShown: {
        if (DisplayService.brightnessAvailable && contentLoader.item) {
            const slider = contentLoader.item.children[0].children[1]
            if (slider) {
                slider.value = DisplayService.brightnessLevel
            }
        }
    }
}
