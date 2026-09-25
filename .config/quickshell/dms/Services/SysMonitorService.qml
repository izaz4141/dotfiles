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
    property var lastDiskStats: null
    property var diskMounts: []
    property var diskDevices: []

    property var processes: []
    property var allProcesses: []
    property string currentSort: "cpu"
    property bool sortAscending: false
    property var availableGpus: []

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
    property real lastTickWall: 0

    property var pidList: []
    property var procCpuTicks: ({})
    property var procPrevCpuTicks: ({})
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
        } else if (gpuPciIds.length > 0 && refCount > 0) {
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
            parseDiskStats(readFile("/proc/diskstats"), elapsed);
        }

        if (isModuleEnabled("diskmounts")) {
            if (!dfInFlight) {
                dfInFlight = true;
                dfProcess.running = true;
            }
        }

        if (isModuleEnabled("processes")) {
            if (!procScanInFlight) {
                procScanInFlight = true;
                threadsTotal = 0;
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

    function parseCpu(statContent, cpuinfoContent) {
        if (!statContent)
            return;

        const lines = statContent.split("\n");
        let cpuTotal = 0;
        let cpuBusy = 0;
        let btime = 0;
        const perCore = [];

        for (const line of lines) {
            if (line.startsWith("cpu ")) {
                const parts = line.trim().split(/\s+/).slice(1);
                cpuTotal = parts.reduce((a, b) => a + parseInt(b, 10) || 0, 0);
                cpuBusy = cpuTotal - (parseInt(parts[3], 10) || 0) - (parseInt(parts[4], 10) || 0);
            } else if (/^cpu\d+ /.test(line)) {
                const parts = line.trim().split(/\s+/).slice(1);
                const total = parts.reduce((a, b) => a + parseInt(b, 10) || 0, 0);
                const busy = total - (parseInt(parts[3], 10) || 0) - (parseInt(parts[4], 10) || 0);
                perCore.push({total: total, busy: busy});
            } else if (line.startsWith("btime")) {
                btime = parseInt(line.trim().split(/\s+/)[1], 10) || 0;
            }
        }

        if (cpuTotal > 0) {
            if (root.cpuLast) {
                const totalDelta = cpuTotal - root.cpuLast.total;
                const busyDelta = cpuBusy - root.cpuLast.busy;
                if (totalDelta > 0) {
                    cpuUsage = Math.round((busyDelta / totalDelta) * 1000) / 10;
                    cpuTotalTicksDelta = totalDelta;
                }
            } else {
                cpuTotalTicksDelta = 0;
            }
            root.cpuLast = {total: cpuTotal, busy: cpuBusy};
        }

        if (perCore.length > 0 && root.perCoreLast) {
            const usage = [];
            for (let i = 0; i < Math.min(perCore.length, root.perCoreLast.length); i++) {
                const totalDelta = perCore[i].total - root.perCoreLast[i].total;
                const busyDelta = perCore[i].busy - root.perCoreLast[i].busy;
                usage.push(totalDelta > 0 ? Math.round((busyDelta / totalDelta) * 1000) / 10 : 0);
            }
            perCoreCpuUsage = usage;
        } else if (root.perCoreLast === null && perCore.length > 0) {
            perCoreCpuUsage = new Array(perCore.length).fill(0);
        }
        root.perCoreLast = perCore;

        if (cpuinfoContent) {
            let model = "";
            let mhzTotal = 0;
            let mhzCount = 0;
            let cores = 0;
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
                    cores++;
                }
            }
            cpuModel = model || cpuModel;
            if (cores > 0)
                cpuCores = cores;
            cpuFrequency = mhzCount > 0 ? Math.round(mhzTotal / mhzCount) : 0;
        }

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

    function parseDiskStats(content, elapsed) {
        if (!content)
            return;
        const lines = content.split("\n");
        let totalRead = 0;
        let totalWrite = 0;
        const devices = [];

        for (const line of lines) {
            if (!line.trim())
                continue;
            const parts = line.trim().split(/\s+/);
            if (parts.length < 10)
                continue;
            const name = parts[2];
            if (name.startsWith("loop") || name.startsWith("ram") || name.startsWith("fd"))
                continue;
            const readSectors = parseFloat(parts[5]) || 0;
            const writeSectors = parseFloat(parts[9]) || 0;
            const readBytes = readSectors * 512;
            const writeBytes = writeSectors * 512;
            totalRead += readBytes;
            totalWrite += writeBytes;
            devices.push({name: name, read: readBytes, write: writeBytes});
        }

        diskDevices = devices;

        if (lastDiskStats && elapsed > 0) {
            const readDelta = Math.max(0, totalRead - lastDiskStats.read);
            const writeDelta = Math.max(0, totalWrite - lastDiskStats.write);
            diskReadRate = readDelta / elapsed;
            diskWriteRate = writeDelta / elapsed;
            addToHistory(diskHistory.read, diskReadRate / (1024 * 1024));
            addToHistory(diskHistory.write, diskWriteRate / (1024 * 1024));
        } else {
            diskReadRate = 0;
            diskWriteRate = 0;
        }

        lastDiskStats = {read: totalRead, write: totalWrite};
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
            if (parts.length < 6)
                continue;
            const device = parts[0];
            if (device === "tmpfs" || device === "devtmpfs" || device === "sysfs" || device === "proc" ||
                device === "cgroup" || device === "cgroup2" || device === "devpts" || device === "mqueue" ||
                device === "securityfs" || device === "debugfs" || device === "tracefs" || device === "fusectl" ||
                device === "binfmt_misc" || device === "efivarfs" || device === "hugetlbfs" || device === "configfs" ||
                device === "pstore" || device === "autofs" || device === "nsfs" || device === "bpf" || device === "rpc_pipefs")
                continue;

            const usedKB = parseFloat(parts[2]) || 0;
            const availKB = parseFloat(parts[3]) || 0;
            const totalKB = usedKB + availKB;
            const mountPoint = parts.slice(5).join(" ");
            const pct = parts[4];

            const toGB = kb => Math.round((kb / (1024 * 1024)) * 10) / 10;

            mounts.push({
                mount: mountPoint,
                mountpoint: mountPoint,
                device: device,
                percent: pct,
                used: toGB(usedKB),
                avail: toGB(availKB),
                size: toGB(totalKB),
                total: toGB(totalKB)
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
        if (parts.length < 9)
            return;

        const pid = parseInt(parts[0], 10) || 0;
        const comm = parts[1];
        const ppid = parseInt(parts[2], 10) || 0;
        const utime = parseInt(parts[3], 10) || 0;
        const stime = parseInt(parts[4], 10) || 0;
        const numThreads = parseInt(parts[5], 10) || 0;
        const memoryKB = parseInt(parts[6], 10) || 0;
        const uidStr = parts[7];
        const cmdline = parts[8];
        const ticks = utime + stime;

        const fullCommand = cmdline || comm;
        const command = cmdline ? cmdline.split(/\s+/)[0].replace(/^.*\/([^/]+)$/, (m, p1) => p1) : comm;
        const username = (passwdMap[uidStr] || "root");

        procCpuTicks[pid] = ticks;
        threadsTotal += numThreads;

        addProc({
            pid: pid,
            ppid: ppid,
            cpu: 0,
            memoryPercent: totalMemoryKB > 0 ? Math.round((memoryKB / totalMemoryKB) * 10000) / 100 : 0,
            memoryKB: memoryKB,
            command: command,
            fullCommand: fullCommand,
            username: username,
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
        if (procs.length === 0)
            return;

        const totalDelta = root.cpuTotalTicksDelta;
        if (totalDelta > 0) {
            for (const p of procs) {
                const cur = procCpuTicks[p.pid] || 0;
                const prev = procPrevCpuTicks[p.pid] !== undefined ? procPrevCpuTicks[p.pid] : cur;
                if (cur > prev) {
                    p.cpu = Math.round(((cur - prev) / totalDelta) * Math.max(1, cpuCores) * 1000) / 10;
                }
            }
        }

        procPrevCpuTicks = procCpuTicks;
        procCpuTicks = {};

        threadCount = threadsTotal;
        threadsTotal = 0;

        const asc = sortAscending;
        procs.sort((a, b) => {
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
            case "name":
                valueA = (a.command || "").toLowerCase();
                valueB = (b.command || "").toLowerCase();
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
            return asc ? -result : result;
        });

        allProcesses = procs;
        processes = procs.slice(0, processLimit);
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

        if (nvidiaNeeded && nvidiaSmiAvailable) {
            if (!nvidiaSmiInFlight) {
                nvidiaSmiInFlight = true;
                nvidiaSmiProcess.running = true;
            }
        }
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

    function killProcess(pid) {
        if (pid > 0) {
            Quickshell.execDetached("kill", [pid.toString()]);
        }
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
        id: dfProcess
        command: ["df", "-kP"]
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
            "for p in /proc/[0-9]*; do stat=$(< \"$p/stat\") 2>/dev/null || continue; pid=${p##*/}; comm=${stat#*\"(\"}; comm=${comm%\")\"*}; rest=${stat##*\") \"}; set -- $rest; sppid=$2; sutime=${12}; sstime=${13}; snthreads=${18}; status=$(< \"$p/status\") 2>/dev/null || continue; rss=\"\"; uid=\"\"; while IFS= read -r line; do case \"$line\" in VmRSS:*) set -- $line; rss=$2 ;; Uid:*) set -- $line; uid=$2 ;; esac; done << EOF\n$status\nEOF\ncmd=$(tr \"\\0\" \" \" < \"$p/cmdline\" 2>/dev/null | tr \"\\t\\n\" \"  \"); printf \"%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n\" \"$pid\" \"$comm\" \"$sppid\" \"$sutime\" \"$sstime\" \"$snthreads\" \"$rss\" \"$uid\" \"$cmd\"; done"]
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
        triggeredOnStart: true
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
        try {
            lspciProcess.running = true;
        } catch (e) {
            lspciAvailable = false;
        }
    }
}