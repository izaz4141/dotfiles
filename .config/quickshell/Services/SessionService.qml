pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.I3
import Quickshell.Wayland
import qs.Common

Singleton {
    id: root

    property bool hasUwsm: false
    property bool isElogind: false
    property bool hibernateSupported: false
    property bool inhibitorAvailable: true
    property bool idleInhibited: false
    property string inhibitReason: "Keep system awake"
    property string nvidiaCommand: ""

    readonly property bool nativeInhibitorAvailable: {
        try {
            return typeof IdleInhibitor !== "undefined";
        } catch (e) {
            return false;
        }
    }

    property bool loginctlAvailable: false
    property bool wtypeAvailable: false
    property bool dbusMonitorAvailable: false
    property string sessionId: ""
    property string sessionPath: ""
    property bool locked: false
    property bool active: false
    property bool idleHint: false
    property bool lockedHint: false
    property bool preparingForSleep: false
    property string sessionType: ""
    property string userName: ""
    property string seat: ""
    property string display: ""

    signal sessionLocked
    signal sessionUnlocked
    signal sessionResumed
    signal loginctlStateChanged

    property bool stateInitialized: false
    property bool _lockMonitorStarted: false
    property bool _sleepMonitorStarted: false
    property bool _sleepArgPending: false

    Timer {
        id: sessionInitTimer
        interval: 200
        running: true
        repeat: false
        onTriggered: {
            detectElogindProcess.running = true;
            detectHibernateProcess.running = true;
            detectPrimeRunProcess.running = true;
            detectWtypeProcess.running = true;
            detectLoginctlProcess.running = true;
            detectDbusMonitorProcess.running = true;
            console.info("SessionService: Native inhibitor available:", nativeInhibitorAvailable);
            if (!SettingsData.loginctlLockIntegration) {
                console.log("SessionService: loginctl lock integration disabled by user");
                return;
            }
        }
    }

    Process {
        id: detectUwsmProcess
        running: false
        command: ["which", "uwsm"]

        onExited: function (exitCode) {
            hasUwsm = (exitCode === 0);
        }
    }

    Process {
        id: detectElogindProcess
        running: false
        command: ["sh", "-c", "ps -eo comm= | grep -E '^(elogind|elogind-daemon)$'"]

        onExited: function (exitCode) {
            console.log("SessionService: Elogind detection exited with code", exitCode);
            isElogind = (exitCode === 0);
        }
    }

    Process {
        id: detectHibernateProcess
        running: false
        command: ["grep", "-q", "disk", "/sys/power/state"]

        onExited: function (exitCode) {
            hibernateSupported = (exitCode === 0);
        }
    }

    Process {
        id: hibernateProcess
        running: false

        property string errorOutput: ""

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => hibernateProcess.errorOutput += data.trim()
        }

        onExited: function (exitCode) {
            if (exitCode === 0) {
                errorOutput = "";
                return;
            }
            ToastService.showError("Hibernate failed", errorOutput);
            errorOutput = "";
        }
    }

    Process {
        id: detectWtypeProcess
        running: false
        command: ["which", "wtype"]
        onExited: exitCode => {
            wtypeAvailable = (exitCode === 0);
        }
    }

    Process {
        id: detectPrimeRunProcess
        running: false
        command: ["which", "prime-run"]

        onExited: function (exitCode) {
            if (exitCode === 0) {
                nvidiaCommand = "prime-run";
            } else {
                detectNvidiaOffloadProcess.running = true;
            }
        }
    }

    Process {
        id: detectNvidiaOffloadProcess
        running: false
        command: ["which", "nvidia-offload"]

        onExited: function (exitCode) {
            if (exitCode === 0) {
                nvidiaCommand = "nvidia-offload";
            }
        }
    }

    Process {
        id: detectLoginctlProcess
        running: false
        command: ["which", "loginctl"]

        onExited: function (exitCode) {
            loginctlAvailable = (exitCode === 0);
            if (loginctlAvailable && dbusMonitorAvailable && SettingsData.loginctlLockIntegration && !stateInitialized) {
                stateInitialized = true;
                startLoginctlMonitors();
                refreshSessionState();
            }
        }
    }

    Process {
        id: detectDbusMonitorProcess
        running: false
        command: ["which", "dbus-monitor"]

        onExited: function (exitCode) {
            dbusMonitorAvailable = (exitCode === 0);
            if (loginctlAvailable && dbusMonitorAvailable && SettingsData.loginctlLockIntegration && !stateInitialized) {
                stateInitialized = true;
                startLoginctlMonitors();
                refreshSessionState();
            }
        }
    }

    Process {
        id: uwsmLogout
        command: ["uwsm", "stop"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim().toLowerCase().includes("not running")) {
                    _logout();
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0) {
                return;
            }
            _logout();
        }
    }

    function escapeShellArg(arg) {
        return "'" + arg.replace(/'/g, "'\\''") + "'";
    }

    function needsShellExecution(prefix) {
        if (!prefix || prefix.length === 0)
            return false;
        return /[;&|<>()$`\\"']/.test(prefix);
    }

    function parseEnvVars(envVarsStr) {
        if (!envVarsStr || envVarsStr.trim().length === 0)
            return {};
        const envObj = {};
        const pairs = envVarsStr.trim().split(/\s+/);
        for (const pair of pairs) {
            const eqIndex = pair.indexOf("=");
            if (eqIndex > 0) {
                const key = pair.substring(0, eqIndex);
                const value = pair.substring(eqIndex + 1);
                envObj[key] = value;
            }
        }
        return envObj;
    }

    function launchDesktopEntry(desktopEntry, useNvidia) {
        let cmd = desktopEntry.command;
        if (useNvidia && nvidiaCommand)
            cmd = [nvidiaCommand].concat(cmd);

        const appId = desktopEntry.id || desktopEntry.execString || desktopEntry.exec || "";
        const override = SessionData.getAppOverride(appId);

        if (override?.extraFlags) {
            const extraArgs = override.extraFlags.trim().split(/\s+/).filter(arg => arg.length > 0);
            cmd = cmd.concat(extraArgs);
        }

        const userPrefix = SettingsData.launchPrefix?.trim() || "";
        const defaultPrefix = Quickshell.env("DMS_DEFAULT_LAUNCH_PREFIX") || "";
        const prefix = userPrefix.length > 0 ? userPrefix : defaultPrefix;
        const workDir = desktopEntry.workingDirectory || Quickshell.env("HOME");
        const cursorEnv = typeof SettingsData.getCursorEnvironment === "function" ? SettingsData.getCursorEnvironment() : {};

        const overrideEnv = override?.envVars ? parseEnvVars(override.envVars) : {};
        const finalEnv = Object.assign({}, cursorEnv, overrideEnv);

        if (desktopEntry.runInTerminal) {
            const terminal = Quickshell.env("TERMINAL") || "xterm";
            const escapedCmd = cmd.map(arg => escapeShellArg(arg)).join(" ");
            const shellCmd = prefix.length > 0 ? `${prefix} ${escapedCmd}` : escapedCmd;
            Quickshell.execDetached({
                command: [terminal, "-e", "sh", "-c", shellCmd],
                workingDirectory: workDir,
                environment: finalEnv
            });
            return;
        }

        if (prefix.length > 0 && needsShellExecution(prefix)) {
            const escapedCmd = cmd.map(arg => escapeShellArg(arg)).join(" ");
            Quickshell.execDetached({
                command: ["sh", "-c", `${prefix} ${escapedCmd}`],
                workingDirectory: workDir,
                environment: finalEnv
            });
            return;
        }

        if (prefix.length > 0)
            cmd = prefix.split(" ").concat(cmd);

        Quickshell.execDetached({
            command: cmd,
            workingDirectory: workDir,
            environment: finalEnv
        });
    }

    function launchDesktopAction(desktopEntry, action, useNvidia) {
        let cmd = action.command;
        if (useNvidia && nvidiaCommand)
            cmd = [nvidiaCommand].concat(cmd);

        const userPrefix = SettingsData.launchPrefix?.trim() || "";
        const defaultPrefix = Quickshell.env("DMS_DEFAULT_LAUNCH_PREFIX") || "";
        const prefix = userPrefix.length > 0 ? userPrefix : defaultPrefix;
        const workDir = desktopEntry.workingDirectory || Quickshell.env("HOME");
        const cursorEnv = typeof SettingsData.getCursorEnvironment === "function" ? SettingsData.getCursorEnvironment() : {};

        if (prefix.length > 0 && needsShellExecution(prefix)) {
            const escapedCmd = cmd.map(arg => escapeShellArg(arg)).join(" ");
            Quickshell.execDetached({
                command: ["sh", "-c", `${prefix} ${escapedCmd}`],
                workingDirectory: workDir,
                environment: cursorEnv
            });
            return;
        }

        if (prefix.length > 0)
            cmd = prefix.split(" ").concat(cmd);

        Quickshell.execDetached({
            command: cmd,
            workingDirectory: workDir,
            environment: cursorEnv
        });
    }

    // * Session management
    function logout() {
        if (hasUwsm) {
            uwsmLogout.running = true;
        }
        _logout();
    }

    function _logout() {
        if (SettingsData.customPowerActionLogout.length === 0) {
            if (CompositorService.isNiri) {
                NiriService.quit();
                return;
            }

            if (CompositorService.isDwl) {
                DwlService.quit();
                return;
            }

            if (CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle) {
                try {
                    I3.dispatch("exit");
                } catch (_) {}
                return;
            }

            HyprlandService.exit();
        } else {
            Quickshell.execDetached(["sh", "-c", SettingsData.customPowerActionLogout]);
        }
    }

    function suspend() {
        if (SettingsData.customPowerActionSuspend.length === 0) {
            Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "suspend"]);
        } else {
            Quickshell.execDetached(["sh", "-c", SettingsData.customPowerActionSuspend]);
        }
    }

    function hibernate() {
        hibernateProcess.errorOutput = "";
        if (SettingsData.customPowerActionHibernate.length > 0) {
            hibernateProcess.command = ["sh", "-c", SettingsData.customPowerActionHibernate];
        } else {
            hibernateProcess.command = [isElogind ? "loginctl" : "systemctl", "hibernate"];
        }
        hibernateProcess.running = true;
    }

    function suspendThenHibernate() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "suspend-then-hibernate"]);
    }

    function suspendWithBehavior(behavior) {
        if (behavior === SettingsData.SuspendBehavior.Hibernate) {
            hibernate();
        } else if (behavior === SettingsData.SuspendBehavior.SuspendThenHibernate) {
            suspendThenHibernate();
        } else {
            suspend();
        }
    }

    function reboot() {
        if (SettingsData.customPowerActionReboot.length === 0) {
            Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "reboot"]);
        } else {
            Quickshell.execDetached(["sh", "-c", SettingsData.customPowerActionReboot]);
        }
    }

    function poweroff() {
        if (SettingsData.customPowerActionPowerOff.length === 0) {
            Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "poweroff"]);
        } else {
            Quickshell.execDetached(["sh", "-c", SettingsData.customPowerActionPowerOff]);
        }
    }

    // * Idle Inhibitor
    signal inhibitorChanged

    function enableIdleInhibit() {
        if (idleInhibited) {
            return;
        }
        console.log("SessionService: Enabling idle inhibit (native:", nativeInhibitorAvailable, ")");
        idleInhibited = true;
        inhibitorChanged();
    }

    function disableIdleInhibit() {
        if (!idleInhibited) {
            return;
        }
        console.log("SessionService: Disabling idle inhibit (native:", nativeInhibitorAvailable, ")");
        idleInhibited = false;
        inhibitorChanged();
    }

    function toggleIdleInhibit() {
        if (idleInhibited) {
            disableIdleInhibit();
        } else {
            enableIdleInhibit();
        }
    }

    function setInhibitReason(reason) {
        inhibitReason = reason;

        if (idleInhibited && !nativeInhibitorAvailable) {
            const wasActive = idleInhibited;
            idleInhibited = false;

            Qt.callLater(() => {
                if (wasActive) {
                    idleInhibited = true;
                }
            });
        }
    }

    Process {
        id: idleInhibitProcess

        command: {
            if (!idleInhibited || nativeInhibitorAvailable) {
                return ["true"];
            }

            console.log("SessionService: Starting systemd/elogind inhibit process");
            return [isElogind ? "elogind-inhibit" : "systemd-inhibit", "--what=idle", "--who=quickshell", `--why=${inhibitReason}`, "--mode=block", "sleep", "infinity"];
        }

        running: idleInhibited && !nativeInhibitorAvailable

        onRunningChanged: {
            console.log("SessionService: Inhibit process running:", running, "(native:", nativeInhibitorAvailable, ")");
        }

        onExited: function (exitCode) {
            if (idleInhibited && exitCode !== 0 && !nativeInhibitorAvailable) {
                console.warn("SessionService: Inhibitor process crashed with exit code:", exitCode);
                idleInhibited = false;
                ToastService.showWarning("Idle inhibitor failed");
            }
        }
    }

    Process {
        id: lockStateMonitor
        running: false
        command: [
            "dbus-monitor", "--system",
            "type='signal',interface='org.freedesktop.login1.Session',member='Lock'",
            "type='signal',interface='org.freedesktop.login1.Session',member='Unlock'"
        ]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root._processLockStateLine(line)
        }

        onExited: () => {
            Qt.callLater(() => {
                if (!SettingsData.loginctlLockIntegration || !loginctlAvailable || !_lockMonitorStarted)
                    return;
                console.warn("SessionService: Lock state monitor exited unexpectedly - restarting");
                startLoginctlMonitors();
            });
        }
    }

    Process {
        id: prepareForSleepMonitor
        running: false
        command: [
            "dbus-monitor", "--system",
            "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"
        ]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root._processSleepStateLine(line)
        }

        onExited: () => {
            Qt.callLater(() => {
                if (!SettingsData.loginctlLockIntegration || !loginctlAvailable || !_sleepMonitorStarted)
                    return;
                console.warn("SessionService: Sleep state monitor exited unexpectedly - restarting");
                startLoginctlMonitors();
            });
        }
    }

    Process {
        id: sessionRefreshProcess
        running: false
        command: ["sh", "-c", 'SID="${XDG_SESSION_ID:-}"; if [ -z "$SID" ]; then SID=$(loginctl list-sessions --no-legend --no-ask-password 2>/dev/null | tr -s " " | while read s u name seat rest; do [ "$u" = "$(id -u)" ] && [ "$seat" != "-" ] && [ -n "$seat" ] && { echo "$s"; break; }; done); fi; [ -z "$SID" ] && exit 0; exec loginctl show-session "$SID" -p Id -p Active -p IdleHint -p Type -p Display -p Seat -p Name']

        stdout: StdioCollector {
            onStreamFinished: {
                const props = {};
                for (const line of text.split("\n")) {
                    const eq = line.indexOf("=");
                    if (eq > 0) {
                        props[line.substring(0, eq)] = line.substring(eq + 1).trim();
                    }
                }
                root.applySessionProperties(props);
            }
        }
    }

    Connections {
        target: SettingsData

        function onLoginctlLockIntegrationChanged() {
            if (SettingsData.loginctlLockIntegration) {
                if (loginctlAvailable && !stateInitialized) {
                    stateInitialized = true;
                    startLoginctlMonitors();
                    refreshSessionState();
                }
            } else {
                stateInitialized = false;
                stopLoginctlMonitors();
            }
        }
    }

    function startLoginctlMonitors() {
        if (!loginctlAvailable || !dbusMonitorAvailable)
            return;

        if (!_lockMonitorStarted) {
            _lockMonitorStarted = true;
            console.info("SessionService: Watching logind Lock/Unlock state");
            lockStateMonitor.running = true;
        }
        if (!_sleepMonitorStarted) {
            _sleepMonitorStarted = true;
            console.info("SessionService: Watching logind PrepareForSleep state");
            prepareForSleepMonitor.running = true;
        }
        refreshSessionState();
    }

    function stopLoginctlMonitors() {
        if (_lockMonitorStarted) {
            _lockMonitorStarted = false;
            lockStateMonitor.running = false;
        }
        if (_sleepMonitorStarted) {
            _sleepMonitorStarted = false;
            prepareForSleepMonitor.running = false;
        }
        locked = false;
        lockedHint = false;
        preparingForSleep = false;
    }

    function refreshSessionState() {
        if (!loginctlAvailable)
            return;
        sessionRefreshProcess.running = true;
    }

    function applySessionProperties(props) {
        let changed = false;

        if (props.Id !== undefined && props.Id !== sessionId) {
            sessionId = props.Id;
            changed = true;
        }
        if (props.Name !== undefined && props.Name !== userName) {
            userName = props.Name;
            changed = true;
        }
        if (props.Seat !== undefined && props.Seat !== seat) {
            seat = props.Seat;
            changed = true;
        }
        if (props.Display !== undefined && props.Display !== display) {
            display = props.Display;
            changed = true;
        }
        if (props.Type !== undefined && props.Type !== sessionType) {
            sessionType = props.Type;
            changed = true;
        }
        if (props.IdleHint !== undefined) {
            const idleVal = props.IdleHint === "yes";
            if (idleVal !== idleHint) {
                idleHint = idleVal;
                changed = true;
            }
        }
        if (props.Active !== undefined) {
            const activeVal = props.Active === "yes";
            if (activeVal !== active) {
                active = activeVal;
                changed = true;
            }
        }

        if (changed)
            loginctlStateChanged();
    }

    function _processLockStateLine(line) {
        if (line.includes("member=Lock")) {
            const wasLocked = locked;
            locked = true;
            lockedHint = true;
            if (!wasLocked)
                sessionLocked();
            refreshSessionState();
        } else if (line.includes("member=Unlock")) {
            const wasLocked = locked;
            locked = false;
            lockedHint = false;
            if (wasLocked)
                sessionUnlocked();
            refreshSessionState();
        }
    }

    function _processSleepStateLine(line) {
        if (line.includes("member=PrepareForSleep")) {
            _sleepArgPending = true;
            return;
        }
        if (!_sleepArgPending)
            return;

        const trimmed = line.trim();
        if (trimmed === "boolean true") {
            _sleepArgPending = false;
            preparingForSleep = true;
        } else if (trimmed === "boolean false") {
            _sleepArgPending = false;
            const wasSleeping = preparingForSleep;
            preparingForSleep = false;
            if (wasSleeping)
                sessionResumed();
        }
    }
}
