pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Common

Singleton {
    id: root

    property bool networkAvailable: true
    property string backend: "networkmanager"
    property string networkStatus: "disconnected"
    property string primaryConnection: ""

    property string ethernetIP: ""
    property string ethernetInterface: ""
    property bool ethernetConnected: false
    property string ethernetConnectionUuid: ""
    property var ethernetDevices: []

    property var wiredConnections: []

    property string wifiIP: ""
    property string wifiInterface: ""
    property bool wifiConnected: false
    property bool wifiEnabled: Networking.wifiEnabled
    property string wifiConnectionUuid: ""
    property string wifiDevicePath: ""
    property string activeAccessPointPath: ""
    property var wifiDevices: []
    property string wifiDeviceOverride: SessionData.wifiDeviceOverride || ""
    property string connectingDevice: ""

    property string currentWifiSSID: ""
    property int wifiSignalStrength: 0
    property var wifiNetworks: []
    property var savedConnections: []
    property var ssidToConnectionName: ({})
    property var wifiSignalIcon: {
        if (!wifiConnected || networkStatus !== "wifi") {
            return "wifi_off"
        }
        if (wifiSignalStrength >= 50) {
            return "wifi"
        }
        if (wifiSignalStrength >= 25) {
            return "wifi_2_bar"
        }
        return "wifi_1_bar"
    }

    property string userPreference: "auto"
    property bool isConnecting: false
    property string connectingSSID: ""
    property string connectionError: ""

    property bool isScanning: false
    property bool autoScan: false

    property bool wifiAvailable: true
    property bool wifiToggling: false
    property bool changingPreference: false
    property string targetPreference: ""
    property var savedWifiNetworks: []
    property string connectionStatus: ""
    property string lastConnectionError: ""
    property bool passwordDialogShouldReopen: false
    property bool autoRefreshEnabled: false
    property string wifiPassword: ""
    property string forgetSSID: ""

    property var vpnProfiles: []
    property var vpnActive: []
    property bool vpnAvailable: false
    property bool vpnIsBusy: false
    property string lastConnectedVpnUuid: ""
    property string pendingVpnUuid: ""
    property var vpnBusyStartTime: 0

    property alias profiles: root.vpnProfiles
    property alias activeConnections: root.vpnActive
    property var activeUuids: vpnActive.map(v => v.uuid).filter(u => !!u)
    property var activeNames: vpnActive.map(v => v.name).filter(n => !!n)
    property string activeUuid: activeUuids.length > 0 ? activeUuids[0] : ""
    property string activeName: activeNames.length > 0 ? activeNames[0] : ""
    property string activeDevice: vpnActive.length > 0 ? (vpnActive[0].device || "") : ""
    property string activeState: vpnActive.length > 0 ? (vpnActive[0].state || "") : ""
    property bool vpnConnected: activeUuids.length > 0
    property alias available: root.vpnAvailable
    property alias isBusy: root.vpnIsBusy
    property alias connected: root.vpnConnected

    property string networkInfoSSID: ""
    property string networkInfoDetails: ""
    property bool networkInfoLoading: false

    property string networkWiredInfoUUID: ""
    property string networkWiredInfoDetails: ""
    property bool networkWiredInfoLoading: false

    property int refCount: 0
    property bool stateInitialized: false

    property string credentialsToken: ""
    property string credentialsSSID: ""
    property string credentialsSetting: ""
    property var credentialsFields: []
    property var credentialsHints: []
    property string credentialsReason: ""
    property bool credentialsRequested: false

    property string pendingConnectionSSID: ""
    property var pendingConnectionStartTime: 0
    property bool wasConnecting: false

    signal networksUpdated
    signal connectionChanged
    signal credentialsNeeded(string token, string ssid, string setting, var fields, var hints, string reason, string connType, string connName, string vpnService, var fieldsInfo)

    property bool usingLegacy: true
    property var activeService: this

    readonly property string socketPath: Quickshell.env("DMS_SOCKET")

    readonly property var lowPriorityCmd: ["nice", "-n", "19", "ionice", "-c3"]

    readonly property bool nmBackend: Networking.backend === NetworkBackendType.NetworkManager

    property bool _wifiEnabledLast: Networking.wifiEnabled
    property bool _wifiConnectedLast: false
    property bool _ethernetConnectedLast: false
    property string _ssidLast: ""
    property int _signalLast: 0
    property var _devicesSignal: []

    Timer {
        id: autoScanTimer
        interval: 15000
        repeat: true
        running: false
        onTriggered: {
            syncFromNative()
            if (root.autoScan && root.wifiEnabled && !root.isScanning) {
                root.scanWifiNetworks()
            }
        }
    }

    Connections {
        target: Networking
        function onWifiEnabledChanged() {
            root.wifiEnabled = Networking.wifiEnabled
            if (root._wifiEnabledLast !== Networking.wifiEnabled) {
                root._wifiEnabledLast = Networking.wifiEnabled
                root.connectionChanged()
                root.connectionStatus = ""
            }
        }
        function onConnectivityChanged() {
            root.syncFromNative()
        }
    }

    Component.onCompleted: {
        console.info("NetworkService: Initializing (native Quickshell.Networking + nmcli)...")
        root.userPreference = SettingsData.networkPreference || "auto"
        root.lastConnectedVpnUuid = SessionData.vpnLastConnected || ""
        root._wifiEnabledLast = Networking.wifiEnabled
        root.vpnAvailable = root.nmBackend
        syncFromNative()
        refreshFullState()
        refreshVpn()
    }

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

    function forEachDevice(callback) {
        const devices = Networking.devices
        if (!devices) return
        const vals = devices.values
        if (!vals) return
        for (var i = 0; i < vals.length; i++) {
            const d = vals[i]
            if (d) callback(d)
        }
    }

    function findWifiDevices() {
        const result = []
        forEachDevice(d => {
            if (d.type === DeviceType.Wifi) result.push(d)
        })
        return result
    }

    function findWiredDevices() {
        const result = []
        forEachDevice(d => {
            if (d.type === DeviceType.Wired) result.push(d)
        })
        return result
    }

    function findConnectedWifiNetwork() {
        const wifiDevs = findWifiDevices()
        for (const dev of wifiDevs) {
            const nets = dev.networks
            if (!nets || !nets.values) continue
            const vals = nets.values
            for (var i = 0; i < vals.length; i++) {
                if (vals[i].connected) return vals[i]
            }
        }
        return null
    }

    function syncFromNative() {
        const wifiDevs = findWifiDevices()
        const wiredDevs = findWiredDevices()

        const wifiList = []
        const wiredList = []
        for (const d of wifiDevs) wifiList.push({ "name": d.name, "type": "wifi" })
        for (const d of wiredDevs) wiredList.push({ "name": d.name, "type": "ethernet" })
        wifiDevices = wifiList
        ethernetDevices = wiredList
        wifiAvailable = wifiList.length > 0

        const wifiDev = wifiDevs.length > 0 ? wifiDevs[0] : null
        const wiredDev = wiredDevs.length > 0 ? wiredDevs[0] : null

        if (wifiDev && wifiDev.scannerEnabled !== undefined) {
            wifiDev.scannerEnabled = true
        }

        if (root.wifiInterface === "" && wifiDev && wifiDev.name) {
            wifiInterface = wifiDev.name
        }
        if (root.ethernetInterface === "" && wiredDev && wiredDev.name) {
            ethernetInterface = wiredDev.name
        }

        const prevWifiConnected = _wifiConnectedLast
        const prevEthernetConnected = _ethernetConnectedLast
        _wifiConnectedLast = wifiDev ? wifiDev.connected : false
        _ethernetConnectedLast = wiredDev ? wiredDev.connected : false
        wifiConnected = _wifiConnectedLast
        ethernetConnected = _ethernetConnectedLast

        const prevStatus = root.networkStatus
        root.networkStatus = (wiredDev && wiredDev.connected)
            ? "ethernet"
            : ((wifiDev && (wifiDev.connected || root.wifiConnected)) ? "wifi" : "disconnected")
        if (prevStatus !== root.networkStatus) {
            root.connectionChanged()
        }

        const current = findConnectedWifiNetwork()
        const newSSID = current ? current.name : ""
        const newSignal = current ? Math.round(current.signalStrength * 100) : 0
        const changed = (current ? newSSID : "") !== _ssidLast || (current ? newSignal : 0) !== _signalLast ||
                        prevWifiConnected !== _wifiConnectedLast || prevEthernetConnected !== _ethernetConnectedLast

        if (current) {
            _ssidLast = newSSID
            _signalLast = newSignal
            currentWifiSSID = newSSID
            wifiSignalStrength = newSignal
            wifiConnected = true
        } else {
            _ssidLast = currentWifiSSID
            _signalLast = wifiSignalStrength
        }

        if (!wifiConnected) {
            connectionStatus = ""
            if (pendingConnectionSSID && !isConnecting) {
                pendingConnectionSSID = ""
            }
        }

        if (changed) {
            connectionChanged()
        }
        wireSecretsHandlers()
    }

    property var _seenNetworks: []

    function wireSecretsHandlers() {
        const devs = findWifiDevices()
        for (const dev of devs) {
            const nets = dev.networks
            if (!nets || !nets.values) continue
            const vals = nets.values
            for (var i = 0; i < vals.length; i++) {
                const n = vals[i]
                if (!n || _seenNetworks.indexOf(n) !== -1) continue
                _seenNetworks.push(n)
                const obj = n
                obj.connectionFailed.connect(reason => {
                    if (reason === ConnectionFailReason.NoSecrets && obj.name) {
                        root.emitCredentialsNeeded(obj.name)
                    }
                })
            }
        }
    }

    function emitCredentialsNeeded(ssid) {
        root.credentialsToken = "native-" + Date.now()
        root.credentialsSSID = ssid
        root.credentialsSetting = "802-11-wireless-security"
        root.credentialsFields = ["psk"]
        root.credentialsHints = []
        root.credentialsReason = "Credentials required"
        root.credentialsRequested = true
        root.isConnecting = false
        root.connectingSSID = ""
        root.credentialsNeeded(root.credentialsToken, ssid, root.credentialsSetting, ["psk"], [], root.credentialsReason, "802-11-wireless", ssid, "", [])
    }

    function refreshFullState() {
        refreshWifiInterfaceDiscovery()
        refreshPrimaryConnection()
        refreshWifiIp()
        refreshEthernetIp()
        refreshActiveConnections()
        refreshSavedConnections()
        refreshWifiDevicePaths()
        refreshCurrentWifi()
        scanWifiNetworks()
    }

    function refreshWifiInterfaceDiscovery() {
        getWifiInterfaceNmcli.running = true
    }

    Process {
        id: getWifiInterfaceNmcli
        command: root.lowPriorityCmd.concat(["nmcli", "-t", "-f", "TYPE,DEVICE", "device", "status"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let found = ""
                const lines = text.trim().split('\n')
                for (const line of lines) {
                    if (line.startsWith("wifi:")) {
                        const dev = line.substring(5)
                        if (dev && dev.indexOf("p2p-") !== 0) {
                            found = dev
                            break
                        }
                    }
                }
                if (found) {
                    root.wifiInterface = found
                    root.wifiAvailable = true
                    if (root.currentWifiSSID === "" || root.wifiSignalStrength === 0) {
                        refreshCurrentWifi()
                    }
                }
            }
        }
    }

    function refreshPrimaryConnection() {
        primaryConnectionQuery.running = true
    }

    Process {
        id: primaryConnectionQuery
        command: root.lowPriorityCmd.concat(["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", "/org/freedesktop/NetworkManager", "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager", "PrimaryConnection"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/objectpath '([^']+)'/)
                if (match && match[1] !== '/') {
                    root.primaryConnection = match[1]
                    getPrimaryConnectionType.running = true
                } else {
                    root.primaryConnection = ""
                }
            }
        }
    }

    Process {
        id: getPrimaryConnectionType
        command: root.primaryConnection ? root.lowPriorityCmd.concat(["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", root.primaryConnection, "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager.Connection.Active", "Type"]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.connectionChanged()
            }
        }
    }

    function refreshWifiIp() {
        getWifiIP.running = true
    }

    function refreshEthernetIp() {
        getEthernetIP.running = true
    }

    Process {
        id: getWifiIP
        command: root.wifiInterface ? root.lowPriorityCmd.concat(["ip", "-4", "addr", "show", root.wifiInterface]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/inet (\d+\.\d+\.\d+\.\d+)/)
                if (match) {
                    root.wifiIP = match[1]
                } else {
                    root.wifiIP = ""
                }
            }
        }
    }

    Process {
        id: getEthernetIP
        command: root.ethernetInterface ? root.lowPriorityCmd.concat(["ip", "-4", "addr", "show", root.ethernetInterface]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/inet (\d+\.\d+\.\d+\.\d+)/)
                if (match) {
                    root.ethernetIP = match[1]
                } else {
                    root.ethernetIP = ""
                }
            }
        }
    }

    function refreshActiveConnections() {
        getActiveConnections.running = true
    }

    Process {
        id: getActiveConnections
        command: root.lowPriorityCmd.concat(["nmcli", "-t", "-f", "UUID,TYPE,DEVICE,STATE", "connection", "show", "--active"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split('\n')
                for (const line of lines) {
                    const parts = line.split(':')
                    if (parts.length >= 4) {
                        const uuid = parts[0]
                        const type = parts[1]
                        const device = parts[2]
                        const state = parts[3]
                        if (type === "802-3-ethernet" && state === "activated") {
                            root.ethernetConnectionUuid = uuid
                        } else if (type === "802-11-wireless" && state === "activated") {
                            root.wifiConnectionUuid = uuid
                        }
                    }
                }
            }
        }
    }

    function refreshCurrentWifi() {
        getCurrentWifiInfo.running = true
    }

    Process {
        id: getCurrentWifiInfo
        command: root.wifiInterface ? root.lowPriorityCmd.concat(["nmcli", "-t", "-f", "ACTIVE,SIGNAL,SSID", "device", "wifi", "list", "ifname", root.wifiInterface, "--rescan", "no"]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let found = false
                const lines = text.trim().split('\n')
                for (const line of lines) {
                    if (line.startsWith("yes:")) {
                        const rest = line.substring(4)
                        const parts = root.splitNmcliFields(rest)
                        if (parts.length >= 2) {
                            const signal = parseInt(parts[0])
                            const newSignal = isNaN(signal) ? 0 : signal
                            const newSSID = parts[1]
                            if (newSSID !== root.currentWifiSSID || newSignal !== root.wifiSignalStrength) {
                                root.connectionChanged()
                            }
                            root.wifiSignalStrength = newSignal
                            root.currentWifiSSID = newSSID
                            if (parts[1]) {
                                root.wifiConnected = true
                                root.networkStatus = "wifi"
                            }
                            found = true
                        }
                        break
                    }
                }
                if (!found && !root.currentWifiSSID) {
                    if (root.wifiConnectionUuid) {
                        resolveWifiSSID.running = true
                    } else if (root.wifiInterface) {
                        resolveWifiSSIDFromDevice.running = true
                    }
                }
            }
        }
    }

    Process {
        id: resolveWifiSSID
        command: root.wifiConnectionUuid ? root.lowPriorityCmd.concat(["nmcli", "-g", "802-11-wireless.ssid", "connection", "show", "uuid", root.wifiConnectionUuid]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const ssid = text.trim()
                if (ssid && ssid !== root.currentWifiSSID) {
                    root.currentWifiSSID = ssid
                    root.wifiConnected = true
                    root.networkStatus = "wifi"
                    root.connectionChanged()
                } else if (ssid) {
                    root.wifiConnected = true
                    root.networkStatus = "wifi"
                }
            }
        }
    }

    Process {
        id: resolveWifiSSIDFromDevice
        command: root.wifiInterface ? root.lowPriorityCmd.concat(["nmcli", "-t", "-f", "GENERAL.CONNECTION", "device", "show", root.wifiInterface]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.currentWifiSSID) {
                    const name = text.trim()
                    if (name) {
                        root.currentWifiSSID = name
                        root.wifiConnected = true
                        root.networkStatus = "wifi"
                        root.connectionChanged()
                    }
                }
            }
        }
    }

    function refreshWifiDevicePaths() {
        getWifiDevicePath.running = true
        getActiveAccessPoint.running = true
    }

    Process {
        id: getWifiDevicePath
        command: root.wifiInterface ? root.lowPriorityCmd.concat(["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", "/org/freedesktop/NetworkManager", "--method", "org.freedesktop.NetworkManager.GetDeviceByIpIface", root.wifiInterface]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/objectpath '([^']+)'/)
                root.wifiDevicePath = match && match[1] !== '/' ? match[1] : ""
            }
        }
    }

    Process {
        id: getActiveAccessPoint
        command: root.wifiDevicePath ? root.lowPriorityCmd.concat(["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", root.wifiDevicePath, "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.NetworkManager.Device.Wireless", "ActiveAccessPoint"]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/objectpath '([^']+)'/)
                root.activeAccessPointPath = match && match[1] !== '/' ? match[1] : ""
            }
        }
    }

    function refreshSavedConnections() {
        getSavedConnections.running = true
    }

    Process {
        id: getSavedConnections
        command: root.lowPriorityCmd.concat(["bash", "-c", "nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1 | while read name; do ssid=$(nmcli -g 802-11-wireless.ssid connection show \"$name\"); echo \"$ssid:$name\"; done"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const saved = []
                const mapping = {}
                const lines = text.trim().split('\n')

                for (const line of lines) {
                    const parts = line.trim().split(':')
                    if (parts.length >= 2) {
                        const ssid = parts[0]
                        const connectionName = parts[1]
                        if (ssid && ssid.length > 0 && connectionName && connectionName.length > 0) {
                            saved.push({ "ssid": ssid, "saved": true })
                            mapping[ssid] = connectionName
                        }
                    }
                }

                root.savedConnections = saved
                root.savedWifiNetworks = saved
                root.ssidToConnectionName = mapping

                const updated = [...root.wifiNetworks]
                for (const network of updated) {
                    network.saved = saved.some(s => s.ssid === network.ssid)
                }
                root.wifiNetworks = updated
            }
        }
    }

    function scanWifi() {
        if (root.isScanning || !root.wifiEnabled) {
            return
        }
        root.isScanning = true
        root.syncFromNative()
        getWifiNetworks.running = true
        refreshSavedConnections()
    }

    function scanWifiNetworks() {
        if (!root.wifiInterface) {
            root.isScanning = false
            return
        }
        root.syncFromNative()
        getWifiNetworks.running = true
        refreshSavedConnections()
    }

    Process {
        id: getWifiNetworks
        command: root.wifiInterface ? root.lowPriorityCmd.concat(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,BSSID", "dev", "wifi", "list", "ifname", root.wifiInterface]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const networks = []
                const lines = text.trim().split('\n')
                const seen = new Set()

                for (const line of lines) {
                    const parts = root.splitNmcliFields(line)
                    if (parts.length >= 4 && parts[0]) {
                        const ssid = parts[0]
                        if (!seen.has(ssid)) {
                            seen.add(ssid)
                            const signal = parseInt(parts[1]) || 0

                            networks.push({
                                "ssid": ssid,
                                "signal": signal,
                                "secured": parts[2] !== "",
                                "bssid": parts[3],
                                "connected": ssid === root.currentWifiSSID,
                                "saved": false
                            })
                        }
                    }
                }

                networks.sort((a, b) => b.signal - a.signal)
                root.wifiNetworks = networks
                root.isScanning = false

                const saved = root.savedConnections || []
                for (const network of root.wifiNetworks) {
                    network.saved = saved.some(s => s.ssid === network.ssid)
                }

                root.networksUpdated()
                root.connectionChanged()
            }
        }
    }

    function getState() {
        syncFromNative()
        refreshFullState()
    }

    function addRef() {
        refCount++
        if (refCount === 1) {
            startAutoScan()
        }
    }

    function removeRef() {
        refCount = Math.max(0, refCount - 1)
        if (refCount === 0) {
            stopAutoScan()
        }
    }

    function nativeWifiNetwork(ssid) {
        const devs = findWifiDevices()
        for (const dev of devs) {
            const nets = dev.networks
            if (!nets || !nets.values) continue
            const vals = nets.values
            for (var i = 0; i < vals.length; i++) {
                if (vals[i].name === ssid) return vals[i]
            }
        }
        return null
    }

    function connectToWifi(ssid, password = "", username = "", anonymousIdentity = "", domainSuffixMatch = "", isHiddenNetwork = false) {
        if (root.isConnecting) {
            return
        }

        root.isConnecting = true
        root.connectingSSID = ssid
        root.connectionError = ""
        root.connectionStatus = "connecting"
        root.passwordDialogShouldReopen = false

        const net = !isHiddenNetwork ? nativeWifiNetwork(ssid) : null
        if (net) {
            if (password) {
                net.connectWithPsk(password)
            } else {
                net.connect()
            }
        } else {
            const args = ["nmcli", "dev", "wifi", "connect", ssid]
            if (password) {
                args.push("password", password)
            }
            if (isHiddenNetwork) {
                args.push("hidden", "yes")
            }
            wifiConnector.command = root.lowPriorityCmd.concat(args)
            wifiConnector.running = true
            return
        }

        root.pendingConnectionSSID = ssid
        root.pendingConnectionStartTime = Date.now()
        root.wasConnecting = true
        connectionWatchdogTimer.start()
    }

    Timer {
        id: connectionWatchdogTimer
        interval: 1500
        repeat: true
        running: false
        onTriggered: {
            if (!root.isConnecting || !root.pendingConnectionSSID) {
                running = false
                return
            }
            root.syncFromNative()
            if (root.wifiConnected && root.currentWifiSSID === root.pendingConnectionSSID && root.wifiIP) {
                running = false
                root.finishConnect(root.pendingConnectionSSID)
            } else {
                const elapsed = Date.now() - root.pendingConnectionStartTime
                if (elapsed > 30000) {
                    running = false
                    root.failConnect(root.pendingConnectionSSID, "failed")
                }
            }
        }
    }

    function finishConnect(ssid) {
        if (!root.pendingConnectionSSID) return
        const elapsed = Date.now() - root.pendingConnectionStartTime
        console.info("NetworkService: Successfully connected to", ssid, "in", elapsed, "ms")
        ToastService.showInfo(I18n.tr("Connected to %1").arg(ssid))
        root.connectionError = ""
        root.connectionStatus = "connected"
        root.pendingConnectionSSID = ""

        if (root.userPreference === "wifi" || root.userPreference === "auto") {
            setConnectionPriority("wifi")
        }
        root.isConnecting = false
        root.connectingSSID = ""
        refreshFullState()
    }

    function failConnect(ssid, status) {
        root.pendingConnectionSSID = ""
        root.connectionStatus = status
        if (status === "failed") {
            ToastService.showError(I18n.tr("Failed to connect to %1").arg(ssid))
        }
        root.isConnecting = false
        root.connectingSSID = ""
        refreshFullState()
    }

    Process {
        id: wifiConnector
        running: false

        property bool connectionSucceeded: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("successfully")) {
                    wifiConnector.connectionSucceeded = true
                    ToastService.showInfo(`Connected to ${root.connectingSSID}`)
                    root.connectionError = ""
                    root.connectionStatus = "connected"
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.connectionError = text
                root.lastConnectionError = text
                if (!wifiConnector.connectionSucceeded && text.trim() !== "") {
                    if (text.includes("password") || text.includes("authentication")) {
                        root.connectionStatus = "invalid_password"
                        root.passwordDialogShouldReopen = true
                    } else {
                        root.connectionStatus = "failed"
                    }
                }
            }
        }

        onExited: exitCode => {
            if (exitCode === 0 || wifiConnector.connectionSucceeded) {
                if (!wifiConnector.connectionSucceeded) {
                    ToastService.showInfo(`Connected to ${root.connectingSSID}`)
                    root.connectionStatus = "connected"
                }
            } else {
                if (root.connectionStatus === "") {
                    root.connectionStatus = "failed"
                }
                if (root.connectionStatus === "invalid_password") {
                    ToastService.showError(I18n.tr("Invalid password for %1").arg(root.connectingSSID))
                } else if (root.connectionStatus === "failed") {
                    ToastService.showError(I18n.tr("Failed to connect to %1").arg(root.connectingSSID))
                }
            }

            wifiConnector.connectionSucceeded = false
            root.isConnecting = false
            root.connectingSSID = ""
            refreshFullState()
        }
    }

    function disconnectWifi() {
        const dev = findWifiDevices().length > 0 ? findWifiDevices()[0] : null
        if (dev) {
            dev.disconnect()
            currentWifiSSID = ""
            connectionStatus = ""
            ToastService.showInfo(I18n.tr("Disconnected from WiFi"))
            doRefresh()
            return
        }

        if (!root.wifiInterface) return
        wifiDisconnector.command = root.lowPriorityCmd.concat(["nmcli", "dev", "disconnect", root.wifiInterface])
        wifiDisconnector.running = true
    }

    Process {
        id: wifiDisconnector
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showInfo(I18n.tr("Disconnected from WiFi"))
                root.currentWifiSSID = ""
                root.connectionStatus = ""
            }
            root.doRefresh()
        }
    }

    function forgetWifiNetwork(ssid) {
        root.forgetSSID = ssid
        const net = nativeWifiNetwork(ssid)
        if (net) {
            net.forget()
            onForgotSuccess(ssid)
            return
        }
        const connectionName = root.ssidToConnectionName[ssid] || ssid
        networkForgetter.command = root.lowPriorityCmd.concat(["nmcli", "connection", "delete", connectionName])
        networkForgetter.running = true
    }

    function onForgotSuccess(ssid) {
        ToastService.showInfo(I18n.tr("Forgot network %1").arg(ssid))
        root.savedConnections = root.savedConnections.filter(s => s.ssid !== ssid)
        root.savedWifiNetworks = root.savedWifiNetworks.filter(s => s.ssid !== ssid)
        const updated = [...root.wifiNetworks]
        for (const network of updated) {
            if (network.ssid === ssid) {
                network.saved = false
                if (network.connected) {
                    network.connected = false
                    root.currentWifiSSID = ""
                }
            }
        }
        root.wifiNetworks = updated
        root.networksUpdated()
        root.forgetSSID = ""
        root.doRefresh()
    }

    Process {
        id: networkForgetter
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                root.onForgotSuccess(root.forgetSSID)
            } else {
                root.forgetSSID = ""
            }
        }
    }

    function toggleWifiRadio() {
        if (root.wifiToggling) return
        root.wifiToggling = true
        Networking.wifiEnabled = !Networking.wifiEnabled
        root.wifiEnabled = Networking.wifiEnabled
        ToastService.showInfo(Networking.wifiEnabled ? I18n.tr("WiFi enabled") : I18n.tr("WiFi disabled"))
        root.wifiToggling = false
        syncFromNative()
        doRefresh()
    }

    function enableWifiDevice() {
        if (!root.wifiEnabled) {
            Networking.wifiEnabled = true
            root.wifiEnabled = true
            ToastService.showInfo(I18n.tr("WiFi enabled"))
            doRefresh()
            return
        }
        wifiDeviceEnabler.running = true
    }

    Process {
        id: wifiDeviceEnabler
        command: root.lowPriorityCmd.concat(["sh", "-c", "WIFI_DEV=$(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1); if [ -n \"$WIFI_DEV\" ]; then nmcli device connect \"$WIFI_DEV\"; else echo \"No WiFi device found\"; exit 1; fi"])
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showInfo(I18n.tr("WiFi enabled"))
            } else {
                ToastService.showError(I18n.tr("Failed to enable WiFi"))
            }
            root.doRefresh()
        }
    }

    function setNetworkPreference(preference) {
        root.userPreference = preference
        root.changingPreference = true
        root.targetPreference = preference
        SettingsData.set("networkPreference", preference)

        if (preference === "wifi") {
            setConnectionPriority("wifi")
        } else if (preference === "ethernet") {
            setConnectionPriority("ethernet")
        } else {
            root.changingPreference = false
            root.targetPreference = ""
        }
    }

    function setConnectionPriority(type) {
        if (root.changingPreference && type === root.targetPreference) {
            return
        }
        if (type === "wifi") {
            setRouteMetrics.command = root.lowPriorityCmd.concat(["bash", "-c", "nmcli -t -f NAME,TYPE connection show | grep 802-11-wireless | cut -d: -f1 | " + "xargs -I {} bash -c 'nmcli connection modify \"{}\" ipv4.route-metric 50 ipv6.route-metric 50'; " + "nmcli -t -f NAME,TYPE connection show | grep 802-3-ethernet | cut -d: -f1 | " + "xargs -I {} bash -c 'nmcli connection modify \"{}\" ipv4.route-metric 100 ipv6.route-metric 100'"])
        } else if (type === "ethernet") {
            setRouteMetrics.command = root.lowPriorityCmd.concat(["bash", "-c", "nmcli -t -f NAME,TYPE connection show | grep 802-3-ethernet | cut -d: -f1 | " + "xargs -I {} bash -c 'nmcli connection modify \"{}\" ipv4.route-metric 50 ipv6.route-metric 50'; " + "nmcli -t -f NAME,TYPE connection show | grep 802-11-wireless | cut -d: -f1 | " + "xargs -I {} bash -c 'nmcli connection modify \"{}\" ipv4.route-metric 100 ipv6.route-metric 100'"])
        } else {
            return
        }
        setRouteMetrics.running = true
    }

    Process {
        id: setRouteMetrics
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                restartConnections.running = true
            } else {
                root.changingPreference = false
                root.targetPreference = ""
            }
        }
    }

    Process {
        id: restartConnections
        command: root.lowPriorityCmd.concat(["bash", "-c", "nmcli -t -f UUID,TYPE connection show --active | " + "grep -E '802-11-wireless|802-3-ethernet' | cut -d: -f1 | " + "xargs -I {} sh -c 'nmcli connection down {} && nmcli connection up {}'"])
        running: false
        onExited: {
            root.changingPreference = false
            root.targetPreference = ""
            root.doRefresh()
        }
    }

    function connectToWifiAndSetPreference(ssid, password) {
        connectToWifi(ssid, password)
        setNetworkPreference("wifi")
    }

    function toggleNetworkConnection(type) {
        if (type === "ethernet") {
            if (root.ethernetConnected) {
                ethernetDisconnector.running = true
            } else {
                ethernetConnector.running = true
            }
        }
    }

    function disconnectEthernetDevice(deviceName) {
        if (!deviceName) {
            toggleNetworkConnection("ethernet")
            return
        }
        ethernetDevDisconnector.command = root.lowPriorityCmd.concat(["nmcli", "dev", "disconnect", deviceName])
        ethernetDevDisconnector.running = true
    }

    Process {
        id: ethernetDevDisconnector
        running: false
        onExited: exitCode => {
            root.doRefresh()
        }
    }

    Process {
        id: ethernetDisconnector
        command: root.lowPriorityCmd.concat(["sh", "-c", "nmcli device disconnect $(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1)"])
        running: false
        onExited: exitCode => {
            root.doRefresh()
        }
    }

    Process {
        id: ethernetConnector
        command: root.lowPriorityCmd.concat(["sh", "-c", "ETH_DEV=$(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1); if [ -n \"$ETH_DEV\" ]; then nmcli device connect \"$ETH_DEV\"; else echo \"No ethernet device found\"; exit 1; fi"])
        running: false
        onExited: exitCode => {
            root.doRefresh()
        }
    }

    function connectToSpecificWiredConfig(uuid) {
        if (root.isConnecting) return
        const conn = root.wiredConnections.find(c => c.uuid === uuid)
        root.isConnecting = true
        root.connectionError = ""
        root.connectionStatus = "connecting"

        wiredConfigConnector.command = root.lowPriorityCmd.concat(["nmcli", "connection", "up", uuid])
        wiredConfigConnector.running = true
    }

    Process {
        id: wiredConfigConnector
        running: false
        onExited: exitCode => {
            root.isConnecting = false
            if (exitCode === 0) {
                root.connectionStatus = "connected"
                ToastService.showInfo(I18n.tr("Configuration activated"))
            } else {
                root.connectionStatus = "failed"
                root.connectionError = I18n.tr("Failed to activate configuration")
                ToastService.showError(I18n.tr("Failed to activate configuration"))
            }
            root.doRefresh()
        }
    }

    function fetchNetworkInfo(ssid) {
        root.networkInfoSSID = ssid
        root.networkInfoLoading = true
        root.networkInfoDetails = "Loading network information..."
        wifiInfoFetcher.running = true
    }

    Process {
        id: wifiInfoFetcher
        command: root.lowPriorityCmd.concat(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,FREQ,RATE,MODE,CHAN,WPA-FLAGS,RSN-FLAGS,ACTIVE,BSSID", "dev", "wifi", "list"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let details = "Network information not found or network not available."
                const lines = text.trim().split('\n')
                const bands = []

                for (const line of lines) {
                    const parts = root.splitNmcliFields(line)
                    if (parts.length >= 11 && parts[0] === root.networkInfoSSID) {
                        const signal = parts[1] || "0"
                        const security = parts[2] || "Open"
                        const freq = parts[3] || "Unknown"
                        const rate = parts[4] || "Unknown"
                        const mode = parts[5] || "Unknown"
                        const channel = parts[6] || "Unknown"
                        const isActive = parts[9] === "yes"
                        const bssid = parts.length >= 11 ? parts[10] : ""

                        let band = "Unknown"
                        const freqNum = parseInt(freq)
                        if (freqNum >= 2400 && freqNum <= 2500) {
                            band = "2.4 GHz"
                        } else if (freqNum >= 5000 && freqNum <= 6000) {
                            band = "5 GHz"
                        } else if (freqNum >= 6000) {
                            band = "6 GHz"
                        }

                        bands.push({
                            "band": band,
                            "freq": freq,
                            "channel": channel,
                            "signal": signal,
                            "rate": rate,
                            "mode": mode,
                            "security": security,
                            "isActive": isActive,
                            "bssid": bssid
                        })
                    }
                }

                if (bands.length > 0) {
                    bands.sort((a, b) => {
                        if (a.isActive && !b.isActive) return -1
                        if (!a.isActive && b.isActive) return 1
                        return parseInt(b.signal) - parseInt(a.signal)
                    })

                    details = ""
                    for (var i = 0; i < bands.length; i++) {
                        const b = bands[i]
                        const statusPrefix = b.isActive ? "● " : "  "
                        const statusSuffix = b.isActive ? " (Connected)" : ""
                        details += statusPrefix + b.band + statusSuffix + " - " + b.signal + "%"
                        details += "  Channel " + b.channel + " (" + b.freq + " MHz) • " + b.rate + " Mbit/s"
                        details += "  BSSID: " + b.bssid
                        details += "  Mode: " + b.mode
                        details += "  Security: " + (b.security !== "" && b.security !== "Open" ? "Secured" : "Open")
                        details += "\n"
                        if (i < bands.length - 1) details += "\n"
                    }
                }

                root.networkInfoDetails = details
                root.networkInfoLoading = false
            }
        }

        onExited: exitCode => {
            root.networkInfoLoading = false
            if (exitCode !== 0) {
                root.networkInfoDetails = "Failed to fetch network information"
            }
        }
    }

    function refreshWiredConnections() {
        getWiredConnections.running = true
    }

    Process {
        id: getWiredConnections
        command: root.lowPriorityCmd.concat(["nmcli", "-t", "-f", "UUID,NAME,TYPE,STATE", "connection", "show"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const conns = []
                const lines = text.trim().split('\n')
                for (const line of lines) {
                    if (line.includes("802-3-ethernet")) {
                        const parts = line.split(':')
                        if (parts.length >= 4) {
                            conns.push({
                                "uuid": parts[0],
                                "name": parts[1],
                                "state": parts[3] === "activated"
                            })
                        }
                    }
                }
                root.wiredConnections = conns
            }
        }
    }

    function fetchWiredNetworkInfo(uuid) {
        root.networkWiredInfoUUID = uuid
        root.networkWiredInfoLoading = true
        root.networkWiredInfoDetails = "Loading network information..."
        wiredInfoFetcher.running = true
    }

    Process {
        id: wiredInfoFetcher
        command: root.networkWiredInfoUUID ? root.lowPriorityCmd.concat(["nmcli", "connection", "show", root.networkWiredInfoUUID]) : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split('\n')
                const infos = {}
                for (const line of lines) {
                    const idx = line.indexOf(':')
                    if (idx < 0) continue
                    const key = line.substring(0, idx).trim()
                    const value = line.substring(idx + 1).trim()
                    infos[key] = value
                }
                root.networkWiredInfoDetails = formatWiredDetails(infos)
                root.networkWiredInfoLoading = false
            }
        }

        onExited: exitCode => {
            root.networkWiredInfoLoading = false
            if (exitCode !== 0) {
                root.networkWiredInfoDetails = "Failed to fetch network information"
            }
        }
    }

    function formatWiredDetails(infos) {
        let details = "Network information not found or network not available."
        const iface = infos["general.device"] || infos["general.interface"] || ""
        if (iface) {
            details = "Interface: " + iface + "\n"
            const hw = infos["802-3-ethernet.hw-address"] || ""
            if (hw) details += "MAC Addr: " + hw + "\n"
            const ip4 = infos["ip4.address"] || ""
            if (ip4) details += "IPv4 address: " + ip4.split(',')[0] + "\n"
            const gw = infos["ip4.gateway"] || ""
            if (gw) details += "Gateway: " + gw + "\n"
            const dns = infos["ip4.dns"] || ""
            if (dns) details += "DNS: " + dns + "\n"
        }
        return details
    }

    function getNetworkInfo(ssid) {
        const network = root.wifiNetworks.find(n => n.ssid === ssid)
        if (!network) return null
        return {
            "ssid": network.ssid,
            "signal": network.signal,
            "secured": network.secured,
            "saved": network.saved,
            "connected": network.connected,
            "bssid": network.bssid
        }
    }

    function getWiredNetworkInfo(uuid) {
        const network = root.wiredConnections.find(n => n.uuid === uuid)
        if (!network) return null
        return { "uuid": uuid }
    }

    function refreshNetworkState() {
        getState()
    }

    function doRefresh() {
        syncFromNative()
        refreshFullState()
    }

    function startAutoScan() {
        root.autoScan = true
        root.autoRefreshEnabled = true
        autoScanTimer.start()
        if (root.wifiEnabled) {
            scanWifiNetworks()
        }
    }

    function stopAutoScan() {
        root.autoScan = false
        root.autoRefreshEnabled = false
        autoScanTimer.stop()
    }

    function setWifiDeviceOverride(deviceName) {
        SessionData.setWifiDeviceOverride(deviceName || "")
        root.wifiDeviceOverride = deviceName || ""
        if (root.wifiEnabled) {
            scanWifi()
        }
    }

    function setWifiAutoconnect(ssid, autoconnect) {
        const connName = root.ssidToConnectionName[ssid] || ssid
        autoconnectSetter.pendingAutoconnect = autoconnect ? 1 : 0
        autoconnectSetter.command = root.lowPriorityCmd.concat(["nmcli", "connection", "modify", connName, "connection.autoconnect", autoconnect ? "yes" : "no"])
        autoconnectSetter.running = true
    }

    Process {
        id: autoconnectSetter
        running: false
        property int pendingAutoconnect: -1
        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showInfo(pendingAutoconnect === 1 ? I18n.tr("Autoconnect enabled") : I18n.tr("Autoconnect disabled"))
            } else {
                ToastService.showError(I18n.tr("Failed to update autoconnect"))
            }
            pendingAutoconnect = -1
            root.doRefresh()
        }
    }

    function submitCredentials(token, secrets, save) {
        root.credentialsRequested = false
        const ssid = root.credentialsSSID
        const psk = secrets && secrets.psk !== undefined ? secrets.psk : (secrets.password || "")
        if (ssid && psk) {
            credentialsSubmitter.command = root.lowPriorityCmd.concat(["nmcli", "dev", "wifi", "connect", ssid, "password", psk])
            credentialsSubmitter.running = true
        } else {
            reconnectWithSecrets(ssid)
        }
        root.pendingConnectionSSID = ssid
        root.pendingConnectionStartTime = Date.now()
        root.credentialsToken = ""
        root.credentialsSSID = ""
        root.credentialsSetting = ""
        root.credentialsFields = []
        root.credentialsHints = []
        root.credentialsReason = ""
    }

    Process {
        id: credentialsSubmitter
        running: false
        onExited: exitCode => {
            root.isConnecting = false
            if (exitCode === 0) {
                ToastService.showInfo(I18n.tr("Connected to %1").arg(root.currentWifiSSID || root.pendingConnectionSSID))
                root.connectionStatus = "connected"
            } else {
                root.connectionStatus = "invalid_password"
                ToastService.showError(I18n.tr("Invalid password for %1").arg(root.pendingConnectionSSID))
            }
            root.pendingConnectionSSID = ""
            root.doRefresh()
        }
    }

    function reconnectWithSecrets(ssid) {
        const connName = root.ssidToConnectionName[ssid] || ssid
        root.isConnecting = true
        root.connectionStatus = "connecting"
        reconnectWithSecretsProc.command = root.lowPriorityCmd.concat(["nmcli", "connection", "up", connName])
        reconnectWithSecretsProc.running = true
    }

    Process {
        id: reconnectWithSecretsProc
        running: false
        onExited: exitCode => {
            root.isConnecting = false
            if (exitCode === 0) {
                root.connectionStatus = "connected"
                ToastService.showInfo(I18n.tr("Connected to %1").arg(root.currentWifiSSID || root.pendingConnectionSSID))
            } else {
                root.connectionStatus = "failed"
            }
            root.pendingConnectionSSID = ""
            root.doRefresh()
        }
    }

    function cancelCredentials(token) {
        root.credentialsRequested = false
        root.pendingConnectionSSID = ""
        root.connectionStatus = "cancelled"
        root.credentialsToken = ""
        root.credentialsSSID = ""
        root.credentialsSetting = ""
        root.credentialsFields = []
        root.credentialsHints = []
        root.credentialsReason = ""
        if (root.isConnecting) {
            root.isConnecting = false
            root.connectingSSID = ""
        }
    }

    function refreshVpnProfiles() {
        if (!root.vpnAvailable) return
        vpnProfilesProc.running = true
    }

    function refreshVpnActive() {
        if (!root.vpnAvailable) return
        vpnActiveProc.running = true
    }

    function refreshVpn() {
        if (!root.vpnAvailable) return
        vpnProfilesProc.running = true
        vpnActiveProc.running = true
    }

    Process {
        id: vpnProfilesProc
        command: root.lowPriorityCmd.concat(["nmcli", "-t", "-f", "UUID,NAME,TYPE,AUTOCONNECT", "connection", "show"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const profiles = []
                const lines = text.trim().split('\n')
                for (const line of lines) {
                    if (!line.includes("vpn")) continue
                    const parts = root.splitNmcliFields(line)
                    if (parts.length >= 3) {
                        profiles.push({
                            "uuid": parts[0],
                            "name": parts[1],
                            "type": "vpn",
                            "serviceType": parts[2],
                            "autoconnect": parts.length > 3 && parts[3] === "yes"
                        })
                    }
                }
                root.vpnProfiles = profiles
                root.vpnAvailable = true
            }
        }
    }

    Process {
        id: vpnActiveProc
        command: root.lowPriorityCmd.concat(["nmcli", "-t", "-f", "UUID,TYPE,DEVICE,STATE", "connection", "show", "--active"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const active = []
                const lines = text.trim().split('\n')
                for (const line of lines) {
                    if (!line.includes("vpn")) continue
                    const parts = line.split(':')
                    if (parts.length >= 4 && parts[3] === "activated") {
                        const uuid = parts[0]
                        active.push({
                            "uuid": uuid,
                            "name": root.vpnProfiles.find(p => p.uuid === uuid)?.name || "",
                            "device": parts[2],
                            "state": parts[3]
                        })
                    }
                }

                const prevCount = root.vpnActive.length
                root.vpnActive = active

                if (root.vpnConnected && root.activeUuid) {
                    root.lastConnectedVpnUuid = root.activeUuid
                    SessionData.setVpnLastConnected(root.activeUuid)
                }

                if (root.vpnIsBusy) {
                    const busyDuration = Date.now() - root.vpnBusyStartTime
                    const timeout = 30000
                    if (busyDuration > timeout) {
                        root.vpnIsBusy = false
                        root.pendingVpnUuid = ""
                        root.vpnBusyStartTime = 0
                    } else if (root.pendingVpnUuid) {
                        if (active.some(a => a.uuid === root.pendingVpnUuid)) {
                            root.vpnIsBusy = false
                            root.pendingVpnUuid = ""
                            root.vpnBusyStartTime = 0
                        }
                    } else if (prevCount !== active.length) {
                        root.vpnIsBusy = false
                        root.vpnBusyStartTime = 0
                    }
                }

                root.connectionChanged()
            }
        }
    }

    function connectVpn(uuidOrName, singleActive = false) {
        if (!root.vpnAvailable || root.vpnIsBusy) return
        root.vpnIsBusy = true
        root.pendingVpnUuid = uuidOrName
        root.vpnBusyStartTime = Date.now()
        vpnConnector.command = root.lowPriorityCmd.concat(["nmcli", "connection", "up", uuidOrName])
        vpnConnector.running = true
    }

    Process {
        id: vpnConnector
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.vpnIsBusy = false
                root.pendingVpnUuid = ""
                root.vpnBusyStartTime = 0
                ToastService.showError(I18n.tr("Failed to connect VPN"))
            }
            root.refreshVpn()
        }
    }

    function disconnectVpn(uuidOrName) {
        if (!root.vpnAvailable || root.vpnIsBusy) return
        root.vpnIsBusy = true
        root.pendingVpnUuid = ""
        root.vpnBusyStartTime = Date.now()
        vpnDisconnector.command = root.lowPriorityCmd.concat(["nmcli", "connection", "down", uuidOrName])
        vpnDisconnector.running = true
    }

    Process {
        id: vpnDisconnector
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.vpnIsBusy = false
                root.vpnBusyStartTime = 0
                ToastService.showError(I18n.tr("Failed to disconnect VPN"))
            }
            root.refreshVpn()
        }
    }

    function disconnectAllVpns() {
        if (!root.vpnAvailable || root.vpnIsBusy) return
        root.vpnIsBusy = true
        root.pendingVpnUuid = ""
        root.vpnBusyStartTime = Date.now()
        vpnDisconnectAllProc.running = true
    }

    Process {
        id: vpnDisconnectAllProc
        command: root.lowPriorityCmd.concat(["bash", "-c", "nmcli -t -f UUID,TYPE connection show --active | grep vpn | cut -d: -f1 | xargs -r -I {} nmcli connection down {}"])
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.vpnIsBusy = false
                ToastService.showError(I18n.tr("Failed to disconnect VPNs"))
            }
            root.refreshVpn()
        }
    }

    function connect(uuidOrName, singleActive = false) {
        connectVpn(uuidOrName, singleActive)
    }

    function disconnect(uuidOrName) {
        disconnectVpn(uuidOrName)
    }

    function disconnectAllActive() {
        disconnectAllVpns()
    }

    function toggleVpn(uuid) {
        if (uuid) {
            if (isActiveVpnUuid(uuid)) {
                disconnectVpn(uuid)
            } else {
                connectVpn(uuid)
            }
            return
        }

        if (root.vpnConnected) {
            disconnectAllVpns()
            return
        }

        const targetUuid = root.lastConnectedVpnUuid || (root.vpnProfiles.length > 0 ? root.vpnProfiles[0].uuid : "")
        if (targetUuid) {
            connectVpn(targetUuid)
        }
    }

    function toggle(uuid) {
        toggleVpn(uuid)
    }

    function isActiveVpnUuid(uuid) {
        return root.activeUuids && root.activeUuids.indexOf(uuid) !== -1
    }

    function isActiveUuid(uuid) {
        return isActiveVpnUuid(uuid)
    }
}
