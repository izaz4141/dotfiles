import QtQuick
import Quickshell
import Quickshell.Io

import qs.Common
import qs.Modals
import qs.Widgets
import qs.Services

import qs.Modals.Common
import qs.Modals.Settings

import qs.Modules.OSD
import qs.Modules.Notifications.Popup
import qs.Modules.Notifications.Center
import qs.Modules.DankDash
import qs.Modules.ControlCenter
import qs.Modules.Lock

ShellRoot {
    id: shellRoot

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: VolumeOSD {
            modelData: item
        }
    }

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: MicVolumeOSD {
            modelData: item
        }
    }

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: BrightnessOSD {
            modelData: item
        }
    }

    Variants {
        model: SettingsData.getFilteredScreens("notifications")

        delegate: NotificationPopupManager {
            modelData: item
        }
    }
    LazyLoader {
        id: notificationCenterLoader

        active: false

        NotificationCenterPopout {
            id: notificationCenter

            Component.onCompleted: {
                PopoutService.notificationCenterPopout = notificationCenter
            }
        }
    }
    NotificationModal {
        id: notificationModal

        Component.onCompleted: {
            PopoutService.notificationModal = notificationModal
        }
    }

    Loader {
        id: dankDashPopoutLoader

        active: false
        asynchronous: true

        sourceComponent: Component {
            DankDashPopout {
                id: dankDashPopout

                Component.onCompleted: {
                    PopoutService.dankDashPopout = dankDashPopout
                }
            }
        }
    }

    LazyLoader {
        id: lockLoader
        active: false

        Lock {
            id: lock
            anchors.fill: parent

            Component.onCompleted: {
                IdleService.lockComponent = lock
            }
        }
    }
    Timer {
        id: lockInitTimer
        interval: 100
        running: true
        repeat: false
        onTriggered: lockLoader.active = true
    }

    LazyLoader {
      id: controlCenterLoader

      active: false

      property var modalRef: colorPickerModal
      property LazyLoader powerModalLoaderRef: powerMenuModalLoader

      ControlCenterPopout {
          id: controlCenterPopout
          colorPickerModal: controlCenterLoader.modalRef
          powerMenuModalLoader: controlCenterLoader.powerModalLoaderRef

          onLockRequested: {
              lockLoader.item.activate()
          }

          Component.onCompleted: {
              PopoutService.controlCenterPopout = controlCenterPopout
          }
      }
    }
    LazyLoader {
      id: powerMenuModalLoader

      active: false

      PowerMenuModal {
            id: powerMenuModal

            onPowerActionRequested: (action, title, message) => {
                                        powerConfirmModalLoader.active = true
                                        if (powerConfirmModalLoader.item) {
                                            powerConfirmModalLoader.item.confirmButtonColor = action === "poweroff" ? Theme.error : action === "reboot" ? Theme.warning : Theme.primary
                                            powerConfirmModalLoader.item.show(title, message, function () {
                                                switch (action) {
                                                case "logout":
                                                    SessionService.logout()
                                                    break
                                                case "suspend":
                                                    SessionService.suspend()
                                                    break
                                                case "hibernate":
                                                    SessionService.hibernate()
                                                    break
                                                case "reboot":
                                                    SessionService.reboot()
                                                    break
                                                case "poweroff":
                                                    SessionService.poweroff()
                                                    break
                                                }
                                            }, function () {})
                                        }
                                    }

            Component.onCompleted: {
                PopoutService.powerMenuModal = powerMenuModal
            }
        }
    }
    LazyLoader {
        id: powerConfirmModalLoader

        active: false

        ConfirmModal {
            id: powerConfirmModal
        }
    }

    SettingsModal {
        id: settingsModal

        Component.onCompleted: {
            PopoutService.settingsModal = settingsModal
        }
    }

    DankColorPickerModal {
        id: colorPickerModal

        Component.onCompleted: {
            PopoutService.colorPickerModal = colorPickerModal
        }
    }

    IpcService {}
}
