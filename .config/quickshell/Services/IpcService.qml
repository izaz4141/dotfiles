import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import qs.Common

Singleton {
    id: root
    IpcHandler {
        target: "dash"

        function toggle() {
            dankDashPopoutLoader.active = true
            if (dankDashPopoutLoader.item) {
                dankDashPopoutLoader.item.dashVisible = !dankDashPopoutLoader.item.dashVisible
                dankDashPopoutLoader.item.currentTabIndex = 0
            }
        }
    }

    IpcHandler {
        target: "cc"

        function toggle() {
            controlCenterLoader.active = true
            if (!controlCenterLoader.item) {
                return
            }
            
            const screen = ScreenUtils.focusedScreen()
            controlCenterLoader.item.triggerScreen = screen
            controlCenterLoader.item.toggle()
            if (controlCenterLoader.item.shouldBeVisible && NetworkService.wifiEnabled) {
                NetworkService.scanWifi()
            }
        }
    }
}