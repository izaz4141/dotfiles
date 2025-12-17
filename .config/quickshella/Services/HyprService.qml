pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import qs.Common

Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels
    readonly property var workspaces: Hyprland.workspaces
    readonly property var monitors: Hyprland.monitors

    readonly property HyprlandToplevel activeToplevel: Hyprland.activeToplevel?.wayland?.activated ? Hyprland.activeToplevel : null
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property int activeWsId: focusedWorkspace?.id ?? 1 

    Process {
        id: keyboard
        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)
                    const mainKeyboard = data.keyboards.find(kb => kb.main === true)
                    SessionData.capsLock = mainKeyboard.capsLock === true
                    SessionData.numLock = mainKeyboard.numLock === true
                } catch(e) {
                    SessionData.capsLock = false
                    SessionData.numLock = false
                    console.log("ERROR DETERMINING KEYBOARD")
                }
            }
        }
    }

    function focusedScreen(): ShellScreen {
        if (!root.focusedMonitor) return Quickshell.screens[0]
        const x = root.focusedMonitor.x
        const y = root.focusedMonitor.y
        for (let s of Quickshell.screens) {
            if (x == s.x &&
                y == s.y ) {
                return s
            }
        }
        return Quickshell.screens[0]
    }

    function keyboardRestart(): void {
        keyboard.running = true
    }
}
