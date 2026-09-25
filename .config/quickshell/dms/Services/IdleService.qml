pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common

Singleton {
    id: root

    readonly property bool hypridleAvailable: _hypridleProbeDetected

    readonly property bool idleInhibitorAvailable: {
        try {
            return typeof IdleInhibitor !== "undefined";
        } catch (e) {
            return false;
        }
    }

    readonly property bool isOnBattery: BatteryService.batteryAvailable && !BatteryService.isPluggedIn
    readonly property int monitorTimeout: isOnBattery ? SettingsData.batteryMonitorTimeout : SettingsData.acMonitorTimeout
    readonly property int lockTimeout: isOnBattery ? SettingsData.batteryLockTimeout : SettingsData.acLockTimeout
    readonly property int suspendTimeout: isOnBattery ? SettingsData.batterySuspendTimeout : SettingsData.acSuspendTimeout
    readonly property int suspendBehavior: isOnBattery ? SettingsData.batterySuspendBehavior : SettingsData.acSuspendBehavior

    readonly property string _configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/hypr"
    readonly property string _configPath: _configDir + "/hypridle.conf"
    readonly property string _lockCommand: "loginctl lock-session $XDG_SESSION_ID"
    readonly property string _unlockCommand: "loginctl unlock-session $XDG_SESSION_ID"
    readonly property string _managedStartMarker: "# === DankMaterialShell idle config (managed) - do not edit manually ==="
    readonly property string _managedEndMarker: "# === End DankMaterialShell idle config (managed) ==="
    property string _lastConfigText: ""
    property string _pendingConfigText: ""
    property string _configReadBuffer: ""
    property bool _hypridleProbeDetected: false
    property bool _configWritePending: false
    property bool _reloadAfterProbe: false

    property bool _dbusMonitorAvailable: false
    property bool _dbusMonitorStarted: false
    property bool _stateMonitorStarted: false
    property bool _inhibitHeaderPending: false
    property bool _uninhibitHeaderPending: false
    property bool _activeChangedPending: false
    property int _inhibitArgIndex: 0
    property var _pendingInhibitApp: ""
    property var _pendingInhibitReason: ""

    property var externalInhibitors: []
    property int _inhibitorCookieCounter: 0

    readonly property bool externalInhibitActive: externalInhibitors.length > 0

    property bool monitorsOff: false

    signal lockRequested
    signal fadeToLockRequested
    signal cancelFadeToLock
    signal fadeToDpmsRequested
    signal cancelFadeToDpms
    signal requestMonitorOff
    signal requestMonitorOn
    signal requestSuspend

    function wake() {
        requestMonitorOn();
    }

    function reapplyDpmsIfNeeded() {
        if (monitorsOff)
            CompositorService.powerOffMonitors();
    }

    function _suspendCommand(behavior) {
        if (behavior === SettingsData.SuspendBehavior.Hibernate) {
            if (SettingsData.customPowerActionHibernate.length > 0)
                return SettingsData.customPowerActionHibernate;
            return "systemctl hibernate";
        }
        if (behavior === SettingsData.SuspendBehavior.SuspendThenHibernate)
            return "systemctl suspend-then-hibernate";
        if (SettingsData.customPowerActionSuspend.length > 0)
            return SettingsData.customPowerActionSuspend;
        return "systemctl suspend";
    }

    function _pushLine(lines, indent, text) {
        lines.push(" ".repeat(indent) + text);
    }

    function _appendEntry(lines, indent, key, value) {
        _pushLine(lines, indent, key + " = " + value);
    }

    function _dpmsCommand(action) {
        return `hyprctl dispatch 'hl.dsp.dpms({ action = "${action}" })'`;
    }

    function _onBatteryCondition() {
        return 'for s in /sys/class/power_supply/*/; do t=$(cat $s/type 2>/dev/null); [ "$t" = "Battery" ] || continue; if [ -f $s/status ]; then [ "$(cat $s/status)" = "Discharging" ] && exit 0; elif [ -f $s/online ]; then [ "$(cat $s/online)" = "0" ] && exit 0; fi; done; exit 1';
    }

    function _notOnBatteryCondition() {
        return 'for s in /sys/class/power_supply/*/; do t=$(cat $s/type 2>/dev/null); [ "$t" = "Battery" ] || continue; if [ -f $s/status ]; then [ "$(cat $s/status)" = "Discharging" ] && exit 1; elif [ -f $s/online ]; then [ "$(cat $s/online)" = "0" ] && exit 1; fi; done; exit 0';
    }

    function _appendListener(lines, name, timeout, onTimeout, onResume, conditionCmd) {
        if (timeout <= 0)
            return;
        _pushLine(lines, 0, `## -- ${name}`);
        _pushLine(lines, 0, "listener {");
        _appendEntry(lines, 4, "timeout", timeout);
        if (onTimeout)
            _appendEntry(lines, 4, "on-timeout", onTimeout);
        if (onResume)
            _appendEntry(lines, 4, "on-resume", onResume);
        if (conditionCmd) {
            _appendEntry(lines, 4, "condition_cmd", conditionCmd);
            _appendEntry(lines, 4, "condition_retry", "0");
        }
        _pushLine(lines, 0, "}");
        _pushLine(lines, 0, "");
    }

    function _generateListeners(lines) {
        const dpmsOff = _dpmsCommand("off");
        const dpmsOn = _dpmsCommand("on");
        const lock = root._lockCommand;
        const acSuspend = root._suspendCommand(SettingsData.acSuspendBehavior);
        const batterySuspend = root._suspendCommand(SettingsData.batterySuspendBehavior);
        const acNotOnBattery = _notOnBatteryCondition();
        const batteryOnBattery = _onBatteryCondition();

        const categories = [
            {
                name: "BRIGHTNESS",
                onBattery: { timeout: SettingsData.batteryBrightnessTimeout, onTimeout: `brightnessctl -s set ${SettingsData.batteryBrightnessLevel}%`, onResume: "brightnessctl -r" },
                onAc: { timeout: SettingsData.acBrightnessTimeout, onTimeout: `brightnessctl -s set ${SettingsData.acBrightnessLevel}%`, onResume: "brightnessctl -r" }
            },
            {
                name: "DPMS",
                onBattery: { timeout: SettingsData.batteryMonitorTimeout, onTimeout: dpmsOff, onResume: dpmsOn },
                onAc: { timeout: SettingsData.acMonitorTimeout, onTimeout: dpmsOff, onResume: dpmsOn }
            },
            {
                name: "LOCK",
                onBattery: { timeout: SettingsData.batteryLockTimeout, onTimeout: lock, onResume: "" },
                onAc: { timeout: SettingsData.acLockTimeout, onTimeout: lock, onResume: "" }
            },
            {
                name: "SUSPEND",
                onBattery: { timeout: SettingsData.batterySuspendTimeout, onTimeout: batterySuspend, onResume: "" },
                onAc: { timeout: SettingsData.acSuspendTimeout, onTimeout: acSuspend, onResume: "" }
            }
        ];

        for (const cat of categories) {
            const acActive = cat.onAc.timeout > 0;
            const batteryActive = cat.onBattery.timeout > 0;
            if (!acActive && !batteryActive)
                continue;
            const acIdentical = acActive && batteryActive
                && cat.onAc.timeout === cat.onBattery.timeout
                && cat.onAc.onTimeout === cat.onBattery.onTimeout
                && cat.onAc.onResume === cat.onBattery.onResume;
            if (acIdentical) {
                _appendListener(lines, cat.name, cat.onAc.timeout, cat.onAc.onTimeout, cat.onAc.onResume, "");
                continue;
            }
            if (acActive)
                _appendListener(lines, `${cat.name} (AC)`, cat.onAc.timeout, cat.onAc.onTimeout, cat.onAc.onResume, acNotOnBattery);
            if (batteryActive)
                _appendListener(lines, `${cat.name} (BATTERY)`, cat.onBattery.timeout, cat.onBattery.onTimeout, cat.onBattery.onResume, batteryOnBattery);
        }
    }

    function _generateManagedLines() {
        const lines = [];
        _pushLine(lines, 0, root._managedStartMarker);
        _pushLine(lines, 0, "");

        _pushLine(lines, 0, "general {");
        // _appendEntry(lines, 4, "lock_cmd", root._lockCommand);
        // _appendEntry(lines, 4, "unlock_cmd", root._unlockCommand);
        if (SettingsData.lockBeforeSuspend)
            _appendEntry(lines, 4, "before_sleep_cmd", root._lockCommand);
        _appendEntry(lines, 4, "after_sleep_cmd", _dpmsCommand("on"));
        _appendEntry(lines, 4, "ignore_dbus_inhibit", "false");
        _appendEntry(lines, 4, "ignore_systemd_inhibit", "false");
        _appendEntry(lines, 4, "ignore_wayland_inhibit", "false");
        _pushLine(lines, 0, "}");
        _pushLine(lines, 0, "");

        _generateListeners(lines);

        _pushLine(lines, 0, root._managedEndMarker);
        return lines;
    }

    function _findGeneralStart(lines) {
        for (let i = 0; i < lines.length; i++) {
            const t = lines[i].trim();
            if (t.startsWith("general") && t.includes("{"))
                return i;
        }
        return -1;
    }

    function _findLineIndex(lines, needle, startIdx) {
        for (let i = startIdx; i < lines.length; i++) {
            if (lines[i].indexOf(needle) >= 0)
                return i;
        }
        return -1;
    }

    function _mergeConfig(rawText) {
        const raw = (rawText || "").split("\n");
        const managed = _generateManagedLines();

        let prefix = [];
        let suffix = [];
        const startIdx = _findLineIndex(raw, root._managedStartMarker, 0);
        if (startIdx >= 0) {
            prefix = raw.slice(0, startIdx);
            const endIdx = _findLineIndex(raw, root._managedEndMarker, startIdx + 1);
            if (endIdx >= 0)
                suffix = raw.slice(endIdx + 1);
        } else {
            const generalIdx = _findGeneralStart(raw);
            if (generalIdx >= 0)
                prefix = raw.slice(0, generalIdx);
            else
                prefix = raw;
        }

        const merged = [];
        for (const l of prefix) merged.push(l);
        while (merged.length > 0 && merged[merged.length - 1].trim() === "")
            merged.pop();
        if (merged.length > 0)
            merged.push("");
        for (const l of managed) merged.push(l);
        while (suffix.length > 0 && suffix[0].trim() === "")
            suffix.shift();
        if (suffix.length > 0) {
            merged.push("");
            for (const l of suffix) merged.push(l);
        }
        return merged.join("\n").replace(/\n+$/, "\n");
    }

    function _scheduleConfigWrite(content) {
        if (content === _lastConfigText) {
            _syncHypridle(false);
            return;
        }

        _configWritePending = true;
        _pendingConfigText = content;

        var writer = configWriterComponent.createObject(root, {
            path: root._configPath,
            content: content
        });
    }

    function _applyConfig() {
        if (!hypridleAvailable || SettingsData.isGreeterMode)
            return;

        Quickshell.execDetached(["mkdir", "-p", root._configDir]);

        _configReadBuffer = "";
        configReadProcess.running = true;
    }

    function _syncHypridle(reloadIfRunning) {
        _reloadAfterProbe = reloadIfRunning;
        hypridleRunningProbe.running = true;
    }

    function _restartHypridle() {
        Quickshell.execDetached(["sh", "-c", "killall hypridle; sleep 0.2; hypridle"]);
        console.info("IdleService: hypridle config applied and restarted");
    }

    function _startHypridle() {
        Quickshell.execDetached(["hypridle"]);
        console.info("IdleService: hypridle started");
    }

    function _scheduleConfigSync() {
        configSyncDebounce.restart();
    }

    Component {
        id: configWriterComponent
        FileView {
            property string content

            blockWrites: false
            atomicWrites: false

            Component.onCompleted: {
                setText(content);
            }

            onSaved: {
                root._configWritePending = false;
                root._lastConfigText = root._pendingConfigText;
                root._pendingConfigText = "";
                root._syncHypridle(true);
                destroy();
            }

            onSaveFailed: error => {
                root._configWritePending = false;
                root._pendingConfigText = "";
                console.error("IdleService: Failed to write hypridle config:", error);
                destroy();
            }
        }
    }

    Timer {
        id: configSyncDebounce
        interval: 150
        repeat: false
        onTriggered: root._applyConfig()
    }

    Process {
        id: hypridleProbe
        command: ["sh", "-c", "command -v hypridle"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line && line.trim().length > 0) {
                    root._hypridleProbeDetected = true;
                }
            }
        }

        onExited: exitCode => {
            if (exitCode === 0 && root._hypridleProbeDetected) {
                console.info("IdleService: hypridle found - delegating idle management");
                root._applyConfig();
                root._startDbusMonitor();
            } else {
                console.warn("IdleService: hypridle not found in PATH - idle management disabled");
            }
        }
    }

    Process {
        id: hypridleRunningProbe
        command: ["pgrep", "-x", "hypridle"]
        running: false

        onExited: exitCode => {
            if (exitCode !== 0) {
                root._startHypridle();
            } else if (root._reloadAfterProbe) {
                root._restartHypridle();
            }
        }
    }

    Process {
        id: configReadProcess
        command: ["cat", root._configPath]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                root._configReadBuffer += (root._configReadBuffer.length > 0 ? "\n" : "") + line;
            }
        }

        onExited: exitCode => {
            var raw = exitCode === 0 ? root._configReadBuffer : "";
            root._configReadBuffer = "";
            root._scheduleConfigWrite(root._mergeConfig(raw));
        }
    }

    Process {
        id: dbusMonitorProbe
        command: ["sh", "-c", "command -v dbus-monitor"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line && line.trim().length > 0) {
                    root._dbusMonitorAvailable = true;
                }
            }
        }

        onExited: exitCode => {
            if (exitCode === 0 && root._dbusMonitorAvailable) {
                root._startDbusMonitor();
            } else {
                console.info("IdleService: dbus-monitor not found - screensaver state not tracked");
            }
        }
    }

    Process {
        id: dbusMonitorProcess
        command: ["dbus-monitor", "--session", "type='method_call',interface='org.freedesktop.ScreenSaver'"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                root._processMonitorLine(line);
            }
        }

        onExited: () => {
            _scheduleRestart(root._dbusMonitorStarted, () => root._startDbusMonitor(), "dbus-monitor");
        }
    }

    Process {
        id: dbusStateMonitorProcess
        command: ["dbus-monitor", "--session", "type='signal',interface='org.freedesktop.ScreenSaver'"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                root._processStateLine(line);
            }
        }

        onExited: () => {
            _scheduleRestart(root._stateMonitorStarted, () => root._startDbusMonitor(), "dbus state monitor");
        }
    }

    function _scheduleRestart(active, restartFn, label) {
        Qt.callLater(() => {
            if (!root._dbusMonitorAvailable || !active)
                return;
            console.warn("IdleService: " + label + " exited unexpectedly - restarting");
            restartFn();
        });
    }

    function _startDbusMonitor() {
        if (!_dbusMonitorAvailable)
            return;

        if (!_dbusMonitorStarted) {
            _dbusMonitorStarted = true;
            console.info("IdleService: Watching org.freedesktop.ScreenSaver inhibits");
            dbusMonitorProcess.running = true;
        }

        if (!_stateMonitorStarted) {
            _stateMonitorStarted = true;
            dbusStateMonitorProcess.running = true;
        }
    }

    function _processMonitorLine(line) {
        if (line.includes("interface=org.freedesktop.ScreenSaver")) {
            if (line.includes("member=Inhibit")) {
                _inhibitHeaderPending = true;
                _uninhibitHeaderPending = false;
                _inhibitArgIndex = 0;
                _pendingInhibitApp = "";
                _pendingInhibitReason = "";
                return;
            }
            if (line.includes("member=UnInhibit")) {
                _inhibitHeaderPending = false;
                _uninhibitHeaderPending = true;
                return;
            }
        }

        if (_inhibitHeaderPending) {
            const trimmed = line.trim();
            if (trimmed.startsWith("string ")) {
                if (_inhibitArgIndex === 0) {
                    _pendingInhibitApp = _parseMonitorString(trimmed);
                    _inhibitArgIndex = 1;
                } else {
                    _pendingInhibitReason = _parseMonitorString(trimmed);
                    _inhibitArgIndex = 0;
                    _inhibitHeaderPending = false;
                    _addInhibitor(_pendingInhibitApp, _pendingInhibitReason);
                }
            }
            return;
        }

        if (_uninhibitHeaderPending) {
            if (line.trim().startsWith("uint32")) {
                _uninhibitHeaderPending = false;
                _removeInhibitor();
            }
        }
    }

    function _processStateLine(line) {
        if (line.includes("interface=org.freedesktop.ScreenSaver") && line.includes("member=ActiveChanged")) {
            _activeChangedPending = true;
            return;
        }

        if (_activeChangedPending) {
            const trimmed = line.trim();
            if (trimmed.startsWith("boolean ")) {
                _activeChangedPending = false;
                const active = trimmed.substring("boolean ".length).trim() === "true";
                if (root.monitorTimeout > 0)
                    root.monitorsOff = active;
            }
        }
    }

    function _parseMonitorString(value) {
        const match = /^string\s+"((?:\\.|[^"\\])*)"?/.exec(value);
        return match ? match[1] : "";
    }

    function _addInhibitor(appName, reason) {
        const next = externalInhibitors.slice();
        next.push({
            appName: appName || "unknown",
            reason: reason || "",
            cookie: _inhibitorCookieCounter++
        });
        externalInhibitors = next;
    }

    function _removeInhibitor() {
        if (externalInhibitors.length === 0)
            return;
        const next = externalInhibitors.slice();
        next.pop();
        externalInhibitors = next;
    }

    Connections {
        target: SettingsData

        function onAcMonitorTimeoutChanged() { root._scheduleConfigSync(); }
        function onBatteryMonitorTimeoutChanged() { root._scheduleConfigSync(); }
        function onAcLockTimeoutChanged() { root._scheduleConfigSync(); }
        function onBatteryLockTimeoutChanged() { root._scheduleConfigSync(); }
        function onAcSuspendTimeoutChanged() { root._scheduleConfigSync(); }
        function onBatterySuspendTimeoutChanged() { root._scheduleConfigSync(); }
        function onAcSuspendBehaviorChanged() { root._scheduleConfigSync(); }
        function onBatterySuspendBehaviorChanged() { root._scheduleConfigSync(); }
        function onLockBeforeSuspendChanged() { root._scheduleConfigSync(); }
        function onCustomPowerActionLockChanged() { root._scheduleConfigSync(); }
        function onCustomPowerActionSuspendChanged() { root._scheduleConfigSync(); }
        function onCustomPowerActionHibernateChanged() { root._scheduleConfigSync(); }
        function onAcBrightnessLevelChanged() { root._scheduleConfigSync(); }
        function onBatteryBrightnessLevelChanged() { root._scheduleConfigSync(); }
        function onAcBrightnessTimeoutChanged() { root._scheduleConfigSync(); }
        function onBatteryBrightnessTimeoutChanged() { root._scheduleConfigSync(); }
    }

    Connections {
        target: BatteryService

        function onBatteryAvailableChanged() {
            root._scheduleConfigSync();
        }

        function onIsPluggedInChanged() {
            root._scheduleConfigSync();
        }
    }

    Connections {
        target: root

        function onRequestMonitorOff() {
            monitorsOff = true;
            CompositorService.powerOffMonitors();
        }

        function onRequestMonitorOn() {
            monitorsOff = false;
            CompositorService.powerOnMonitors();
        }

        function onRequestSuspend() {
            SessionService.suspendWithBehavior(root.suspendBehavior);
        }
    }

    onExternalInhibitActiveChanged: {
        if (externalInhibitActive) {
            const apps = externalInhibitors.map(i => i.appName).join(", ");
            console.info("IdleService: External idle inhibit active from:", apps || "unknown");
            SessionService.idleInhibited = true;
            SessionService.inhibitReason = "External app: " + (apps || "unknown");
        } else {
            console.info("IdleService: External idle inhibit released");
            SessionService.idleInhibited = false;
            SessionService.inhibitReason = "Keep system awake";
        }
    }
}
