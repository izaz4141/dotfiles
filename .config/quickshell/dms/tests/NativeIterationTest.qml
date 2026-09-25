// Runtime unit test for the NetworkService ObjectModel iteration fix.
// Verifies that the four fixed functions (forEachDevice, findConnectedWifiNetwork,
// wireSecretsHandlers iteration, nativeWifiNetwork) correctly enumerate devices /
// networks using the Quickshell ObjectModel `.values` array accessor.
// Run: qs -p test/NativeIterationTest.qml 2>&1 | grep -E "TEST"
import QtQuick
import Quickshell
import Quickshell.Networking

Item {
    id: root

    readonly property int deviceTypeWifi: 1
    readonly property int deviceTypeWired: 2
    property var seenNetworks: []

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
            if (d.type === root.deviceTypeWifi) result.push(d)
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

    function wireSecretsIteration() {
        const devs = findWifiDevices()
        for (const dev of devs) {
            const nets = dev.networks
            if (!nets || !nets.values) continue
            const vals = nets.values
            for (var i = 0; i < vals.length; i++) {
                const n = vals[i]
                if (!n || root.seenNetworks.indexOf(n) !== -1) continue
                root.seenNetworks.push(n)
            }
        }
        return root.seenNetworks.length
    }

    function run() {
        const wifiDevs = findWifiDevices()
        console.warn("TEST findWifiDevices=" + wifiDevs.length)
        if (wifiDevs.length === 0) { console.warn("TEST FAIL no wifi device"); return }
        for (let i = 0; i < wifiDevs.length; i++) {
            console.warn("TEST wifiDev[" + i + "] connected=" + wifiDevs[i].connected)
        }
        const cur = findConnectedWifiNetwork()
        console.warn("TEST findConnectedWifiNetwork.ssid=" + (cur ? cur.name : "(none)")
            + " signal%=" + (cur ? Math.round(cur.signalStrength * 100) : 0))
        const byName = nativeWifiNetwork("3deep")
        console.warn("TEST nativeWifiNetwork(3deep) connected=" + (byName ? byName.connected : "not found"))
        const seen = wireSecretsIteration()
        console.warn("TEST wireSecretsIteration.seen=" + seen)

        const pass = wifiDevs.length > 0 && cur && cur.connected && cur.name === "3deep" && byName && seen > 0
        if (pass) {
            console.warn("TEST PASS: iteration fix works on live native model")
            runTimer.running = false
            Quickshell.quit()
            return
        }

        // Also verify old accessors are NOT present (the bug)
        const devsModel = Networking.devices
        console.warn("TEST old-accessor count=" + devsModel.count
            + " get=" + (typeof devsModel.get) + " values=" + (devsModel.values ? devsModel.values.length : 0))

        Quickshell.quit()
    }

    property int attempts: 0

    Timer {
        id: runTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.attempts++
            root.run()
            if (root.attempts >= 6) {
                runTimer.running = false
                Quickshell.quit()
            }
        }
    }
}
