pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool geoclueAvailable: false
    property bool geoclueAgentRunning: false

    readonly property bool locationAvailable: geoclueAvailable
    readonly property bool valid: latitude !== 0 || longitude !== 0

    property var latitude: 0.0
    property var longitude: 0.0
    property var accuracy: 0.0

    signal locationChanged(var data)

    property string _agentPath: "/usr/lib/geoclue-2.0/demos/agent"
    property bool _busy: false

    Component.onCompleted: {
        detectGeoclue();
    }

    function detectGeoclue() {
        Proc.runCommand("geoclueDetect", ["sh", "-c", "busctl --system list | grep -qF org.freedesktop.GeoClue2"], (output, code) => {
            geoclueAvailable = (code === 0);
            if (!geoclueAvailable)
                return;
            Proc.runCommand("geoclueAgentPath", ["sh", "-c", "if test -x /usr/lib/geoclue-2.0/demos/agent; then echo /usr/lib/geoclue-2.0/demos/agent; elif test -x /usr/libexec/geoclue-2.0/demos/agent; then echo /usr/libexec/geoclue-2.0/demos/agent; else exit 1; fi"], (out, c) => {
                const found = out.trim();
                if (c === 0 && found)
                    _agentPath = found;
                if (!valid)
                    getState();
            }, 0);
        }, 0);
    }

    Process {
        id: geoclueAgentProcess
        command: [_agentPath]
        running: false

        onExited: function (exitCode) {
            geoclueAgentRunning = false;
        }
    }

    function startGeoclueAgent() {
        if (!geoclueAvailable || geoclueAgentRunning)
            return;
        geoclueAgentProcess.command = [_agentPath];
        geoclueAgentProcess.running = true;
        geoclueAgentRunning = true;
    }

    function getState() {
        if (!geoclueAvailable || _busy)
            return;

        _busy = true;
        startGeoclueAgent();
        Proc.runCommand("geolocate", ["python3", Paths.strip(Qt.resolvedUrl("../Scripts/geolocate.py"))], (output, code) => {
            const parts = output.trim().split(",");
            if (code !== 0 || parts.length < 2) {
                console.warn("LocationService: geoclue lookup failed:", output.trim());
                _busy = false;
                return;
            }

            const lat = parseFloat(parts[0]);
            const lon = parseFloat(parts[1]);
            if (isNaN(lat) || isNaN(lon) || (lat === 0 && lon === 0)) {
                console.warn("LocationService: geoclue returned no coordinates:", output.trim());
                _busy = false;
                return;
            }

            root.latitude = lat;
            root.longitude = lon;
            root.accuracy = parts.length > 2 ? parseFloat(parts[2]) || 0 : 0;
            root.locationChanged({
                "latitude": lat,
                "longitude": lon,
                "accuracy": root.accuracy
            });
            _busy = false;
        }, 0, 30000);
    }
}