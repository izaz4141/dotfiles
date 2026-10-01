// Unit test / probe: verifies whether the native Quickshell.Networking module
// populates devices and reflects the live NetworkManager connection state.
//
// Run from inside a Wayland session:
//   qs -p test/NativeNetworkingProbe.qml --log-rules 'quickshell.network*.debug=true' -vv 2>&1 | grep -E "PROBE|quickshell.(network|wifinetwork)"
//
// Expected for a healthy backend: PROBE backend=NetworkManager and at least one
// wifi device with connected=true whose networks expose the connected SSID.
import QtQuick
import Quickshell
import Quickshell.Networking

Item {
    id: root

    property int attempts: 0

    function dump() {
        console.warn("PROBE backend=" + Networking.backend)
        const devs = Networking.devices
        const vals = devs ? devs.values : null
        console.warn("PROBE devices.values.length=" + (vals ? vals.length : "no values"))
        if (vals) {
            for (var i = 0; i < vals.length; i++) {
                const d = vals[i]
                console.warn("PROBE dev[" + i + "] type=" + d.type + " name=" + d.name
                    + " connected=" + d.connected + " state=" + d.state
                    + " scanner=" + (d.scannerEnabled !== undefined ? d.scannerEnabled : "-"))
                const nets = d.networks
                const nvals = nets ? nets.values : null
                console.warn("PROBE   dev[" + i + "].networks.values.length=" + (nvals ? nvals.length : "-"))
                if (nvals) {
                    for (var j = 0; j < nvals.length; j++) {
                        const n = nvals[j]
                        console.warn("PROBE   net[" + j + "] ssid=" + n.name
                            + " connected=" + n.connected
                            + " signal=" + (n.signalStrength !== undefined ? n.signalStrength : "-"))
                    }
                }
            }
        }
    }

    Timer {
        id: probeTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.attempts++
            root.dump()
            if (root.attempts >= 4) {
                probeTimer.running = false
                Quickshell.quit()
            }
        }
    }
}
