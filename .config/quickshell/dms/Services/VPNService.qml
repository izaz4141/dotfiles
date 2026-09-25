pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property bool available: NetworkService.vpnAvailable

    property var plugins: []
    property var allExtensions: []
    property bool importing: false
    property string importError: ""

    property var editConfig: null
    property bool configLoading: false

    property bool pluginsLoading: false

    readonly property var lowPriorityCmd: ["nice", "-n", "19", "ionice", "-c3"]

    signal importComplete(string uuid, string name)
    signal configLoaded(var config)
    signal configUpdated
    signal vpnDeleted(string uuid)

    function splitNmcliFields(line) {
        const parts = []
        let cur = ""
        let escape = false
        for (var i = 0; i < line.length; i++) {
            const ch = line[i]
            if (escape) {
                cur += ch
                escape = false
            } else if (ch === '\\') {
                escape = true
            } else if (ch === ':') {
                parts.push(cur)
                cur = ""
            } else {
                cur += ch
            }
        }
        parts.push(cur)
        return parts
    }

    function fetchPlugins() {
        plugins = []
        allExtensions = []
        pluginsLoading = false
    }

    function importVpn(filePath, name = "") {
        if (!root.available || root.importing)
            return
        root.importing = true
        root.importError = ""

        const type = root.detectType(filePath)
        vpnImporter.command = root.lowPriorityCmd.concat(["nmcli", "connection", "import", "type", type, "file", filePath])
        vpnImporter.running = true
    }

    function detectType(filePath) {
        const lower = filePath.toLowerCase()
        if (lower.includes("openvpn") && !lower.endsWith(".conf")) {
            return "openvpn"
        }
        if (lower.endsWith(".ovpn")) {
            return "openvpn"
        }
        return "openvpn"
    }

    Process {
        id: vpnImporter
        property string requestedName: ""
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/\((\S+)\)/) || text.match(/UUID:\s*(\S+)/)
                if (m) {
                    vpnImporter.requestedName = m[1]
                } else {
                    vpnImporter.requestedName = ""
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.importing = false
                root.importError = "Import failed"
                ToastService.showError(I18n.tr("Failed to import VPN"))
                return
            }
            root.importing = false
            ToastService.showInfo(I18n.tr("VPN imported"))
            NetworkService.refreshVpn()
            root.importComplete(vpnImporter.requestedName || "", "")
        }
    }

    function getConfig(uuidOrName) {
        if (!root.available)
            return
        root.configLoading = true
        root.editConfig = null

        vpnConfigFetcher.targetUuid = uuidOrName
        vpnConfigFetcher.command = root.lowPriorityCmd.concat(["nmcli", "-t", "-f", "connection.id,connection.autoconnect,vpn.service-type,vpn.data", "connection", "show", uuidOrName])
        vpnConfigFetcher.running = true
    }

    Process {
        id: vpnConfigFetcher
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = root.splitNmcliFields(text.trim())
                if (parts.length >= 1) {
                    const name = parts[0] || ""
                    const autoconnect = parts[1] === "yes"
                    const serviceType = parts[2] || ""
                    const data = root.parseVpnData(parts[3] || "")
                    const config = {
                        "name": name,
                        "uuid": vpnConfigFetcher.targetUuid,
                        "username": data["username"] || "",
                        "autoconnect": autoconnect,
                        "serviceType": serviceType,
                        "data": data
                    }
                    root.editConfig = config
                    root.configLoading = false
                    root.configLoaded(config)
                }
            }
        }
        onExited: exitCode => {
            root.configLoading = false
            if (exitCode !== 0) {
                ToastService.showError(I18n.tr("Failed to load VPN config"))
            }
        }
        property string targetUuid: ""
    }

    function parseVpnData(raw) {
        const data = {}
        if (!raw) return data
        const entries = raw.split(';')
        for (const entry of entries) {
            const idx = entry.indexOf('=')
            if (idx < 0) continue
            const key = entry.substring(0, idx).trim()
            const value = entry.substring(idx + 1).trim()
            data[key] = value
        }
        return data
    }

    function updateConfig(uuid, updates) {
        if (!root.available)
            return
        const modifyArgs = ["nmcli", "connection", "modify", uuid]
        let changed = false
        if (updates.name !== undefined) {
            modifyArgs.push("connection.id", updates.name)
            changed = true
        }
        if (updates.autoconnect !== undefined) {
            modifyArgs.push("connection.autoconnect", updates.autoconnect ? "yes" : "no")
            changed = true
        }
        if (updates.data !== undefined && typeof updates.data === "object") {
            const entries = []
            for (const key of Object.keys(updates.data)) {
                entries.push(key + " = " + updates.data[key])
            }
            modifyArgs.push("vpn.data", entries.join("; "))
            changed = true
        }
        if (!changed) return

        vpnConfigUpdater.command = root.lowPriorityCmd.concat(modifyArgs)
        vpnConfigUpdater.running = true
    }

    Process {
        id: vpnConfigUpdater
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                ToastService.showError(I18n.tr("Failed to update VPN"))
                return
            }
            ToastService.showInfo(I18n.tr("VPN configuration updated"))
            NetworkService.refreshVpn()
            root.configUpdated()
        }
    }

    function deleteVpn(uuidOrName) {
        if (!root.available)
            return
        vpnDeleter.targetUuid = uuidOrName
        vpnDeleter.command = root.lowPriorityCmd.concat(["nmcli", "connection", "delete", uuidOrName])
        vpnDeleter.running = true
    }

    Process {
        id: vpnDeleter
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                ToastService.showError(I18n.tr("Failed to delete VPN"))
                return
            }
            ToastService.showInfo(I18n.tr("VPN deleted"))
            NetworkService.refreshVpn()
            root.vpnDeleted(vpnDeleter.targetUuid)
        }
        property string targetUuid: ""
    }

    function getFileFilter() {
        return ["*.ovpn", "*.conf"]
    }

    function getExtensionsForPlugin(serviceType) {
        return ["*.conf"]
    }

    function getPluginName(serviceType) {
        if (!serviceType)
            return "VPN"

        const plugin = plugins.find(p => p.serviceType === serviceType)
        if (plugin)
            return plugin.name

        const svc = serviceType.toLowerCase()
        if (svc.includes("openvpn"))
            return "OpenVPN"
        if (svc.includes("wireguard"))
            return "WireGuard"
        if (svc.includes("openconnect"))
            return "OpenConnect"
        if (svc.includes("fortissl") || svc.includes("forti"))
            return "Fortinet"
        if (svc.includes("strongswan"))
            return "IPsec (strongSwan)"
        if (svc.includes("libreswan"))
            return "IPsec (Libreswan)"
        if (svc.includes("l2tp"))
            return "L2TP/IPsec"
        if (svc.includes("pptp"))
            return "PPTP"
        if (svc.includes("vpnc"))
            return "Cisco (vpnc)"
        if (svc.includes("sstp"))
            return "SSTP"

        const parts = serviceType.split('.')
        return parts[parts.length - 1] || "VPN"
    }

    function getVpnTypeFromProfile(profile) {
        if (!profile)
            return "VPN"
        if (profile.type === "wireguard")
            return "WireGuard"
        return getPluginName(profile.serviceType)
    }
}
