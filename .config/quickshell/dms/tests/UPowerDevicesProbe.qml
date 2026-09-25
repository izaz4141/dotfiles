import QtQuick
import Quickshell
import Quickshell.Services.UPower

Item {
    id: root
    property int attempts: 0

    function run() {
        const d = UPower.devices
        console.warn("UPROBE backend devices undefined=" + (d === undefined))
        if (d) {
            console.warn("UPROBE keys=" + JSON.stringify(Object.keys(d)).substring(0, 120))
            console.warn("UPROBE count=" + d.count + " length=" + d.length
                + " values.len=" + (d.values ? d.values.length : "none")
                + " values=" + (d.values ? JSON.stringify(d.values.map(x => ({"type": x.type, "percent": x.percent, "state": x.state, "name": x.name}))) : "[]"))
        }
        root.attempts++
        if (root.attempts >= 3) Quickshell.quit()
    }

    Timer { interval: 1500; repeat: true; running: true
        onTriggered: root.run() }
}
