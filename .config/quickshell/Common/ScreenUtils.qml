pragma Singleton

import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root
    function focusedScreen() {
        const x = Hyprland.focusedMonitor.x
        const y = Hyprland.focusedMonitor.y
        for (let s of Quickshell.screens) {
            if (x == s.x &&
                y == s.y ) {
                return s
            }
        }
        return Quickshell.screens[0]
    }
}