pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool monitorAvailable: true
    property int refCount: 0
    property int updateInterval: refCount > 0 ? 3000 : 30000
    property bool isUpdating: false

    property var moduleRefCounts: ({})
    property var enabledModules: []
    property var gpuPciIds: []
    property var gpuPciIdRefCounts: ({})
    property int processLimit: 20
    property string processSort: "cpu"
    property bool noCpu: false

    property bool gpuTempEnabled: false
    property bool nvidiaGpuTempEnabled: false
    property bool nonNvidiaGpuTempEnabled: false

    property real cpuUsage: 0
    property real cpuFrequency: 0
    property real cpuTemperature: 0
    property int cpuCores: 1
    property string cpuModel: ""
    property var perCoreCpuUsage: []

    property real memoryUsage: 0
    property real totalMemoryMB: 0
    property real usedMemoryMB: 0
    property real freeMemoryMB: 0
    property real availableMemoryMB: 0
    property int totalMemoryKB: 0
    property int usedMemoryKB: 0
    property int totalSwapKB: 0
    property int usedSwapKB: 0

    property real networkRxRate: 0
    property real networkTxRate: 0
    property var lastNetworkStats: null
    property var networkInterfaces: []

    property real diskReadRate: 0
    property real diskWriteRate: 0
    property var diskMounts: []
    property var diskDevices: []
    property var diskBaselines: ({})
    property string diskBaselineKey: ""
    property var blockDevices: []
    property var blockDeviceInfo: ({})
    property bool blockScanInFlight: false

    property var processes: []
    property var allProcesses: []
    property string currentSort: "cpu"
    property bool sortAscending: false
    property var availableGpus: []
    property var processDetails: ({})
    readonly property var nonGroupableCommands: [
        "sddm", "lightdm", "gdm", "xdm", "greetd", "ly", "login", "display-manager",
        "start-hyprland", "hyprland-session", "startx", "xsession", "gnome-session",
        "startplasma", "plasmashell", "xfce4-session", "mate-session", "lxqt-session",
        "lxsession", "dde-session", "ukui-session", "deepin-session", "cinnamon",
        "i3", "awesome", "sway-launch",
        "hyprland", "niri", "sway", "mangowc", "labwc", "scroll"
    ]

    property string kernelVersion: ""
    property string distribution: ""
    property string hostname: ""
    property string architecture: ""
    property string loadAverage: ""
    property int processCount: 0
    property int threadCount: 0
    property string bootTime: ""
    property string motherboard: ""
    property string biosVersion: ""
    property string uptime: ""
    property string shortUptime: ""

    property int historySize: 60
    property var cpuHistory: []
    property var memoryHistory: []
    property var networkHistory: ({"rx": [], "tx": []})
    property var diskHistory: ({"read": [], "write": []})

    property var cpuLast: null
    property var perCoreLast: null
    property int cpuTotalTicksDelta: 0
    property real cpuLastSampleWall: 0
    readonly property int cpuMinSampleInterval: 1000
    readonly property real procMinCpuInterval: 0.5
    readonly property int clkTicksPerSecond: 100
    property real lastTickWall: 0

    property var pidList: []
    property var procCpuTicks: ({})
    property var procPrevCpuTicks: ({})
    property var procIoCurrent: ({})
    property var procIoPrev: ({})
    property real procIoElapsed: 0
    property real lastProcScanWall: 0
    property bool procScanInFlight: false
    property int procScanIndex: 0

    property var gpuCards: ({})
    property var gpuHwmonPaths: ({})
    property var gpuHwmonQueue: []
    property int gpuHwmonQueueIndex: 0
    property string gpuHwmonScanPciId: ""
    property string lspciText: ""
    property bool lspciAvailable: false
    property bool nvidiaSmiAvailable: false
    property int nvidiaGpuCount: 0
    property real nvidiaSmiLastRun: 0

    readonly property int dfMinInterval: 10000
    readonly property int nvidiaSmiMinInterval: 15000
    property real dfLastRun: 0
    property real blockScanLastAttempt: 0
    property int blockScanBackoff: 0
    readonly property int blockScanMaxBackoff: 60000

    property var passwdMap: ({})
    property bool gpuInitialized: false
    property bool systemInitialized: false

    function readFile(filePath) {
        if (!filePath)
            return "";
        try {
            fileReader.path = "";
            fileReader.path = filePath;
            return fileReader.text();
        } catch (e) {
            return "";
        }
    }

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

    function setGpuPciIds(pciIds) {
        gpuPciIds = Array.isArray(pciIds) ? pciIds : [];
    }

    function addGpuPciId(pciId) {
        gpuPciIdRefCounts[pciId] = (gpuPciIdRefCounts[pciId] || 0) + 1;
        if (!gpuPciIds.includes(pciId)) {
            gpuPciIds = gpuPciIds.concat([pciId]);
        }
        gpuPciIdRefCounts = Object.assign({}, gpuPciIdRefCounts);
    }

    function removeGpuPciId(pciId) {
        const currentCount = gpuPciIdRefCounts[pciId] || 0;
        if (currentCount > 1) {
            gpuPciIdRefCounts[pciId] = currentCount - 1;
        } else if (currentCount === 1) {
            delete gpuPciIdRefCounts[pciId];
            if (gpuPciIds.includes(pciId)) {
                gpuPciIds = gpuPciIds.slice();
                gpuPciIds.splice(gpuPciIds.indexOf(pciId), 1);
            }

            if (availableGpus && availableGpus.length > 0) {
                const updatedGpus = availableGpus.slice();
                for (let i = 0; i < updatedGpus.length; i++) {
                    if (updatedGpus[i].pciId === pciId) {
                        updatedGpus[i] = Object.assign({}, updatedGpus[i], {temperature: 0});
                    }
                }
                availableGpus = updatedGpus;
            }
        }
        gpuPciIdRefCounts = Object.assign({}, gpuPciIdRefCounts);
    }

    function setProcessOptions(limit = 20, sort = "cpu", disableCpu = false) {
        processLimit = limit;
        processSort = sort;
        noCpu = disableCpu;
    }

    function isModuleEnabled(module) {
        return enabledModules.includes(module) || enabledModules.includes("all");
    }

    function updateAllStats() {
        if (!monitorAvailable || refCount <= 0 || enabledModules.length === 0) {
            isUpdating = false;
            return;
        }

        isUpdating = true;
        const now = Date.now();
        const elapsed = root.lastTickWall > 0 ? (now - root.lastTickWall) / 1000 : 0;
        root.lastTickWall = now;

        if (isModuleEnabled("cpu") || isModuleEnabled("processes")) {
            parseCpu(readFile("/proc/stat"), readFile("/proc/cpuinfo"));
        }

        if (isModuleEnabled("cpu")) {
            parseCpuTemperature();
        }

        if (isModuleEnabled("memory")) {
            parseMemory(readFile("/proc/meminfo"));
        }

        if (isModuleEnabled("network")) {
            parseNetwork(readFile("/proc/net/dev"), elapsed);
        }

        if (isModuleEnabled("disk")) {
            if (blockDevices.length === 0 && !blockScanInFlight && now - root.blockScanLastAttempt >= root.blockScanBackoff) {
                startBlockDeviceScan();
            }
            parseDiskStats(readFile("/proc/diskstats"), elapsed);
        }

        if (isModuleEnabled("diskmounts")) {
            if (!dfInFlight && now - root.dfLastRun >= root.dfMinInterval) {
                dfInFlight = true;
                dfLastRun = now;
                dfProcess.running = true;
            }
        }

        if (isModuleEnabled("processes")) {
            if (!procScanInFlight) {
                procScanInFlight = true;
                threadsTotal = 0;
                procIoElapsed = root.lastProcScanWall > 0 ? (now - root.lastProcScanWall) / 1000 : 0;
                root.lastProcScanWall = now;
                procTableProcess.running = true;
            }
        }

        if (isModuleEnabled("system")) {
            loadAverage = readFile("/proc/loadavg").trim();
        }

        if (gpuPciIds.length > 0) {
            refreshGpuTemps();
        }

        isUpdating = false;
    }

    function parseCpuFields(line) {
        const parts = line.trim().split(/\s+/);
        if (parts.length < 6)
            return null;
        const fields = [];
        for (let i = 1; i < parts.length; i++) {
            if (!/^\d+$/.test(parts[i]))
                return null;
            fields.push(parseInt(parts[i], 10));
        }
        return fields;
    }

    function sumCpuFields(fields) {
        let sum = 0;
        for (const value of fields)
            sum += value;
        return sum;
    }

    function cpuUsageFromDeltas(total, busy, lastTotal, lastBusy) {
        const totalDelta = Math.max(0, total - lastTotal);
        if (totalDelta <= 0)
            return -1;
        const busyDelta = Math.max(0, Math.min(busy - lastBusy, totalDelta));
        return Math.round((busyDelta / totalDelta) * 1000) / 10;
    }

    function parseCpu(statContent, cpuinfoContent) {
        if (!statContent)
            return;

        const lines = statContent.split("\n");
        let cpuFields = null;
        let btime = 0;
        let statCores = 0;
        const perCore = [];

        for (const line of lines) {
            if (/^cpu\s/.test(line)) {
                const fields = parseCpuFields(line);
                if (fields)
                    cpuFields = fields;
            } else if (/^cpu\d+\s/.test(line)) {
                statCores++;
                const fields = parseCpuFields(line);
                if (fields) {
                    const total = sumCpuFields(fields);
                    perCore.push({total: total, busy: total - fields[3] - fields[4]});
                }
            } else if (line.startsWith("btime")) {
                btime = parseInt(line.trim().split(/\s+/)[1], 10) || 0;
            }
        }

        const now = Date.now();
        const publish = root.cpuLastSampleWall === 0 || (now - root.cpuLastSampleWall) >= root.cpuMinSampleInterval;
        root.cpuLastSampleWall = now;

        if (cpuFields) {
            const total = sumCpuFields(cpuFields);
            const busy = total - cpuFields[3] - cpuFields[4];
            const usage = root.cpuLast ? cpuUsageFromDeltas(total, busy, root.cpuLast.total, root.cpuLast.busy) : -1;
            if (publish && usage >= 0) {
                cpuUsage = usage;
                cpuTotalTicksDelta = total - root.cpuLast.total;
            }
            root.cpuLast = {total: total, busy: busy};
        }

        if (perCore.length > 0) {
            const rebaseline = !root.perCoreLast || root.perCoreLast.length !== perCore.length;
            if (publish && !rebaseline) {
                const usage = [];
                for (let i = 0; i < perCore.length; i++) {
                    const value = cpuUsageFromDeltas(perCore[i].total, perCore[i].busy, root.perCoreLast[i].total, root.perCoreLast[i].busy);
                    usage.push(value >= 0 ? value : 0);
                }
                perCoreCpuUsage = usage;
            } else if (!publish || rebaseline) {
                perCoreCpuUsage = new Array(perCore.length).fill(0);
            }
            root.perCoreLast = perCore;
        }

        if (cpuinfoContent) {
            let model = "";
            let mhzTotal = 0;
            let mhzCount = 0;
            let infoCores = 0;
            for (const line of cpuinfoContent.split("\n")) {
                const idx = line.indexOf(":");
                if (idx < 0)
                    continue;
                const key = line.substring(0, idx).trim();
                const value = line.substring(idx + 1).trim();
                if (key === "model name" && !model) {
                    model = value;
                } else if (key === "cpu MHz") {
                    const mhz = parseFloat(value);
                    if (mhz > 0) {
                        mhzTotal += mhz;
                        mhzCount++;
                    }
                } else if (key === "processor") {
                    infoCores++;
                }
            }
            cpuModel = model || cpuModel;
            cpuFrequency = mhzCount > 0 ? Math.round(mhzTotal / mhzCount) : 0;
            if (statCores > 0)
                cpuCores = statCores;
            else if (infoCores > 0)
                cpuCores = infoCores;
        } else if (statCores > 0) {
            cpuCores = statCores;
        }

        if (publish)
            addToHistory(cpuHistory, cpuUsage);

        if (btime > 0 && root.bootEpoch === 0) {
            root.bootEpoch = btime;
            updateUptime();
        }
    }

    property var bootEpoch: 0

    property var hwmonList: []
    property bool hwmonListScanning: false

    function parseCpuTemperature() {
        if (hwmonList.length === 0) {
            if (!hwmonListScanning) {
                hwmonListScanning = true;
                hwmonListProcess.running = true;
            }
            return;
        }

        for (const hwmon of hwmonList) {
            const name = readFile(hwmon + "/name").trim();
            if (name === "coretemp" || name === "k10temp" || name === "k8temp") {
                const temp = readHwmonTemp(hwmon);
                if (temp > 0) {
                    cpuTemperature = temp;
                    return;
                }
            }
        }

        const candidates = [];
        for (const hwmon of hwmonList) {
            const name = readFile(hwmon + "/name").trim();
            if (["amdgpu", "nvidia", "i915", "nouveau", "radeon", "hidpp"].indexOf(name) !== -1)
                continue;
            const temp = readHwmonTemp(hwmon);
            if (temp > 0 && temp <= 130)
                candidates.push(temp);
        }
        candidates.sort((a, b) => b - a);
        if (candidates.length > 0)
            cpuTemperature = candidates[0];
    }

    function parseHwmonList(content) {
        const hwmons = [];
        for (const line of content.split("\n")) {
            const entry = line.trim();
            if (entry.startsWith("hwmon")) {
                hwmons.push("/sys/class/hwmon/" + entry);
            }
        }
        return hwmons;
    }

    function readHwmonTemp(hwmonPath) {
        const candidates = [hwmonPath + "/temp1_input", hwmonPath + "/temp2_input", hwmonPath + "/temp3_input"];
        for (const path of candidates) {
            const value = parseInt(readFile(path), 10);
            if (value > 0)
                return Math.round(value / 1000);
        }
        return 0;
    }

    function parseMemory(content) {
        if (!content)
            return;
        const lines = content.split("\n");
        let memTotal = 0, memFree = 0, memAvailable = 0, bufferTotal = 0, swapTotal = 0, swapFree = 0;

        for (const line of lines) {
            if (!line.trim())
                continue;
            const parts = line.trim().match(/^(\S+):\s+(\d+)/);
            if (!parts)
                continue;
            const key = parts[1];
            const value = parseInt(parts[2], 10) || 0;
            switch (key) {
                case "MemTotal": memTotal = value; break;
                case "MemFree": memFree = value; break;
                case "MemAvailable": memAvailable = value; break;
                case "Buffers": bufferTotal += value; break;
                case "Cached": bufferTotal += value; break;
                case "SwapTotal": swapTotal = value; break;
                case "SwapFree": swapFree = value; break;
            }
        }

        const available = memAvailable > 0 ? memAvailable : (memFree + bufferTotal);
        const used = memTotal > available ? memTotal - available : 0;
        totalMemoryKB = memTotal;
        usedMemoryKB = used;
        totalMemoryMB = Math.round(memTotal / 1024);
        usedMemoryMB = Math.round(used / 1024);
        freeMemoryMB = Math.round(memFree / 1024);
        availableMemoryMB = Math.round(available / 1024);
        totalSwapKB = swapTotal;
        usedSwapKB = swapTotal > swapFree ? swapTotal - swapFree : 0;
        memoryUsage = memTotal > 0 ? Math.round(((memTotal - available) / memTotal) * 1000) / 10 : 0;

        addToHistory(memoryHistory, memoryUsage);
    }

    function parseNetwork(content, elapsed) {
        if (!content)
            return;
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
            interfaces.push({name: iface, rx: rxBytes, tx: txBytes});
        }

        networkInterfaces = interfaces;

        if (lastNetworkStats && elapsed > 0) {
            let rxDelta = totalRx - lastNetworkStats.rx;
            let txDelta = totalTx - lastNetworkStats.tx;
            if (rxDelta < 0)
                rxDelta += Math.pow(2, 64);
            if (txDelta < 0)
                txDelta += Math.pow(2, 64);
            networkRxRate = Math.max(0, rxDelta / elapsed);
            networkTxRate = Math.max(0, txDelta / elapsed);
            addToHistory(networkHistory.rx, networkRxRate / 1024);
            addToHistory(networkHistory.tx, networkTxRate / 1024);
        } else {
            networkRxRate = 0;
            networkTxRate = 0;
        }

        lastNetworkStats = {rx: totalRx, tx: totalTx};
    }

    function looksLikeWholeDisk(name) {
        return /^(sd[a-z]+|nvme\d+n\d+|mmcblk\d+|vd[a-z]+|xvd[a-z]+|hd[a-z]+|bcache\d+)$/.test(name);
    }

    function isWholeDisk(name) {
        if (blockDevices.length > 0) {
            return blockDevices.indexOf(name) !== -1;
        }
        return looksLikeWholeDisk(name);
    }

    function parseBlockDeviceList(content) {
        const names = [];
        const info = {};

        for (const line of content.split("\n")) {
            const name = line.trim();
            if (!name)
                continue;

            const base = "/sys/block/" + name;
            if (readFile(base + "/device/uevent").trim().length === 0)
                continue;

            names.push(name);
            info[name] = {
                model: readFile(base + "/device/model").trim(),
                sizeBytes: (parseInt(readFile(base + "/size"), 10) || 0) * 512,
                rotational: readFile(base + "/queue/rotational").trim() === "1",
                removable: readFile(base + "/removable").trim() === "1"
            };
        }

        blockDevices = names;
        blockDeviceInfo = info;
        blockScanInFlight = false;
        blockScanBackoff = names.length > 0 ? 0 : Math.min(root.blockScanMaxBackoff, root.blockScanBackoff === 0 ? 5000 : root.blockScanBackoff * 2);
    }

    function startBlockDeviceScan() {
        if (blockScanInFlight)
            return;
        blockScanInFlight = true;
        blockScanLastAttempt = Date.now();
        blockDeviceListProcess.running = true;
    }

    function requestProcessDetails(pid) {
        if (!pid || pid <= 0)
            return;
        if (processDetailsProcess.running)
            return;
        processDetailsProcess.pid = pid;
        processDetailsProcess.running = true;
    }

    function parseProcessDetails(content) {
        const details = {};
        for (const line of content.split("\n")) {
            if (!line.trim())
                continue;
            const idx = line.indexOf("\t");
            if (idx === -1)
                continue;
            const key = line.substring(0, idx);
            const value = line.substring(idx + 1).trim();
            if (!key || !value)
                continue;
            details[key] = value;
        }
        details.fds = parseInt(details.fds, 10) || 0;
        details.threads = parseInt(details.threads, 10) || 0;
        processDetails = details;
    }

    function parseDiskStats(content, elapsed) {
        if (!content)
            return;

        const raw = {};
        const seen = [];

        for (const line of content.split("\n")) {
            if (!line.trim())
                continue;
            const parts = line.trim().split(/\s+/);
            if (parts.length < 14)
                continue;
            const name = parts[2];
            raw[name] = {
                read: (parseFloat(parts[5]) || 0) * 512,
                write: (parseFloat(parts[9]) || 0) * 512,
                ioTicks: parseFloat(parts[12]) || 0
            };
            seen.push(name);
        }

        for (const name of seen) {
            if (!looksLikeWholeDisk(name))
                continue;
            if (blockDevices.indexOf(name) === -1) {
                startBlockDeviceScan();
                break;
            }
        }

        const names = seen.filter(isWholeDisk).sort();
        const key = names.join(",");
        const stable = key.length > 0 && key === diskBaselineKey;

        const devices = [];
        const baselines = {};
        let totalRead = 0;
        let totalWrite = 0;

        for (const name of names) {
            const current = raw[name];
            const previous = diskBaselines[name];
            const meta = blockDeviceInfo[name] || {};

            let readRate = 0;
            let writeRate = 0;
            let busyPercent = 0;

            if (previous && stable && elapsed > 0) {
                readRate = Math.max(0, (current.read - previous.read) / elapsed);
                writeRate = Math.max(0, (current.write - previous.write) / elapsed);
                busyPercent = Math.min(100, Math.max(0, ((current.ioTicks - previous.ioTicks) / (elapsed * 1000)) * 100));
            }

            baselines[name] = current;
            totalRead += readRate;
            totalWrite += writeRate;

            devices.push({
                name: name,
                model: meta.model || "",
                sizeBytes: meta.sizeBytes || 0,
                rotational: meta.rotational === true,
                removable: meta.removable === true,
                read: current.read,
                write: current.write,
                readRate: readRate,
                writeRate: writeRate,
                busyPercent: Math.round(busyPercent)
            });
        }

        diskDevices = devices;
        diskBaselines = baselines;
        diskBaselineKey = key;

        diskReadRate = totalRead;
        diskWriteRate = totalWrite;

        if (stable) {
            addToHistory(diskHistory.read, totalRead / (1024 * 1024));
            addToHistory(diskHistory.write, totalWrite / (1024 * 1024));
        }
    }

    function parseDf(content) {
        if (!content)
            return;
        const mounts = [];
        const lines = content.split("\n");

        for (let i = 1; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line)
                continue;
            const parts = line.split(/\s+/);
            if (parts.length < 7)
                continue;
            const device = parts[0];
            if (device === "tmpfs" || device === "devtmpfs" || device === "sysfs" || device === "proc" ||
                device === "cgroup" || device === "cgroup2" || device === "devpts" || device === "mqueue" ||
                device === "securityfs" || device === "debugfs" || device === "tracefs" || device === "fusectl" ||
                device === "binfmt_misc" || device === "efivarfs" || device === "hugetlbfs" || device === "configfs" ||
                device === "pstore" || device === "autofs" || device === "nsfs" || device === "bpf" || device === "rpc_pipefs")
                continue;

            const usedKB = parseFloat(parts[3]) || 0;
            const availKB = parseFloat(parts[4]) || 0;
            const totalKB = usedKB + availKB;
            const mountPoint = parts.slice(6).join(" ");
            const pct = parts[5];

            const toGB = kb => Math.round((kb / (1024 * 1024)) * 10) / 10;

            const toTB = totalKB / (1024 * 1024) >= 1024;
            const divisor = toTB ? 1024 : 1;
            const unit = toTB ? "TB" : "GB";
            const digits = toTB ? 2 : 1;
            const formatVolume = kb => (kb / (1024 * 1024) / divisor).toFixed(digits) + " " + unit;

            mounts.push({
                mount: mountPoint,
                mountpoint: mountPoint,
                device: device,
                fstype: parts[1],
                percent: pct,
                used: toGB(usedKB),
                avail: toGB(availKB),
                size: toGB(totalKB),
                total: toGB(totalKB),
                unit: unit,
                usedLabel: formatVolume(usedKB),
                availLabel: formatVolume(availKB),
                sizeLabel: formatVolume(totalKB)
            });
        }

        diskMounts = mounts;
        dfInFlight = false;
    }

    function parseProcTable(text) {
        if (!text) {
            procScanInFlight = false;
            return;
        }

        const lines = text.split("\n");
        let count = 0;
        for (const rawLine of lines) {
            const line = rawLine.trim();
            if (line.length === 0)
                continue;
            parseProcRow(line);
            count++;
        }

        processCount = count;
        applySorting();
        procScanInFlight = false;
    }

    function parseProcRow(line) {
        const parts = line.split("\t");
        if (parts.length < 10)
            return;

        const pid = parseInt(parts[0], 10) || 0;
        const comm = parts[1];
        const ppid = parseInt(parts[2], 10) || 0;
        const utime = parseInt(parts[3], 10) || 0;
        const stime = parseInt(parts[4], 10) || 0;
        const numThreads = parseInt(parts[5], 10) || 0;
        const memoryKB = parseInt(parts[6], 10) || 0;
        const uidStr = parts[7];
        const readBytes = parseInt(parts[8], 10) || 0;
        const writeBytes = parseInt(parts[9], 10) || 0;
        const ioAvailable = parts[10] === "1";
        const cmdline = parts.slice(11).join("\t");
        const ticks = utime + stime;

        const fullCommand = cmdline || comm;
        const command = cmdline ? cmdline.split(/\s+/)[0].replace(/^.*\/([^/]+)$/, (m, p1) => p1) : comm;
        const displayCommand = root.resolveProcessName(comm, command);
        const username = (passwdMap[uidStr] || "root");

        procCpuTicks[pid] = ticks;
        procIoCurrent[pid] = {read: readBytes, write: writeBytes, available: ioAvailable};
        threadsTotal += numThreads;

        addProc({
            pid: pid,
            ppid: ppid,
            cpu: 0,
            memoryPercent: totalMemoryKB > 0 ? Math.round((memoryKB / totalMemoryKB) * 10000) / 100 : 0,
            memoryKB: memoryKB,
            command: command,
            displayCommand: displayCommand,
            fullCommand: fullCommand,
            username: username,
            threads: numThreads,
            ioAvailable: ioAvailable,
            readRate: 0,
            writeRate: 0,
            displayName: (fullCommand && fullCommand.length > 15) ? fullCommand.substring(0, 15) + "..." : (fullCommand || "")
        });
    }

    property var pendingProcs: []
    property int threadsTotal: 0

    function addProc(proc) {
        pendingProcs.push(proc);
    }

    function applySorting() {
        const procs = pendingProcs.slice();
        pendingProcs = [];
        const ioCurrent = procIoCurrent;
        procIoCurrent = {};
        if (procs.length === 0)
            return;

        const ioElapsed = root.procIoElapsed;
        if (ioElapsed > 0) {
            for (const p of procs) {
                const cur = ioCurrent[p.pid];
                const prev = procIoPrev[p.pid];
                if (!cur || !prev || !cur.available || !prev.available) {
                    p.readRate = 0;
                    p.writeRate = 0;
                    continue;
                }
                p.readRate = Math.max(0, (cur.read - prev.read) / ioElapsed);
                p.writeRate = Math.max(0, (cur.write - prev.write) / ioElapsed);
            }
        }
        procIoPrev = ioCurrent;

        const currentTicks = procCpuTicks;
        const previousTicks = procPrevCpuTicks;
        const scanWall = root.lastProcScanWall;

        for (const p of procs) {
            const cur = currentTicks[p.pid];
            if (cur === undefined)
                continue;
            const previous = previousTicks[p.pid];
            if (previous === undefined)
                continue;
            const elapsed = (scanWall - previous.wall) / 1000;
            if (elapsed < root.procMinCpuInterval)
                continue;
            p.cpu = Math.round((Math.max(0, cur - previous.ticks) / elapsed / root.clkTicksPerSecond) * 1000) / 10;
        }

        if (Object.keys(currentTicks).length > 0) {
            const nextTicks = {};
            for (const pid in currentTicks)
                nextTicks[pid] = {ticks: currentTicks[pid], wall: scanWall};
            procPrevCpuTicks = nextTicks;
        }
        procCpuTicks = {};

        threadCount = threadsTotal;
        threadsTotal = 0;

        procs.sort((a, b) => compareProcesses(a, b));

        allProcesses = procs;
        processes = procs.slice(0, processLimit);
    }

    function compareProcesses(a, b) {
        let valueA, valueB, result;
        switch (currentSort) {
        case "cpu":
            valueA = a.cpu || 0;
            valueB = b.cpu || 0;
            result = valueB - valueA;
            break;
        case "memory":
            valueA = a.memoryKB || 0;
            valueB = b.memoryKB || 0;
            result = valueB - valueA;
            break;
        case "io":
            valueA = Math.max(a.readRate || 0, a.writeRate || 0);
            valueB = Math.max(b.readRate || 0, b.writeRate || 0);
            result = valueB - valueA;
            break;
        case "name":
            valueA = (a.displayCommand || a.command || "").toLowerCase();
            valueB = (b.displayCommand || b.command || "").toLowerCase();
            result = valueA.localeCompare(valueB);
            break;
        case "pid":
            valueA = a.pid || 0;
            valueB = b.pid || 0;
            result = valueA - valueB;
            break;
        default:
            return 0;
        }
        return sortAscending ? -result : result;
    }

    function isGroupableProcess(proc) {
        if (!proc || proc.pid <= 2)
            return false;
        const cmd = (proc.command || "").toLowerCase();
        if (cmd.includes("systemd") || cmd.includes("kthreadd") || cmd === "init")
            return false;
        for (const entry of nonGroupableCommands) {
            if (cmd.startsWith(entry))
                return false;
        }
        return true;
    }

    function groupProcesses(list) {
        if (!list || list.length === 0)
            return [];

        const pids = {};
        const childrenOf = {};
        for (const proc of list) {
            pids[proc.pid] = true;
            const ppid = proc.ppid ?? 0;
            if (!childrenOf[ppid])
                childrenOf[ppid] = [];
            childrenOf[ppid].push(proc);
        }

        const descendantCache = {};
        function descendantsOf(pid) {
            if (descendantCache[pid])
                return descendantCache[pid];
            const found = [];
            const seen = { [pid]: true };
            const stack = (childrenOf[pid] || []).slice();
            while (stack.length > 0) {
                const node = stack.pop();
                if (seen[node.pid])
                    continue;
                seen[node.pid] = true;
                found.push(node);
                for (const child of (childrenOf[node.pid] || [])) {
                    if (!seen[child.pid])
                        stack.push(child);
                }
            }
            descendantCache[pid] = found;
            return found;
        }

        const rows = [];
        const visited = {};

        function emitRow(proc, children) {
            let cpu = proc.cpu || 0;
            let memoryKB = proc.memoryKB || 0;
            let readRate = proc.readRate || 0;
            let writeRate = proc.writeRate || 0;
            for (const child of children) {
                cpu += child.cpu || 0;
                memoryKB += child.memoryKB || 0;
                readRate += child.readRate || 0;
                writeRate += child.writeRate || 0;
                visited[child.pid] = true;
            }
            rows.push({
                pid: proc.pid,
                process: proc,
                children: children,
                isGroup: children.length > 0,
                childCount: children.length,
                cpu: Math.round(cpu * 10) / 10,
                memoryKB: memoryKB,
                readRate: readRate,
                writeRate: writeRate,
                ioAvailable: proc.ioAvailable === true
            });
        }

        function emit(proc) {
            if (visited[proc.pid])
                return;
            visited[proc.pid] = true;

            const kids = (childrenOf[proc.pid] || []).filter(child => !visited[child.pid]);
            if (isGroupableProcess(proc) && kids.length > 0) {
                emitRow(proc, descendantsOf(proc.pid));
                return;
            }

            emitRow(proc, []);
            for (const kid of kids)
                emit(kid);
        }

        for (const proc of list) {
            if (!pids[proc.ppid ?? 0])
                emit(proc);
        }
        for (const proc of list)
            emit(proc);

        return rows;
    }

    function startGpuHwmonScan() {
        gpuHwmonQueue = Object.keys(gpuCards).filter(pciId => !gpuHwmonPaths[pciId]);
        gpuHwmonQueueIndex = 0;
        scanNextGpuHwmon();
    }

    function scanNextGpuHwmon() {
        while (gpuHwmonQueueIndex < gpuHwmonQueue.length) {
            const pciId = gpuHwmonQueue[gpuHwmonQueueIndex];
            const card = gpuCards[pciId];
            if (card && card.cardName) {
                gpuHwmonScanPciId = pciId;
                gpuHwmonListProcess.command = ["ls", "/sys/class/drm/" + card.cardName + "/device/hwmon"];
                gpuHwmonListProcess.running = true;
                return;
            }
            gpuHwmonQueueIndex++;
        }
    }

    function refreshGpuTemps() {
        const updated = availableGpus.slice();
        let changed = false;
        let nvidiaNeeded = false;

        for (let i = 0; i < updated.length; i++) {
            const gpu = updated[i];
            if (!gpuPciIds.includes(gpu.pciId))
                continue;

            if ((gpu.vendor && gpu.vendor.indexOf("10de") !== -1)) {
                nvidiaNeeded = true;
                continue;
            }

            const hwmonPath = gpuHwmonPaths[gpu.pciId];
            let temp = 0;
            if (hwmonPath) {
                const content = readFile(hwmonPath + "/temp1_input");
                temp = parseInt(content, 10) > 0 ? Math.round(parseInt(content, 10) / 1000) : 0;
            }
            if (temp > 0 && temp !== gpu.temperature) {
                updated[i] = Object.assign({}, gpu, {temperature: temp});
                changed = true;
            }
        }

        if (changed)
            availableGpus = updated;

        if (!nvidiaNeeded || !nvidiaSmiAvailable || nvidiaSmiInFlight)
            return;
        const now = Date.now();
        if (now - root.nvidiaSmiLastRun < root.nvidiaSmiMinInterval)
            return;
        nvidiaSmiInFlight = true;
        nvidiaSmiLastRun = now;
        nvidiaSmiProcess.running = true;
    }

    function applyNvidiaTemps(content) {
        const lines = content.split("\n");
        const updated = availableGpus.slice();
        let changed = false;
        let idx = 0;

        for (const line of lines) {
            const parts = line.trim().split(",");
            if (parts.length >= 1 && idx < updated.length) {
                const gpu = updated[idx];
                if (gpuPciIds.includes(gpu.pciId) && gpu.vendor && gpu.vendor.indexOf("10de") !== -1) {
                    const temp = parseFloat(parts[parts.length - 1]);
                    if (temp >= 0 && temp !== gpu.temperature) {
                        updated[idx] = Object.assign({}, gpu, {temperature: temp});
                        changed = true;
                    }
                }
                idx++;
            }
        }

        if (changed)
            availableGpus = updated;
        nvidiaSmiInFlight = false;
    }

    function addToHistory(array, value) {
        array.push(value);
        if (array.length > historySize) {
            array.shift();
        }
    }

    function resolveProcessName(comm, binaryName) {
        if (!comm)
            return binaryName;
        if (!binaryName || comm === binaryName)
            return comm;
        if (comm.length === 15 && binaryName.startsWith(comm))
            return binaryName;
        return comm;
    }

    function getProcessIcon(command) {
        const cmd = command.toLowerCase();
        if (cmd.includes("firefox") || cmd.includes("chrome") || cmd.includes("browser") || cmd.includes("chromium")) {
            return "web";
        }
        if (cmd.includes("code") || cmd.includes("editor") || cmd.includes("vim")) {
            return "code";
        }
        if (cmd.includes("terminal") || cmd.includes("bash") || cmd.includes("zsh")) {
            return "terminal";
        }
        if (cmd.includes("music") || cmd.includes("audio") || cmd.includes("spotify")) {
            return "music_note";
        }
        if (cmd.includes("video") || cmd.includes("vlc") || cmd.includes("mpv")) {
            return "play_circle";
        }
        if (cmd.includes("systemd") || cmd.includes("elogind") || cmd.includes("kernel") || cmd.includes("kthread") || cmd.includes("kworker")) {
            return "settings";
        }
        return "memory";
    }

    function formatCpuUsage(cpu) {
        return (cpu || 0).toFixed(1) + "%";
    }

    function formatMemoryUsage(memoryKB) {
        const mem = memoryKB || 0;
        if (mem < 1024) {
            return mem.toFixed(0) + " KB";
        } else if (mem < 1024 * 1024) {
            return (mem / 1024).toFixed(1) + " MB";
        } else {
            return (mem / (1024 * 1024)).toFixed(1) + " GB";
        }
    }

    function formatIoRate(bytesPerSecond) {
        const bytes = bytesPerSecond || 0;
        if (bytes < 1024) {
            return bytes.toFixed(0) + " B/s";
        } else if (bytes < 1024 * 1024) {
            return (bytes / 1024).toFixed(1) + " KB/s";
        } else if (bytes < 1024 * 1024 * 1024) {
            return (bytes / (1024 * 1024)).toFixed(1) + " MB/s";
        } else {
            return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB/s";
        }
    }

    function formatSystemMemory(memoryKB) {
        const mem = memoryKB || 0;
        if (mem === 0) {
            return "--";
        }
        if (mem < 1024 * 1024) {
            return (mem / 1024).toFixed(0) + " MB";
        } else {
            return (mem / (1024 * 1024)).toFixed(1) + " GB";
        }
    }

    function killProcess(pid, force) {
        if (pid <= 0)
            return;
        if (force)
            Quickshell.execDetached(["kill", "-9", pid.toString()]);
        else
            Quickshell.execDetached("kill", [pid.toString()]);
    }

    function updateUptime() {
        if (!bootEpoch || bootEpoch <= 0) {
            uptime = "";
            shortUptime = "";
            return;
        }

        const now = Math.floor(Date.now() / 1000);
        const seconds = Math.max(0, now - bootEpoch);
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);

        const parts = [];
        if (days > 0)
            parts.push(`${days} day${days === 1 ? "" : "s"}`);
        if (hours > 0)
            parts.push(`${hours} hour${hours === 1 ? "" : "s"}`);
        if (minutes > 0)
            parts.push(`${minutes} minute${minutes === 1 ? "" : "s"}`);

        uptime = parts.length > 0 ? `up ${parts.join(", ")}` : `up ${seconds} seconds`;

        let shortStr = "up";
        if (days > 0)
            shortStr += ` ${days}d`;
        if (hours > 0)
            shortStr += ` ${hours}h`;
        if (minutes > 0)
            shortStr += ` ${minutes}m`;
        shortUptime = shortStr;
    }

    function setSortBy(newSortBy) {
        if (newSortBy !== currentSort) {
            currentSort = newSortBy;
            sortAscending = false;
            applySorting();
        }
    }

    function toggleSort(column) {
        if (column === currentSort) {
            sortAscending = !sortAscending;
        } else {
            currentSort = column;
            sortAscending = false;
        }
        applySorting();
    }

    function parseOsRelease(content) {
        if (!content)
            return;
        let prettyName = "";
        let name = "";
        for (const line of content.split("\n")) {
            const trimmedLine = line.trim();
            if (trimmedLine.startsWith("PRETTY_NAME=")) {
                prettyName = trimmedLine.substring(12).replace(/^["']|["']$/g, "");
            } else if (trimmedLine.startsWith("NAME=")) {
                name = trimmedLine.substring(5).replace(/^["']|["']$/g, "");
            }
        }
        distribution = prettyName || name || "Linux";
        console.info("SysMonitorService: Detected distribution:", distribution);
    }

    function parsePasswd(content) {
        if (!content)
            return;
        const map = {};
        for (const line of content.split("\n")) {
            if (!line.trim())
                continue;
            const parts = line.split(":");
            if (parts.length >= 3) {
                map[parts[2]] = parts[0];
            }
        }
        passwdMap = map;
    }

    function initializeSystemMetadata() {
        if (systemInitialized)
            return;
        systemInitialized = true;

        parseOsRelease(readFile("/etc/os-release"));
        parsePasswd(readFile("/etc/passwd"));
        kernelVersion = readFile("/proc/sys/kernel/osrelease").trim();
        hostname = readFile("/proc/sys/kernel/hostname").trim();
        motherboard = (readFile("/sys/class/dmi/id/board_vendor").trim() + " " + readFile("/sys/class/dmi/id/board_name").trim()).trim();
        biosVersion = readFile("/sys/class/dmi/id/bios_version").trim();
        unameProcess.running = true;
        if (nvidiaSmiCheck.running === false) {
            nvidiaSmiCheck.running = true;
        }
    }

    function initializeGpuFromDrm(drmText) {
        const cards = {};
        let nvidiaCount = 0;

        for (const entry of drmText.split("\n")) {
            const name = entry.trim();
            if (!name.startsWith("card"))
                continue;

            const basePath = "/sys/class/drm/" + name + "/device";
            const classContent = readFile(basePath + "/class");
            if (!/0x03/.test(classContent))
                continue;

            const uevent = readFile(basePath + "/uevent");
            let pciId = "";
            let driver = "";
            let vendor = "";
            for (const line of uevent.split("\n")) {
                if (line.startsWith("PCI_SLOT_NAME=")) {
                    pciId = line.substring("PCI_SLOT_NAME=".length);
                } else if (line.startsWith("DRIVER=")) {
                    driver = line.substring("DRIVER=".length);
                }
            }
                if (pciId) {
                    vendor = readFile(basePath + "/vendor").trim().replace("0x", "");
                    if (vendor === "10de") {
                        nvidiaCount++;
                    }

                    cards[pciId] = {
                        cardName: name,
                        driver: driver,
                        vendor: vendor
                    };
                    root.addGpuPciId(pciId);
                }
        }

        gpuCards = cards;
        gpuHwmonPaths = {};
        nvidiaGpuCount = nvidiaCount;
        gpuInitialized = true;
        startGpuHwmonScan();

        if (lspciAvailable && root.lspciText) {
            buildGpusFromLspci(lspciText);
        }

        if (SessionData.enabledGpuPciIds && SessionData.enabledGpuPciIds.length > 0) {
            for (const pciId of SessionData.enabledGpuPciIds) {
                if (!gpuPciIds.includes(pciId)) {
                    gpuPciIds.push(pciId);
                }
            }
        }
    }

    function buildGpusFromLspci(content) {
        const list = [];
        for (const line of content.split("\n")) {
            const trimmed = line.trim();
            if (!trimmed)
                continue;
            const parts = trimmed.split(/\s+/);
            const pciId = parts[0];
            if (!gpuCards[pciId])
                continue;

            const colonIdx = trimmed.indexOf("]:");
            let name = colonIdx >= 0 ? trimmed.substring(colonIdx + 2).trim() : trimmed.substring(parts[0].length).trim();
            name = name.replace(/\s*\[[0-9a-f]{2,4}:[0-9a-f]{2,4}\]\s*$/i, "").trim();

            list.push({
                driver: gpuCards[pciId].driver || "",
                vendor: gpuCards[pciId].vendor || "",
                displayName: name || "GPU",
                fullName: name || "GPU",
                pciId: pciId,
                temperature: 0
            });
        }
        if (list.length === 0) {
            for (const pciId in gpuCards) {
                const card = gpuCards[pciId];
                list.push({
                    driver: card.driver || "",
                    vendor: card.vendor || "",
                    displayName: "GPU " + pciId,
                    fullName: "GPU " + pciId,
                    pciId: pciId,
                    temperature: 0
                });
            }
        }
        availableGpus = list;
    }

    FileView {
        id: fileReader
        blockLoading: true
        blockWrites: true
        printErrors: false
        path: ""
    }

    Process {
        id: blockDeviceListProcess
        command: ["ls", "/sys/block"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("SysMonitorService: Failed to list block devices");
                blockScanInFlight = false;
                blockScanBackoff = Math.min(root.blockScanMaxBackoff, root.blockScanBackoff === 0 ? 5000 : root.blockScanBackoff * 2);
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseBlockDeviceList(text);
            }
        }
    }

    Process {
        id: processDetailsProcess
        property int pid: 0
        command: ["sh", "-c", "d=/proc/$1; [ -d \"$d\" ] || exit 1; printf 'cwd\\t%s\\n' \"$(readlink $d/cwd 2>/dev/null)\"; printf 'exe\\t%s\\n' \"$(readlink $d/exe 2>/dev/null)\"; printf 'fds\\t%s\\n' \"$(ls -1 $d/fd 2>/dev/null | wc -l)\"; printf 'threads\\t%s\\n' \"$(awk '/^Threads:/{print $2}' $d/status 2>/dev/null)\"; printf 'state\\t%s\\n' \"$(awk '/^State:/{sub(/^State:[\\\\t ]+/,\"\"); print}' $d/status 2>/dev/null)\"; printf 'cmdline\\t%s\\n' \"$(tr '\\0' ' ' < $d/cmdline 2>/dev/null)\"", "sh", pid.toString()]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("SysMonitorService: process details unavailable for pid", pid);
                processDetails = {};
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseProcessDetails(text);
            }
        }
    }

    Process {
        id: dfProcess
        command: ["df", "-kPT"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("SysMonitorService: df failed with exit code:", exitCode);
                dfInFlight = false;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseDf(text);
            }
        }
    }

    property bool dfInFlight: false

    Process {
        id: procTableProcess
        command: ["sh", "-c",
            "for p in /proc/[0-9]*; do stat=$(< \"$p/stat\") 2>/dev/null || continue; pid=${p##*/}; comm=${stat#*\"(\"}; comm=${comm%\")\"*}; rest=${stat##*\") \"}; set -- $rest; sppid=$2; sutime=${12}; sstime=${13}; snthreads=${18}; status=$(< \"$p/status\") 2>/dev/null || continue; rss=\"\"; uid=\"\"; case $status in *VmRSS:*) t=${status#*VmRSS:}; t=${t%%$'\\n'*}; set -- $t; rss=$1 ;; esac; case $status in *Uid:*) t=${status#*Uid:}; t=${t%%$'\\n'*}; set -- $t; uid=$1 ;; esac; ioa=0; rb=0; wb=0; if [ \"$sppid\" != 2 ] && io=$(< \"$p/io\") 2>/dev/null; then case $io in *read_bytes:*) t=${io#*read_bytes:}; t=${t%%$'\\n'*}; set -- $t; rb=$1; ioa=1 ;; esac; case $io in *write_bytes:*) t=${io#*write_bytes:}; t=${t%%$'\\n'*}; set -- $t; wb=$1 ;; esac; fi; cmd=\"\"; IFS= read -r -d \"\" cmd < \"$p/cmdline\" 2>/dev/null; cmd=${cmd//$'\\t'/ }; cmd=${cmd//$'\\n'/ }; printf \"%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n\" \"$pid\" \"$comm\" \"$sppid\" \"$sutime\" \"$sstime\" \"$snthreads\" \"$rss\" \"$uid\" \"$rb\" \"$wb\" \"$ioa\" \"$cmd\"; done"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                procScanInFlight = false;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseProcTable(text);
            }
        }
    }

    Process {
        id: hwmonListProcess
        command: ["ls", "/sys/class/hwmon"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("SysMonitorService: Failed to list hwmon devices");
                hwmonListScanning = false;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.hwmonList = root.parseHwmonList(text);
                root.hwmonListScanning = false;
                root.parseCpuTemperature();
            }
        }
    }

    Process {
        id: gpuHwmonListProcess
        command: ["ls", "/sys/class/drm"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("SysMonitorService: Failed to list gpu hwmon dir");
                gpuHwmonQueueIndex++;
                scanNextGpuHwmon();
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const entry = line.trim();
                    if (entry.startsWith("hwmon")) {
                        const pciId = root.gpuHwmonScanPciId;
                        const card = root.gpuCards[pciId];
                        if (card) {
                            root.gpuHwmonPaths[pciId] = "/sys/class/drm/" + card.cardName + "/device/hwmon/" + entry;
                        }
                        break;
                    }
                }
                root.gpuHwmonQueueIndex++;
                root.scanNextGpuHwmon();
            }
        }
    }

    Process {
        id: lsDrmProcess
        command: ["ls", "/sys/class/drm"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("SysMonitorService: Failed to list drm devices");
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.initializeGpuFromDrm(text);
            }
        }
    }

    Process {
        id: unameProcess
        command: ["uname", "-m"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("SysMonitorService: uname failed");
            }
        }
        stdout: StdioCollector {
            onStreamFinished: root.architecture = text.trim()
        }
    }

    Process {
        id: lspciProcess
        command: ["lspci", "-nn", "-D"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("SysMonitorService: lspci failed, GPU names may be generic");
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.lspciText = text;
                root.lspciAvailable = true;
                if (root.gpuInitialized) {
                    root.buildGpusFromLspci(text);
                }
            }
        }
    }

    Process {
        id: nvidiaSmiCheck
        command: ["sh", "-c", "command -v nvidia-smi"]
        running: false
        onExited: exitCode => {
            root.nvidiaSmiAvailable = exitCode === 0;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.nvidiaSmiAvailable = text.trim().length > 0;
            }
        }
    }

    property bool nvidiaSmiInFlight: false

    Process {
        id: nvidiaSmiProcess
        command: ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                nvidiaSmiInFlight = false;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.applyNvidiaTemps(text);
            }
        }
    }

    Timer {
        id: updateTimer
        interval: root.updateInterval
        running: root.monitorAvailable && root.refCount > 0 && root.enabledModules.length > 0
        repeat: true
        onTriggered: root.updateAllStats()
    }

    Timer {
        id: uptimeTimer
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateUptime()
    }

    Component.onCompleted: {
        initializeSystemMetadata();
        hwmonListProcess.running = true;
        lsDrmProcess.running = true;
        startBlockDeviceScan();
        try {
            lspciProcess.running = true;
        } catch (e) {
            lspciAvailable = false;
        }
    }
}