pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int refCount: 0
    property int updateInterval: 1000
    property bool isUpdating: false

    property var moduleRefCounts: ({})
    property var enabledModules: []

    property real downloadSpeed: 0
    property real uploadSpeed: 0
    property real downloadTotal: 0
    property real uploadTotal: 0

    property var networkInterfaces: []
    property var lastNetworkStats: null
    property var initialNetworkStats: null
    property real lastTimestamp: 0
    property bool initialized: false
    property var lastInterfaceStats: ({})
    property var networkInterfaceSpeeds: ({})

    property int historySize: 60
    property var downloadHistory: []
    property var uploadHistory: []

    function addRef(modules = null) {
        refCount++;
        let modulesChanged = false;

        if (modules) {
            const modulesToAdd = Array.isArray(modules) ? modules : [modules];
            for (const module of modulesToAdd) {
                const currentCount = moduleRefCounts[module] || 0;
                moduleRefCounts[module] = currentCount + 1;

                if (enabledModules.indexOf(module) === -1) {
                    enabledModules.push(module);
                    modulesChanged = true;
                }
            }
        }

        if (modulesChanged || refCount === 1) {
            enabledModules = enabledModules.slice();
            moduleRefCounts = Object.assign({}, moduleRefCounts);
            updateAllStats();
        }
    }

    function removeRef(modules = null) {
        refCount = Math.max(0, refCount - 1);
        let modulesChanged = false;

        if (modules) {
            const modulesToRemove = Array.isArray(modules) ? modules : [modules];
            for (const module of modulesToRemove) {
                const currentCount = moduleRefCounts[module] || 0;
                if (currentCount > 1) {
                    moduleRefCounts[module] = currentCount - 1;
                } else if (currentCount === 1) {
                    delete moduleRefCounts[module];
                    const index = enabledModules.indexOf(module);
                    if (index > -1) {
                        enabledModules.splice(index, 1);
                        modulesChanged = true;
                    }
                }
            }
        }

        if (modulesChanged) {
            enabledModules = enabledModules.slice();
            moduleRefCounts = Object.assign({}, moduleRefCounts);
        }
    }

    function updateAllStats() {
        if (refCount > 0 && enabledModules.length > 0) {
            isUpdating = true;
            netDevFile.reload();
        } else {
            isUpdating = false;
        }
    }

    function addToHistory(array, value) {
        array.push(value);
        if (array.length > historySize) {
            array.shift();
        }
    }

    function parseNetDev(content) {
        const lines = content.split("\n");
        let totalRx = 0;
        let totalTx = 0;
        const interfaces = [];

        for (let i = 2; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line)
                continue;

            const parts = line.split(/\s+/);
            if (parts.length < 10)
                continue;

            const iface = parts[0].replace(":", "");
            if (iface === "lo")
                continue;

            const rxBytes = parseFloat(parts[1]) || 0;
            const txBytes = parseFloat(parts[9]) || 0;

            totalRx += rxBytes;
            totalTx += txBytes;

            interfaces.push({
                name: iface,
                rxBytes: rxBytes,
                txBytes: txBytes
            });
        }

        return {
            rx: totalRx,
            tx: totalTx,
            interfaces: interfaces
        };
    }

    function findPrimaryInterface(interfaces) {
        for (const iface of interfaces) {
            const name = iface.name;
            if (name.startsWith("eth") || name.startsWith("enp") || name.startsWith("ens") || name.startsWith("enx")) {
                return name;
            }
        }
        for (const iface of interfaces) {
            const name = iface.name;
            if (name.startsWith("wlan") || name.startsWith("wlp") || name.startsWith("wlx")) {
                return name;
            }
        }
        return interfaces.length > 0 ? interfaces[0].name : "";
    }

    FileView {
        id: netDevFile
        path: "/proc/net/dev"
    }

    Timer {
        id: updateTimer
        interval: root.updateInterval
        running: root.refCount > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateAllStats()
    }

    Connections {
        target: netDevFile
        function onLoaded() {
            const content = netDevFile.text();
            if (!content)
                return;

            const data = root.parseNetDev(content);
            const now = Date.now();

            if (!root.initialized) {
                root.initialNetworkStats = { rx: data.rx, tx: data.tx };
                root.lastNetworkStats = { rx: data.rx, tx: data.tx };
                root.lastTimestamp = now;
                root.networkInterfaces = data.interfaces;
                root.initialized = true;

                const primary = root.findPrimaryInterface(data.interfaces);
                console.info("NetworkSpeedService: Initialized, primary interface:", primary);
                return;
            }

            const timeDelta = (now - root.lastTimestamp) / 1000;
            if (timeDelta > 0 && root.lastNetworkStats) {
                let rxDelta = data.rx - root.lastNetworkStats.rx;
                let txDelta = data.tx - root.lastNetworkStats.tx;

                if (rxDelta < 0) {
                    rxDelta += Math.pow(2, 64);
                }
                if (txDelta < 0) {
                    txDelta += Math.pow(2, 64);
                }

                root.downloadSpeed = rxDelta / timeDelta;
                root.uploadSpeed = txDelta / timeDelta;

                if (root.downloadSpeed >= 0 && isFinite(root.downloadSpeed))
                    root.addToHistory(root.downloadHistory, root.downloadSpeed / 1024);
                if (root.uploadSpeed >= 0 && isFinite(root.uploadSpeed))
                    root.addToHistory(root.uploadHistory, root.uploadSpeed / 1024);

                let downTotal = data.rx - root.initialNetworkStats.rx;
                let upTotal = data.tx - root.initialNetworkStats.tx;

                if (downTotal < 0)
                    downTotal += Math.pow(2, 64);
                if (upTotal < 0)
                    upTotal += Math.pow(2, 64);

                root.downloadTotal = downTotal;
                root.uploadTotal = upTotal;
            }

            root.lastNetworkStats = { rx: data.rx, tx: data.tx };
            root.lastTimestamp = now;
            root.networkInterfaces = data.interfaces;

            if (timeDelta > 0 && root.lastInterfaceStats) {
                let interfaceSpeeds = {};
                for (const iface of data.interfaces) {
                    const prev = root.lastInterfaceStats[iface.name];
                    if (prev) {
                        let rxDelta = iface.rxBytes - prev.rxBytes;
                        let txDelta = iface.txBytes - prev.txBytes;
                        if (rxDelta < 0) rxDelta += Math.pow(2, 64);
                        if (txDelta < 0) txDelta += Math.pow(2, 64);
                        interfaceSpeeds[iface.name] = {
                            rxSpeed: rxDelta / timeDelta,
                            txSpeed: txDelta / timeDelta
                        };
                    }
                }
                root.networkInterfaceSpeeds = interfaceSpeeds;
            }

            let ifaceStats = {};
            for (const iface of data.interfaces) {
                ifaceStats[iface.name] = { rxBytes: iface.rxBytes, txBytes: iface.txBytes };
            }
            root.lastInterfaceStats = ifaceStats;
        }
    }

    Component.onCompleted: {
        console.info("NetworkSpeedService: Initialized");
    }
}