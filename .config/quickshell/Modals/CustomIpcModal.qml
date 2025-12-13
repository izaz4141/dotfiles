import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import qs.Common
import qs.Modals.Common
import qs.Services

DankModal {
    id: customIpc
    
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
            
            const screen = HyprService.focusedScreen()
            controlCenterLoader.item.triggerScreen = screen
            controlCenterLoader.item.toggle()
            if (controlCenterLoader.item.shouldBeVisible && NetworkService.wifiEnabled) {
                NetworkService.scanWifi()
            }
        }
    }
}