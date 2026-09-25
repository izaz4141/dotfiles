pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root

    property bool wlrOutputAvailable: false
    property var outputs: []
    property int serial: 0

    signal stateChanged
    signal configurationApplied(bool success, string message)

    Component.onCompleted: {
        Qt.callLater(checkCompositor)
    }

    Connections {
        target: CompositorService

        function onCompositorChanged() {
            checkCompositor()
        }
    }

    Connections {
        target: CompositorService.isNiri ? NiriService : null
        enabled: CompositorService.isNiri

        function onOutputsChanged() {
            if (CompositorService.isNiri && wlrOutputAvailable) {
                fetchNiriOutputs()
            }
        }
    }

    function checkCompositor() {
        const wasAvailable = wlrOutputAvailable

        if (CompositorService.isHyprland || CompositorService.isNiri || CompositorService.isSway) {
            wlrOutputAvailable = true
            if (!wasAvailable) {
                console.info("WlrOutputService: Compositor detected:", CompositorService.compositor)
            }
            requestState()
        } else {
            wlrOutputAvailable = false
        }
    }

    function requestState() {
        if (!wlrOutputAvailable) {
            return
        }

        if (CompositorService.isHyprland) {
            fetchHyprlandOutputs()
        } else if (CompositorService.isNiri) {
            fetchNiriOutputs()
        } else if (CompositorService.isSway) {
            fetchSwayOutputs()
        }
    }

    function fetchHyprlandOutputs() {
        Proc.runCommand("wlr-fetch-outputs", ["hyprctl", "monitors", "-j"], (output, exitCode) => {
            if (exitCode !== 0) {
                console.warn("WlrOutputService: Failed to fetch Hyprland monitors:", exitCode)
                return
            }
            try {
                const data = JSON.parse(output)
                outputs = transformHyprlandOutputs(data)
                serial++
                console.log("WlrOutputService: Updated with", outputs.length, "Hyprland outputs")
                stateChanged()
            } catch (e) {
                console.warn("WlrOutputService: Failed to parse Hyprland monitors:", e)
            }
        }, 0, 5000)
    }

    function parseHyprlandMode(modeStr, index) {
        const match = modeStr.match(/^(\d+)x(\d+)@([\d.]+)Hz$/)
        if (!match) return null
        return {
            "id": String(index),
            "width": parseInt(match[1]),
            "height": parseInt(match[2]),
            "refresh": Math.round(parseFloat(match[3]) * 1000),
            "preferred": index === 0
        }
    }

    function transformHyprlandOutputs(data) {
        if (!Array.isArray(data)) return []

        const result = []
        for (const monitor of data) {
            if (!monitor || !monitor.name) continue

            const modes = []
            const availableModes = monitor.availableModes || []
            for (let i = 0; i < availableModes.length; i++) {
                const mode = parseHyprlandMode(availableModes[i], i)
                if (mode) modes.push(mode)
            }

            if (modes.length === 0 && monitor.width && monitor.height) {
                const refresh = Math.round(monitor.refreshRate || 60000)
                modes.push({
                    "id": "0",
                    "width": monitor.width,
                    "height": monitor.height,
                    "refresh": refresh,
                    "preferred": true
                })
            }

            const currentRefresh = Math.round((monitor.refreshRate || 60000) * 1000)
            const currentModeIndex = modes.findIndex(m =>
                m.width === monitor.width &&
                m.height === monitor.height &&
                Math.abs(m.refresh - currentRefresh) < 1000
            )
            const currentMode = modes[currentModeIndex >= 0 ? currentModeIndex : 0] || null

            result.push({
                "name": monitor.name,
                "enabled": !monitor.disabled,
                "make": monitor.make || "",
                "model": monitor.model || "",
                "serialNumber": monitor.serial || "",
                "modes": modes,
                "currentMode": currentMode,
                "x": monitor.x ?? 0,
                "y": monitor.y ?? 0,
                "scale": monitor.scale ?? 1.0,
                "transform": monitor.transform ?? 0,
                "adaptiveSyncSupported": true,
                "adaptiveSync": monitor.vrr ? 1 : 0
            })
        }

        return result
    }

    function fetchNiriOutputs() {
        if (!NiriService || !NiriService.outputs) {
            console.warn("WlrOutputService: NiriService not available")
            return
        }

        const niriOutputs = NiriService.outputs
        outputs = transformNiriOutputs(niriOutputs)
        serial++
        console.log("WlrOutputService: Updated with", outputs.length, "Niri outputs")
        stateChanged()
    }

    function transformNiriOutputs(data) {
        if (!data || typeof data !== "object") return []

        const result = []
        for (const name in data) {
            const output = data[name]
            if (!output) continue

            const niriModes = output.modes || []
            const modes = niriModes.map((m, i) => ({
                "id": String(i),
                "width": m.width,
                "height": m.height,
                "refresh": m.refresh_rate ?? 60000,
                "preferred": i === 0
            }))

            const currentModeIndex = output.current_mode ?? 0
            const currentMode = modes[currentModeIndex] || null

            const transformMap = {
                "Normal": 0, "90": 1, "180": 2, "270": 3,
                "Flipped": 4, "Flipped90": 5, "Flipped180": 6, "Flipped270": 7
            }

            result.push({
                "name": name,
                "enabled": true,
                "make": output.make || "",
                "model": output.model || "",
                "serialNumber": output.serial || "",
                "modes": modes,
                "currentMode": currentMode,
                "x": output.logical?.x ?? 0,
                "y": output.logical?.y ?? 0,
                "scale": output.logical?.scale ?? 1.0,
                "transform": transformMap[output.logical?.transform] ?? 0,
                "adaptiveSyncSupported": false,
                "adaptiveSync": output.vrr_enabled ? 1 : 0
            })
        }

        return result
    }

    function fetchSwayOutputs() {
        Proc.runCommand("wlr-fetch-outputs", ["swaymsg", "-t", "get_outputs"], (output, exitCode) => {
            if (exitCode !== 0) {
                console.warn("WlrOutputService: Failed to fetch Sway outputs:", exitCode)
                return
            }
            try {
                const data = JSON.parse(output)
                outputs = transformSwayOutputs(data)
                serial++
                console.log("WlrOutputService: Updated with", outputs.length, "Sway outputs")
                stateChanged()
            } catch (e) {
                console.warn("WlrOutputService: Failed to parse Sway outputs:", e)
            }
        }, 0, 5000)
    }

    function transformSwayOutputs(data) {
        if (!Array.isArray(data)) return []

        const transformMap = {
            "normal": 0, "90": 1, "180": 2, "270": 3,
            "flipped": 4, "flipped_90": 5, "flipped_180": 6, "flipped_270": 7
        }

        const result = []
        for (const output of data) {
            if (!output || !output.name) continue

            const modes = (output.modes || []).map((m, i) => ({
                "id": String(i),
                "width": m.width,
                "height": m.height,
                "refresh": m.refresh ?? 60000,
                "preferred": m.preferred ?? false
            }))

            const currentModeIndex = output.current_mode ?? 0
            const currentMode = modes[currentModeIndex] || null

            result.push({
                "name": output.name,
                "enabled": output.active ?? true,
                "make": output.make || "",
                "model": output.model || "",
                "serialNumber": output.serial || "",
                "modes": modes,
                "currentMode": currentMode,
                "x": output.rect?.x ?? 0,
                "y": output.rect?.y ?? 0,
                "scale": output.scale ?? 1.0,
                "transform": transformMap[output.transform] ?? 0,
                "adaptiveSyncSupported": false,
                "adaptiveSync": 0
            })
        }

        return result
    }

    function getOutput(name) {
        for (const output of outputs) {
            if (output.name === name) {
                return output
            }
        }
        return null
    }

    function getEnabledOutputs() {
        return outputs.filter(output => output.enabled)
    }
}
