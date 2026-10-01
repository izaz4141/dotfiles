# TO-MIGRATE — DMSService removal

This project runs **pure quickshell** and does **not** use the `dms` Go backend.
`Services/DMSService.qml` is an IPC client for that backend (a Unix socket at
`$DMS_SOCKET`). Every file below references it. Each one must be either
**deleted** (feature cannot work without the DMS backend) or **migrated**
(reimplemented with native quickshell tooling).

## Native reference pattern (research findings)

**Preferred approach: use native `Quickshell.*` modules first**, and only fall
back to shelling out to CLIs (`gdbus`/`nmcli`/`cliphist`) where no module exists.

### Does `Quickshell.DBus` exist? — No.

Research against the official Quickshell docs (v0.3.x) confirms:

- There is **no general `Quickshell.DBus` module**.
- The only DBus-named module is **`Quickshell.DBusMenu`**, which is only for
  system-tray DBusMenu items — not general-purpose D-Bus.
- The community-written "the_quickshell_book" mentions a `Qt.dbusCall()` /
  `Qt.dbusConnect()` API, but **that is NOT part of the official Quickshell
  API**. Do not use it.

So general D-Bus integration must be done by shelling out to `gdbus`/`dbus-send`
via `Process` (this is what `Services/NetworkService.qml` does), or
better — by using a native `Quickshell.*` module that wraps the relevant D-Bus
service for you.

### Native Quickshell modules available (installed version 0.3.1)

These wrap system D-Bus services natively and should be preferred over the DMS
backend and over raw `gdbus`:

| Feature (DMS service) | Native Quickshell module |
|---|---|
| Network (`network.*`) | `Quickshell.Networking` (`Networking`, `NetworkDevice`, `WifiDevice`, `WiredDevice`, `WifiNetwork`) |
| Bluetooth (`bluetooth.*`) | `Quickshell.Bluetooth` (`Bluetooth`, `BluetoothAdapter`, `BluetoothDevice`) |
| Idle / screensaver (`freedesktop.screensaver`) | `Quickshell.Wayland` — `IdleMonitor`, `IdleInhibitor` |
| Lock session (`loginctl.lock`) | `Quickshell.Wayland` — `WlSessionLock`, `WlSessionLockSurface` |
| Battery / power | `Quickshell.Services.UPower` |
| Audio | `Quickshell.Services.Pipewire` |
| Media (`mpris`) | `Quickshell.Services.Mpris` |
| Notifications | `Quickshell.Services.Notifications` |
| Polkit | `Quickshell.Services.Polkit` |
| Auth (lock) | `Quickshell.Services.Pam` |
| Hyprland workspaces | `Quickshell.Hyprland` |
| Sway/i3 workspaces | `Quickshell.I3` |
| Gamma / night mode | `Quickshell.Wayland` / `gammastep` or `wlsunset` via `Process` |

**Migration order of preference when rewriting a DMS-backed feature:**
1. Use a native `Quickshell.*` module (`.Networking`, `.Bluetooth`, `.Wayland`, …).
2. If none exists, shell out to the CLI (`gdbus`, `nmcli`, `cliphist`) via
   `Quickshell.Io.Process` / `Quickshell.execDetached` (see `Services/NetworkService.qml`).
3. Never use `DMSService.sendRequest(...)`.

---

## Migration checklist

Track progress by checking off each completed item.

### Phase 1 — Migrate services (do first)

- [x] `Services/DMSNetworkService.qml` → `Quickshell.Networking` / `nmcli` (anchor migration — consolidated into `Services/NetworkService.qml`, `LegacyNetworkService.qml`/`DMSNetworkService.qml` deleted)
- [x] `Services/ClipboardService.qml` → `cliphist` / `wl-clipboard`
- [x] `Services/BluetoothService.qml` → `Quickshell.Bluetooth` + `bluetoothctl` (persistent stdin/stdout Process for passcode pairing)
- [x] `Services/SessionService.qml` → `dbus-monitor` Lock/Unlock/PrepareForSleep + `loginctl show-session`
- [ ] `Services/CapsLock` (via `Modules/DankBar/Widgets/CapsLockIndicator.qml`) → keyboard state
- [x] `Services/IdleService.qml` → **hypridle-backed** (config merge/parser + `killall hypridle` restart) + `dbus-monitor` observers
- [ ] `Services/CompositorService.qml` → remove DMS dwl-detection branch
- [ ] `Services/CupsService.qml` → `lpstat`/`lpadmin`/`lp` or remove
- [ ] `Services/DwlService.qml` → dwl-ipc direct or remove
- [ ] `Services/ExtWorkspaceService.qml` → per-compositor workspaces / `ext-workspace-v1`
- [x] `Services/LocationService.qml` → geoclue2 D-Bus via `gdbus`/`busctl`
- [x] `Services/SettingsSearchService.qml` → remove `dmsConnected` gate
- [x] `Services/VPNService.qml` → `nmcli` (folded into `Services/NetworkService.qml`; `VPNService.qml` rewritten on nmcli)
- [x] `Services/DgopService.qml` → `Services/SysMonitorService.qml` — replaced the `dgop` binary with native `/proc`/`/sys` monitoring (single `Quickshell.Io.Process` `sh -c` per tick for `/proc/[0-9]*` stat/status/cmdline; FileView stable-path reads for stat/meminfo/net/dev/diskstats/loadavg/os-release/sysfs/hwmon); preserved the `addRef`/`removeRef` + metric-property surface so consumers only retargeted their import.

### Phase 2 — Migrate modules / modals

- [ ] `Common/Theme.qml` (night mode / auto-theme) → gammastep/wlsunset + native timer
- [ ] `DMSShell.qml` (`dms://` handler) → remove or rewire
- [ ] `Modals/BluetoothPairingModal.qml` → `bluetoothctl` stdin/stdout (refactored — uses `BluetoothService.pairingRequested` signal instead of DMS agent)
- [x] `Modals/DankLauncherV2/ClipboardLauncherPreview.qml` → `cliphist` / remove
- [x] `Modals/Settings/SettingsSidebar.qml` → remove apiVersion gate
- [ ] `Modals/WifiQRCodeModal.qml` → `qrencode` / remove
- [ ] `Modules/ControlCenter/Components/DragDropGrid.qml` → `PluginService`
- [x] `Widgets/DankLocationSearch.qml` → native `curl` for Nominatim search (`dms dl` removed)
- [x] `Services/WeatherService.qml` → verified DMS-free (native `curl` fetchers + migrated `LocationService` + native `GreetdSettings`; no code change needed)
- [ ] `Modules/ControlCenter/Details/BluetoothDetail.qml` → native bluez
- [x] `Modules/ControlCenter/Details/NetworkDetail.qml` → remove version gates
- [ ] `Modules/DankBar/Widgets/WorkspaceSwitcher.qml` → native workspaces
- [ ] `Modules/Lock/Lock.qml` → `loginctl lock-session` / `Quickshell.Wayland`
- [ ] `Modules/Lock/LockScreenContent.qml` → `loginctl` + keyboard state

### Phase 3 — Settings tabs (plugins / themes UI)

- [ ] `Modules/Settings/AboutTab.qml` → shell version only (drop DMS version/capabilities)
- [x] `Modules/Settings/ClipboardTab.qml` → `cliphist` config / remove
- [x] `Modules/Settings/NetworkTab.qml` → remove version gate
- [ ] `Modules/Settings/PluginBrowser.qml` → local `PluginService` only
- [ ] `Modules/Settings/PluginListItem.qml` → local `PluginService` only
- [ ] `Modules/Settings/PluginsTab.qml` → local `PluginService` only
- [ ] `Modules/Settings/ThemeBrowser.qml` → local themes only
- [ ] `Modules/Settings/ThemeColorsTab.qml` → local themes only

### Phase 4 — Cleanup

- [ ] Verify no remaining `DMSService` references (`grep -rl 'DMSService' Services Modules Modals Common`)
- [ ] Delete `Services/DMSService.qml`
- [x] Delete `Services/DMSNetworkService.qml` (migrated into `Services/NetworkService.qml`)
- [x] Delete `Services/LegacyNetworkService.qml` (absorbed into `Services/NetworkService.qml`)
- [x] Remove now-unused native fallback glue in `Services/NetworkService.qml` (service is now self-contained)
- [x] Remove `DMS_SOCKET` handling from network service (still present for other services)
- [ ] Run `qmlformat-all.sh` and `qmllint` to validate

---

## Services

### Services/DMSService.qml
- **Action:** DELETE
- **Usages:** The entire IPC client — socket connections, `sendRequest`, `sendSubscribeRequest`, all `sendRequest(...)` wrappers (`bluetooth.*`, `loginctl.*`, `network.*`, `cups.*`, `clipboard.*`, `plugins.*`, `themes.*`, `dbus.*`, `extworkspace.*`, `dwl.*`, `location.*`), all subscription signals, and `dbusSignalReceived`.
- **Native alternative:** None. This is the thing being removed.
- **Notes:** Deleting this file breaks everything else in this doc; migrate each consumer first, then delete.

### Services/SysMonitorService.qml
- **Action:** DONE — renamed to `SysMonitorService`; 28 consumer files retargeted (`DgopService` → `SysMonitorService`, `dgopAvailable` → `monitorAvailable`); `dgop`-availability gates dropped (always `monitorAvailable: true`); `Services/DgopService.qml` deleted; discovered GPUs auto-registered via `addGpuPciId`.
- **Usages:** Ref-counted module registry (`addRef`/`removeRef`, `enabledModules`, `updateAllStats`), GPU PCI-ID tracking (`addGpuPciId`/`removeGpuPciId`), process sort options (`setProcessOptions`, `setSortBy`/`toggleSort`/`applySorting`, `killProcess`), and ~60 metric properties (`cpuUsage`, `cpuTemperature`, `memoryUsage`, `usedMemoryKB`, `networkRxRate`, `diskReadRate`, `diskMounts`, `processes`, `availableGpus`, `hostname`/`distribution`/`kernelVersion`, `cpuHistory`/`memoryHistory`/`networkHistory`/`diskHistory`/`uptime`, …). Backed natively by **`/proc`** (one `sh -c` Process per 3s tick: stat/status/cmdline per process, deltas computed in QML) plus **FileView** for stable paths (stat, meminfo, net/dev, diskstats, loadavg, os-release, sysfs hwmon/dmi). Does **not** use DMSService or any external binary. Consumed by `Modules/ProcessList/*`, `Modals/ProcessListModal.qml`, `Modules/DankBar/Widgets/{CpuMonitor,CpuTemperature,RamMonitor,NetworkMonitor,DiskUsage,GpuTemperature}.qml`, `Modules/DankDash/Overview/{SystemMonitorCard,UserInfoCard}.qml`, `Modules/ControlCenter/*`, `Modules/BuiltinDesktopPlugins/SystemMonitorWidget.qml`, `WidgetsTab`/`SystemMonitorSettings`.
- **Native alternative:** This IS the native service.
- **Notes:** Migration complete. `dgop` binary no longer required; consumers that previously gated on `dgopAvailable` now use `monitorAvailable` (always `true`); no `dgop` references remain in the shell's source.

### Services/DMSNetworkService.qml
- **Action:** DONE (merged into `Services/NetworkService.qml`)
- **Usages:** Previously network state + actions via `DMSService.sendRequest(...)`; all now handled directly in `Services/NetworkService.qml`.
- **Native alternative:** `Services/NetworkService.qml` is now a single self-contained service backed by **`Quickshell.Networking`** (`Networking`, `NetworkDevice`, `WifiDevice`, `WiredDevice`, `WifiNetwork`) for radio/device/state/actions, with `nmcli`/`gdbus`/`ip` via `Quickshell.Io.Process` for IPs, network-status, preferences, network-info, wired info, VPN, and credentials. `Services/LegacyNetworkService.qml` and this file were deleted; `Services/VPNService.qml` rewritten on nmcli; VPN state folded into `NetworkService`.
- **Notes:** Highest-value migration — complete. `usingLegacy` is fixed `true`; `activeService` is self-referential; `DMS_SOCKET` handling removed.
- **Native networking gotchas (resolved):**
  - `Networking.backend` is readonly and auto-detects `NetworkManager` (requires NM on the system bus). `Networking.devices`/`WifiDevice.networks` populate asynchronously; set `WifiDevice.scannerEnabled = true` so the networks model fills with scanned APs.
  - `device`-level states (`WifiDevice/WiredDevice.connected`) and `networkStatus` must come from the SAME source to avoid the Control Center showing title `Not connected` + subtitle `Connected` (a two-source mismatch: gdbus `PrimaryConnection` type vs native `currentWifiSSID`/`wifiSignalStrength`). `networkStatus` is now derived from native device connected-state in `syncFromNative()`.
  - `wifiInterface` is resolved via `nmcli -t -f TYPE,DEVICE device status` (filtering the `wifi` row, excluding `p2p-*`/`loopback`/`wireguard`), NOT native `WifiDevice[0]` (which can pick `p2p-dev-*`), so the nmcli `dev wifi list`/`ip addr`/scan commands use the real radio.
   - `currentWifiSSID`/`wifiSignalStrength` fall back to `nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi list --rescan no` (active `yes:` row), which also sets `networkStatus="wifi"`.
   - **ObjectModel accessor (root cause of "Not connected"/"Connected" contradiction):** Quickshell's `Networking.devices` and `WifiDevice.networks` are exposed as a raw **`ObjectModel`** that has NO `.count`, `.length`, `.get(i)`, or `.forEach`. The ONLY way to iterate them is the **`.values` array** (e.g. `Networking.devices.values[i]`, `dev.networks.values`). Using `.count`/`.get()` silently yields `undefined` and the loop body never runs → `wifiInterface` stays empty and `findConnectedWifiNetwork()` returns null → device shown as disconnected even when connected. Verified empirically (backend auto-detects NetworkManager; `devices.values` enumerates the real devices/networks). All native-model iteration in `syncFromNative()`/`findConnectedWifiNetwork()`/`wireSecretsHandlers()`/`nativeWifiNetwork()` must use `.values[i]`. See `test/NativeIterationTest.qml`.



### Services/ClipboardService.qml
- **Action:** DONE
- **Usages:** Was: `DMSService.sendRequest("clipboard.getHistory" | "clipboard.copyEntry" | "clipboard.deleteEntry" | "clipboard.getPinnedCount" | "clipboard.pinEntry" | "clipboard.unpinEntry" | "clipboard.clearHistory")` + `Connections { target: DMSService; function onClipboardStateUpdate(...) }` + DMS-based `clipboardAvailable` capability check.
- **Native alternative:** Done. Singleton `Services/ClipboardService.qml` shells out to `cliphist` via `Quickshell.Io.Process`:
  - **List:** `cliphist list` → `StdioCollector` → `listModel` (`{entry}` rows holding the raw `id\tcontent` line).
  - **Copy:** `cliphist decode <id> | wl-copy` via `Quickshell.execDetached`.
  - **Delete:** `echo '<line>' | cliphist delete` via a per-entry `Process` whose `command` is rebuilt each call; on exit the matching row is removed from `listModel` and `filteredClipboardModel`, then `Qt.callLater(root.refresh)` re-runs `cliphist list` to repaint the view immediately.
  - **Wipe:** `printf y | cliphist wipe` via `Process` (handles both interactive and non-interactive `cliphist` versions); on exit both models are cleared and `Qt.callLater(root.refresh)` re-runs `cliphist list` to confirm the empty state against fresh data.
  - **Filter/search:** local `filteredClipboardModel` rebuilt by `setSearchText(text)` from `listModel` using `getEntryPreview(...)` (strips the leading cliphist id, detects image MIME/dimensions, truncates to `ClipboardConstants.previewLength`).
  - **Type/preview helpers:** `getEntryType(entry)` and `getEntryPreview(entry)` exposed to the modal delegates.
  - **Availability probe:** `Component.onCompleted` runs `command -v cliphist`; `clipboardAvailable` reflects the result and gates the settings sidebar entry.
  The `cliphistProcesses` `QtObject` (and its child `Process`es) was deleted; the modal set (`Modals/Clipboard/*`) now consumes the service directly. Pinning is dropped (`cliphist` has no pin concept).
- **Notes:** Requires `wl-paste --watch cliphist store` running in the user's compositor config (out of scope for the shell). The `image/` preview path and `base64` data-URL helper used by the launcher are not yet wired into the service (the `DankLauncherV2/ClipboardLauncherPreview.qml` migration in this doc describes a planned `ClipboardService.getEntryDataUrl(id, cb)` that runs `cliphist decode <id>` to a temp file + `file -b --mime-type` + `base64 -w0` — implement when the launcher is updated to call into the service).

### Services/CompositorService.qml
- **Action:** MIGRATE
- **Usages:** `DMSService.dmsAvailable` guard (line 574), `Connections { target: DMSService; function onCapabilitiesReceived() }` (589), `checkForDwl()` via `apiVersion`/`capabilities.includes("dwl")` (598-609).
- **Native alternative:** dwl detection should come from the dwl IPC socket (`dwl-ipc-unstable-v2`) directly or environment, not DMS capabilities.
- **Notes:** Only the dwl-detection path depends on DMS; compositor detection for other compositors is already native.

### Services/CupsService.qml
- **Action:** MIGRATE / DELETE
- **Usages:** Subscription mgmt (`DMSService.addSubscription/removeSubscription` for `"cups"`), capability check (`capabilities.includes("cups")`), and ~20 actions via `DMSService.sendRequest("cups.*")` (`getPrinters`, `getJobs`, `pausePrinter`, `resumePrinter`, `cancelJob`, `purgeJobs`, `getDevices`, `getPPDs`, `getClasses`, `createPrinter`, `deletePrinter`, `acceptJobs`, `rejectJobs`, `setPrinterShared`, `setPrinterLocation`, `setPrinterInfo`, `testConnection`).
- **Native alternative:** CUPS admin via `lpstat`/`lpadmin`/`lp`/`cancel` through `Process`, or drop the printing UI.
- **Notes:** Fully backend-dependent (Go IPP integration). Needs a full native rewrite or removal. Consumed by `Settings/PrinterTab.qml`, `ControlCenter/BuiltinPlugins/CupsWidget.qml`, `WidgetModel.qml`, `DankBar/Widgets/ControlCenterButton.qml`, `SettingsSidebar.qml`, `SettingsModal.qml`, `SettingsSearchService.qml`.

### Services/DwlService.qml
- **Action:** MIGRATE / DELETE
- **Usages:** `DMSService.dmsAvailable`, capability check (`capabilities.includes("dwl")`), subscription (`addSubscription("dwl")`), and `DMSService.sendRequest("dwl.getState" | "dwl.setTags" | "dwl.setClientTags" | "dwl.setLayout")`.
- **Native alternative:** dwl IPC (`dwl-ipc-unstable-v2`) directly, or drop dwl support if the user's compositor is not dwl.
- **Notes:** Feature is compositor-specific (MangoWC/dwl); migrate only if relevant.

### Services/ExtWorkspaceService.qml
- **Action:** MIGRATE / DELETE
- **Usages:** `DMSService.dmsAvailable`, capability check (`capabilities.includes("extworkspace")`), `DMSService.addSubscription("extworkspace")`, and `sendRequest("extworkspace.getState" | "activateWorkspace" | "deactivateWorkspace" | "removeWorkspace" | "createWorkspace")`, plus `DMSService.forceExtWorkspace`.
- **Native alternative:** `ext-workspace-v1` Wayland protocol directly from quickshell, or fall back to per-compositor workspace services (`NiriService`, `HyprlandService`, etc.).
- **Notes:** `WorkspaceSwitcher.qml` already uses this service; the compositor-specific services are native.

### Services/IdleService.qml
- **Action:** DONE (hypridle-backed)
- **Usages:** Was: `DMSService.screensaverInhibited` (line 32), `DMSService.screensaverInhibitors.map(...)` (165, 185).
- **Native alternative:** IdleService now depends on **hypridle** as the idle engine. It:
  - Probes `command -v hypridle` on init (`hypridleAvailable`; gates `PowerSleepTab` warning and all sync work).
  - **Merges a managed section into `~/.config/hypr/hypridle.conf`** (hyprland syntax), not a full overwrite. `_mergeConfig()` parses the existing file: keeps everything before the first `general { ... }` block verbatim (e.g. ML4W banner comments), swaps the `general` block and any pre-existing listeners for the freshly generated **managed region**, and preserves anything below the `# === End DankMaterialShell idle config (managed) ===` end marker (user-added listeners).
  - Managed region = a `general` block (`lock_cmd`/`unlock_cmd = loginctl lock/unlock-session $XDG_SESSION_ID`, `before_sleep_cmd = loginctl lock-session $XDG_SESSION_ID` when `lockBeforeSuspend`, `after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'`, `ignore_dbus_inhibit`/`ignore_systemd_inhibit = false`) plus **listeners** (absolute timeouts) **grouped by category** — brightness (`brightnessctl -s set N%` / `-r`), DPMS (`hyprctl dispatch 'hl.dsp.dpms'` off/on — plugin syntax kept), lock (`loginctl lock-session $XDG_SESSION_ID`), suspend (`systemctl suspend/hibernate/suspend-then-hibernate` or custom actions; pre-sleep locking is handled by `before_sleep_cmd`, which fires on the logind prepare-for-sleep event for *any* suspend source — suspend listeners run the bare `systemctl` command). Steps omitted when timeout is 0 ("Never").
  - **AC/battery plan via `condition_cmd`**: within each category the AC and battery listeners are emitted adjacently (AC first), each gated by an inline sysfs script (`/sys/class/power_supply`) — `_onBatteryCondition()` (exit 0 when a `Battery` supply is discharging / `online=0`) and `_notOnBatteryCondition()` (exit 0 when no `Battery` supply is discharging — **desktop/PC mode = AC**, since a battery-less machine falls through to `exit 0`). Each conditioned listener also declares `condition_retry = 0` (re-check every second, so a deferred action fires as soon as the mode flips). When both states are identical in `(timeout, on-timeout, on-resume)`, a single ungated listener (no `condition_cmd`/`condition_retry`) is emitted for that category. hypridle runs `condition_cmd` via `/bin/sh -c` and only fires `on-resume` if `on-timeout` actually ran, so deferred listeners don't misfire.
  - Writes via a `FileView` (`blockWrites:false`, `atomicWrites:false`) then **restarts** hypridle (`killall hypridle; sleep 0.2; hypridle`) or starts it if absent (`hypridle`). Re-syncs on any timeout/behavior setting change; AC↔battery flips are a no-op since both conditional listener sets are always present.
  - **Internal `IdleMonitor` timers removed** (hypridle owns timing). The existing `dbus-monitor` observer still mirrors external `org.freedesktop.ScreenSaver.Inhibit/UnInhibit` bus traffic into `externalInhibitors` → `SessionService.idleInhibited`.
  - A second `dbus-monitor` observes `org.freedesktop.ScreenSaver.ActiveChanged`; hypridle does not emit that signal, so it is now dormant (kept as-is).
- **Notes:** Requires `hypridle` and `dbus-monitor` (probes and degrades gracefully when either is absent). The managed region replaces the stock ML4W generic block/listeners on first sync; hand-edits inside the managed region are overwritten, user content above `general` or below the end marker survives. `lock_cmd`/`unlock_cmd` use loginctl so any dbus lock event (including `before_sleep_cmd`) locks the session → DMS shows its own lock screen on the logind Lock signal (no hyprlock). Drop-in replacement: `PowerSleepTab` warning now gates on `!IdleService.hypridleAvailable`. `idleMonitorAvailable` property removed (was consumed only by `PowerSleepTab.qml:346`, updated). The logind Lock/Unlock observer previously living here (`logindMonitorProcess` → `lockComponent.lock()`) was **consolidated** into `Services/SessionService.qml`'s `lockStateMonitor` (single source); external logind locks now reach the lock screen via `SessionService.sessionLocked()`, gated by `SettingsData.loginctlLockIntegration`.

### Services/LocationService.qml
- **Action:** DONE
- **Usages:** Was: `DMSService.isConnected` + `capabilities.includes("location")` gate, `Connections { target: DMSService; onLocationStateUpdate }`, and `sendRequest("location.getState")`.
- **Native alternative:** Done. Singleton `Services/LocationService.qml` now resolves coordinates from **geoclue2** over the system D-Bus by running a single `python3` helper (`Scripts/geolocate.py`, uses the `python-dbus` module) via `Quickshell.Io.Process` (`Proc.runCommand` in `Common/Proc.qml`). The public surface is unchanged (`latitude`, `longitude`, `valid`, `locationAvailable`, `locationChanged(data)`, `getState()`), so `WeatherService.qml` needed only a one-line addition (`LocationService.getState()` when `useAutoLocation` turns on). Flow:
  - **Probe:** `busctl --system list | grep -qF org.freedesktop.GeoClue2` (same as `DisplayService`) → `geoclueAvailable` → `locationAvailable`.
  - **Agent:** lazily starts `/usr/lib/geoclue-2.0/demos/agent` (falls back to `/usr/libexec/geoclue-2.0/demos/agent`) to auto-approve geoclue authorization, mirroring `DisplayService.startGeoclueAgent()` but self-contained (services don't import services).
  - **Client:** helper holds **one persistent D-Bus connection** for the whole exchange — `Manager.GetClient` → `Properties.Set` `DesktopId` (`org.DankMaterialShell`) + `DistanceThreshold` (1000) → `Client.Start` → polls `Client.Location` until a non-`/` path (1 s interval, ≤25 s) → reads `Latitude`/`Longitude`/`Accuracy` → `Client.Stop` → prints `lat,lon,acc` and exits. QML parses that line and emits `locationChanged({latitude, longitude, accuracy})`.
  - **Why one connection:** geoclue2 binds each `Client` object to the D-Bus connection that created it; one-shot `gdbus call` per step (each a fresh connection) makes the client vanish before the next call (`Object does not exist`), so per-call `gdbus` cannot work.
- **Notes:** Consumed by `Services/WeatherService.qml` (`getLocationFromService()` + `onLocationChanged` reverse-geocode). Requires `geoclue` + `python3` + `python-dbus` (`geoclueAvailable` probe gates everything); degrades gracefully (`locationAvailable=false`, startup warn on denied/no-fix). `Common/Theme.qml` does not consume this service — its `theme.auto`/`wayland.gamma` location wiring still needs its own migration (Phase 2).

### Services/SessionService.qml
- **Action:** MIGRATED (DMS-free)
- **Usages:** Was: `socketPath` (`DMS_SOCKET`), 4 `Connections { target: DMSService }` blocks, `DMSService.isConnected` guards, capability checks (`capabilities.includes("loginctl")`), `sendRequest("loginctl.getState" | "loginctl.setLockBeforeSuspend" | "loginctl.setSleepInhibitorEnabled")`, `DMSService.apiVersion`, and DMS-shaped `updateLoginctlState(state)`/`handleLoginctlEvent(event)`.
- **Native alternative:** Done. Singleton `Services/SessionService.qml` now tracks logind purely natively:
  - **Availability probes:** `detectLoginctlProcess` (`which loginctl` → `loginctlAvailable`) and `detectDbusMonitorProcess` (`which dbus-monitor` → `dbusMonitorAvailable`), both kicked from `sessionInitTimer`. These gate all loginctl UI (`Lock.qml`, `LockScreenTab.qml`, `PowerSleepTab.qml`) exactly as the old DMS capability check did.
  - **Lock/Unlock (instant, event-driven):** `lockStateMonitor` Process = `dbus-monitor --system` filtering `org.freedesktop.login1.Session` `Lock`/`Unlock` signals; `_processLockStateLine()` flips `locked`/`lockedHint` and fires `sessionLocked()`/`sessionUnlocked()` on transition, then triggers a session refresh. This is now the **single** logind Lock/Unlock observer — the duplicate `logindMonitorProcess` one in `IdleService` was removed (its `logindEventDebounce`/`_startLogindMonitor`/`_processLogindLine`/`lockComponent` all deleted; `Lock.qml` no longer assigns `IdleService.lockComponent`). Auto-restarts while integration is on and `_lockMonitorStarted` (a debug `file` exclusion + `Qt.callLater` re-arm).
  - **Sleep/Resume:** `prepareForSleepMonitor` Process = `dbus-monitor --system` on `org.freedesktop.login1.Manager.PrepareForSleep`; `_processSleepStateLine()` parses the `boolean true/false` arg into `preparingForSleep` and fires `sessionResumed()` on the true→false edge (keeps `SessionData` OSD-suppression alive).
  - **Identity/active refresh:** `sessionRefreshProcess` = one-shot `sh -c` that resolves the session ID (`$XDG_SESSION_ID`, falling back to the first graphical `user`-class session from `loginctl list-sessions --no-legend`, filtered by our uid) then runs `loginctl show-session <SID> -p Id -p Active -p IdleHint -p Type -p Display -p Seat -p Name` via `StdioCollector`. **Required regression fix:** the initial DMS-free version ran `loginctl show-session` with *no* ID, which returns the login *manager's* properties (never `Id`/`Active`/`Seat`) → `SessionService.active` stayed `false` → `Lock.qml`'s `pendingLock` path (gated `!active && loginctlAvailable && integration`) deadlocked and no lock screen ever appeared. `applySessionProperties()` maps `Key=value` onto `sessionId/userName/seat/display/sessionType/idleHint/active` and fires `loginctlStateChanged()` when anything changed. Runs at init, on integration-enable, and after each Lock/Unlock event.
  - **Lifecycle:** `startLoginctlMonitors()`/`stopLoginctlMonitors()` or started from the probes and from `SettingsData.onLoginctlLockIntegrationChanged`; `stateInitialized` gates first init; disabling integration stops monitors and resets `locked`/`lockedHint`/`preparingForSleep`.
- **Notes:** `syncLockBeforeSuspend()` and `syncSleepInhibitor()` were **dropped** — they pushed to the removed Go backend; `lockBeforeSuspend` is already native via `IdleService` (hypridle `before_sleep_cmd`, re-merged on `onLockBeforeSuspendChanged` at `IdleService.qml:631`). The Control Center "Keep system awake" tile is unaffected (that's the native `systemd-inhibit --what=idle` `idleInhibitProcess`). `sessionPath` stays `""` (no consumers). Consumed by `Lock.qml` / `LockScreenContent.qml` / `PowerSleepTab.qml` / `LockScreenTab.qml` / `WallpaperCyclingService.qml` / `PopoutService.qml` / `SessionData.qml`. Verified DMS-free (`rg DMSService\|DMS_SOCKET` → no matches) and runtime smoke-tested (singleton load + state-transition helpers).

### Services/SettingsSearchService.qml
- **Action:** DONE
- **Usages:** `"dmsConnected": () => DMSService.isConnected && DMSService.apiVersion >= 23` (line 29) — was used as a gating condition in settings search.
- **Native alternative:** DONE — entry removed from `conditionMap`. The `clipboardOnly → dmsConnected` mapping in `translations/extract_settings_index.py:404` self-heals to "always show" via `checkCondition`'s unknown-key fallback (`Services/SettingsSearchService.qml:115-122`).

### Services/VPNService.qml
- **Action:** DONE (rewritten on `nmcli` in `Services/VPNService.qml`)
- **Usages:** Previously `DMSService.sendRequest("network.vpn.*")`; now `nmcli connection` via `Process` in `Services/VPNService.qml` (import/show/modify/delete) with VPN state in `Services/NetworkService.qml`.
- **Native alternative:** Done. VPN via `nmcli connection` (import/show/up/down) through `Process`.
- **Notes:** VPN manager UI now works without DMS.

### Services/BluetoothService.qml
- **Action:** DONE
- **Usages:** Was: `enhancedPairingAvailable` guard (`DMSService.dmsAvailable && apiVersion >= 9 && capabilities.includes("bluetooth")`, line 19), and `DMSService.bluetoothPair(...)` (line 187) which used the DMS backend's bluez agent.
- **Native alternative:** Done. Singleton `Services/BluetoothService.qml` uses `Quickshell.Bluetooth` for adapter/devices/connect/disconnect/trust, and a persistent `bluetoothctl` Process (lazy-started on first pairing) with `stdinEnabled: true` for passcode pairing. The `SplitParser` on `btctlProcess.stdout` detects `Enter PIN code`, `Enter passkey`, `Confirm passkey N` prompts and emits the `pairingRequested(deviceName, requestType, passkey)` signal; the modal shows; user input is piped back via `BluetoothService.submitPairingInput(input)` → `Process.write()`. Success/failure parsed from `Pairing successful` / `Failed to pair` / `org.bluez.Error` lines. `cancelPairing()` writes `quit\n` to stdin. Device removal uses native `device.forget()`. `bluetoothctlAvailable` probed via `command -v bluetoothctl` on init.
- **Notes:** Requires `bluetoothctl` (part of `bluez`). Consumed by `BluetoothDetail.qml` and `BluetoothPairingModal.qml` — both refactored to use the new signal-based flow.

---

## Core / Common

### DMSShell.qml
- **Action:** MIGRATE / DELETE
- **Usages:** `Connections { target: DMSService; function onOpenUrlRequested(url) }` (line 694) — handles `dms://theme/install/<id>` and `dms://plugin/install/<id>` deep links.
- **Native alternative:** Only relevant if the `dms://` deep-link scheme is kept; otherwise remove the handler and `PopoutService.pendingThemeInstall`/`pendingPluginInstall` flow.
- **Notes:** It only triggers on backend-originated open-url events, which won't happen without DMS.

### Common/Theme.qml
- **Action:** MIGRATE
- **Usages:** `wayland.gamma.*` (`setLocation`, `setUseIPLocation`) and `theme.auto.*` (`setMode`, `setSchedule`, `setEnabled`, `trigger`, `getState`, `setLocation`, `setUseIPLocation`), plus a `Connections { target: DMSService }` block (348) and helper functions (`canAutoTheme`, `setAutoThemeMode`, `applyNightMode`) — most guarded by `typeof DMSService !== "undefined"` and `DMSService.isConnected`.
- **Native alternative:** Night mode / gamma can be done via `wlr-gamma-control-unstable-v1` or a compositor-native gamma command (e.g. `gammastep`, `wlsunset`, hyprland-specific). Auto-theme toggle can be driven by scheduling/time natively.
- **Notes:** The `typeof DMSService !== "undefined"` guards mean it degrades gracefully, but the actual gamma/auto-theme behavior silently no-ops without DMS.

---

## Modals

### Modals/BluetoothPairingModal.qml
- **Action:** DONE
- **Usages:** Was: `DMSService.bluetoothCancelPairing(token)` (76, 97, 286, 365), `DMSService.bluetoothSubmitPairing(token, secrets, true, ...)` (398) — responses to the DMS backend bluez agent.
- **Native alternative:** Done — refactored to use `BluetoothService.cancelPairing()` and `BluetoothService.submitPairingInput(input)` which pipe commands to the `bluetoothctl` Process. Triggered by the `BluetoothService.pairingRequested(deviceName, requestType, passkey)` signal (connected in `BluetoothDetail.qml`). The `token` property and DMS secrets object are gone — input is just a plain string written to `bluetoothctl`'s stdin.

### Modals/DankLauncherV2/ClipboardLauncherPreview.qml
- **Action:** DONE
- **Usages:** Was: `DMSService.sendRequest("clipboard.getEntry", ...)` (line 58) to fetch image bytes for an entry.
- **Native alternative:** Done — `ClipboardService.getEntryDataUrl(id, (mime, b64) => ...)` runs `cliphist decode <id>` to a temp file, then `file -b --mime-type` + `base64 -w0`, and returns the mime + base64 string. The modal builds a `data:<mime>;base64,<b64>` URL.

### Modals/Settings/SettingsSidebar.qml
- **Action:** DONE
- **Usages:** `DMSService.isConnected || apiVersion < 23` (line 343, previously line 344) to gate a clipboard-only settings entry.
- **Native alternative:** DONE — replaced with `ClipboardService.clipboardAvailable` (native `cliphist` / `wl-clipboard-history` / `copyq` probe). The `clipboardOnly` flag on the clipboard entry is preserved.

### Modals/WifiQRCodeModal.qml
- **Action:** MIGRATE / DELETE
- **Usages:** `DMSService.sendRequest("network.qrcode", ...)` (51) and `"network.delete-qrcode"` (65).
- **Native alternative:** Double-click-to-connect/save is already handled natively by `NetworkService`; the QR-code generation/management is backend-only — drop it or regenerate the QR natively (e.g. `qrencode`).

---

## Modules

### Modules/ControlCenter/Components/DragDropGrid.qml
- **Action:** MIGRATE
- **Usages:** `if (!DMSService.dmsAvailable)` (line 218).
- **Native alternative:** Replace the DMS-availability gate with a native value (e.g. plugin availability via `PluginService`).

### Modules/ControlCenter/Details/BluetoothDetail.qml
- **Action:** MIGRATE
- **Usages:** `DMSService.bluetoothRemove(devicePath, ...)` (722) and a `Connections { target: DMSService }` block (732).
- **Native alternative:** Device removal via native bluez D-Bus (trust/remove through the device object) — same pattern as the rest of `BluetoothService`.

### Modules/ControlCenter/Details/NetworkDetail.qml
- **Action:** DONE
- **Usages:** Removed `DMSService.apiVersion` gates from WiFi connect, saved networks, and preference UI.
- **Native alternative:** Done — gates removed; all features (interactive credentials, saved/forget, autoconnect, preference) are implemented in `Services/NetworkService.qml`.

### Modules/DankBar/Widgets/CapsLockIndicator.qml
- **Action:** MIGRATE / DELETE
- **Usages:** `DMSService.capsLockState` (lines 10, 15, 23).
- **Native alternative:** Caps-lock state from an `evdev`/keyboard-state monitor, or remove the indicator.

### Modules/DankBar/Widgets/WorkspaceSwitcher.qml
- **Action:** MIGRATE
- **Usages:** `DMSService.forceExtWorkspace` (48), `DMSService.activeSubscriptions.includes("extworkspace")` + `DMSService.addSubscription("extworkspace")` (1810-1811).
- **Native alternative:** Use `ExtWorkspaceService` natively or per-compositor workspace services (`NiriService`, `HyprlandService`, etc.); `useExtWorkspace` should not depend on DMS subscriptions.

### Modules/Lock/Lock.qml
- **Action:** MIGRATE
- **Usages:** `DMSService.isConnected`, `DMSService.lockSession(...)` (54), `DMSService.unlockSession(...)` (56) — gated by `SettingsData.loginctlLockIntegration`.
- **Native alternative:** `loginctl lock-session` / `unlock-session` via `Process`, or use **`Quickshell.Wayland`** `WlSessionLock`; keep native lock instead of DMS loginctl integration.

### Modules/Lock/LockScreenContent.qml
- **Action:** MIGRATE
- **Usages:** `DMSService.apiVersion >= 2`, `DMSService.sendRequest("loginctl.lockerReady", ...)` (64-65), `DMSService.capsLockState` (1082).
- **Native alternative:** `loginctl` locker-ready notification natively (or `Quickshell.Wayland` `WlSessionLock`); caps-lock from keyboard state or drop.

### Modules/Settings/AboutTab.qml
- **Action:** MIGRATE
- **Usages:** `DMSService.cliVersion` (192, 196, 657), `DMSService.isConnected` (607), `DMSService.apiVersion` (682), `DMSService.capabilities.length` + `DMSService.capabilities` (731, 746).
- **Native alternative:** Remove the DMS version/capability display (no longer meaningful). Keep shell/UI version from `SystemUpdateService`/`VERSION`.

### Modules/Settings/ClipboardTab.qml
- **Action:** DONE
- **Usages:** Was: `DMSService.sendRequest("clipboard.getConfig" | "clipboard.setConfig")` (193, 207), `DMSService.isConnected` + `Connections { target: DMSService }` (220, 225-227), config error text (250, 267).
- **Native alternative:** Done — reads/writes the key/value text file at `~/.config/cliphist/config` via `Quickshell.Io.FileView`. Only exposes the options that actually exist in upstream `cliphist`: `max-items`, `max-store-size`, `min-store-length`, `preview-width`, `max-dedupe-search`. DMS-only options (`max-pinned`, `auto-clear-days`, `max-entry-size`, `clear-at-startup`, `disabled`) were removed because `cliphist` does not support them; the `clipboardEnterToPaste` setting remains as a `SettingsData` toggle (it's a launcher-behavior setting, not a `cliphist` config key). The `en.json` translation references for this file are now stale and need to be regenerated by running the translation extractor (separate cleanup task).

### Modules/Settings/NetworkTab.qml
- **Action:** DONE
- **Usages:** Removed `DMSService.apiVersion > 13` gate (saved-network options).
- **Native alternative:** Done — saved/forget network options now come from `NetworkService`.

### Modules/Settings/PluginBrowser.qml
- **Action:** MIGRATE / DELETE
- **Usages:** `DMSService.install(...)` (83), `DMSService.listPlugins()` + `listInstalled()` (107-109), `Connections { target: DMSService }` (173).
- **Native alternative:** Use the native `PluginService` (local plugin discovery/management). The online plugin *browser* is entirely DMS/backend-driven — remove it.
- **Notes:** The `PluginService` already manages local plugins; only the "browse online plugins" feature is DMS-dependent.

### Modules/Settings/PluginListItem.qml
- **Action:** MIGRATE / DELETE
- **Usages:** `DMSService.dmsAvailable` (187, 231), `DMSService.update(...)` (204), `DMSService.listInstalled()` (211), `DMSService.uninstall(...)` (247), `DMSService.apiVersion >= 8` (211).
- **Native alternative:** Use `PluginService` for installed/update/uninstall of local plugins; drop DMS-installed plugin concept.

### Modules/Settings/PluginsTab.qml
- **Action:** MIGRATE / DELETE
- **Usages:** `DMSService.dmsAvailable` (96, 211, 223, 418), `DMSService.listInstalled()` (224, 369, 419), `DMSService.apiVersion < 8` (320), `DMSService.apiVersion >= 8` (368), `Connections { target: DMSService }` (386).
- **Native alternative:** `PluginService` for local plugins; remove the "install from DMS" flow (security/permissions warnings for online plugins are backend-specific).

### Modules/Settings/ThemeBrowser.qml
- **Action:** MIGRATE / DELETE
- **Usages:** `DMSService.installTheme(...)` (66), `uninstallTheme(...)` (95), `listThemes()` + `listInstalledThemes()` (107-108), `Connections { target: DMSService }` (176).
- **Native alternative:** Local theme management via matugen/themes registry is native; the online *theme browser* is DMS/backend-only — remove it.

### Modules/Settings/ThemeColorsTab.qml
- **Action:** MIGRATE / DELETE
- **Usages:** `DMSService.dmsAvailable` (132, 252), `DMSService.listInstalledThemes()` (133, 715), `DMSService.uninstallTheme(...)` (709), `Connections { target: DMSService }` (141).
- **Native alternative:** Use local theme registry (matugen templates); the "Browse"/installed-online-theme features are DMS-only — remove or replace with local source selection.

---

## Quick reference

| File | Action | Native alternative |
|------|--------|--------------------|
| Services/DMSService.qml | DELETE | none (removal target) |
| Services/DMSNetworkService.qml | DELETED | Quickshell.Networking / nmcli (merged into NetworkService.qml) |
| Services/LegacyNetworkService.qml | DELETED | absorbed into NetworkService.qml |
| Services/ClipboardService.qml | DONE | cliphist / wl-copy / file (MIME) |
| Services/CompositorService.qml | MIGRATE | dwl-ipc direct |
| Services/CupsService.qml | MIGRATE/DELETE | lpstat/lpadmin/lp |
| Services/DwlService.qml | MIGRATE/DELETE | dwl-ipc direct |
| Services/ExtWorkspaceService.qml | MIGRATE/DELETE | ext-workspace-v1 / per-compositor |
| Services/IdleService.qml | DONE | hypridle-backed merge/parser (managed section + `condition_cmd` plan gating) + `killall hypridle` restart + dbus-monitor observers (in-file) |
| Services/LocationService.qml | DONE | geoclue2 D-Bus via gdbus/busctl (`Manager.GetClient` → `Client.Start` → poll `Location` → parse `Latitude`/`Longitude`) |
| Services/SessionService.qml | MIGRATED | dbus-monitor Lock/Unlock/PrepareForSleep + loginctl show-session |
| Services/SettingsSearchService.qml | DONE | remove gate |
| Services/VPNService.qml | DONE | nmcli (rewritten; VPN state in NetworkService.qml) |
| Services/BluetoothService.qml | DONE | Quickshell.Bluetooth + bluetoothctl (stdin/stdout for passcode pairing) |
| Services/SysMonitorService.qml | MIGRATE | Services/SysMonitorService.qml (FileView filewatch on /proc + /sys; no `dgop` binary) |
| DMSShell.qml | MIGRATE/DELETE | none (deep links) |
| Common/Theme.qml | MIGRATE | gammastep/wlsunset + native timer |
| Modals/BluetoothPairingModal.qml | DONE | bluetoothctl stdin/stdout (BluetoothService.pairingRequested) |
| Modals/…/ClipboardLauncherPreview.qml | DONE | ClipboardService.getEntryDataUrl (cliphist decode + file) |
| Modals/Settings/SettingsSidebar.qml | DONE | native gate (cliphist probe) |
| Modals/WifiQRCodeModal.qml | MIGRATE/DELETE | qrencode / drop |
| Widgets/DankLocationSearch.qml | DONE | native curl (`curl -sS --fail -4 --connect-timeout 5 --max-time 10 -H "User-Agent: DankMaterialShell Location Search"` against Nominatim search API) — replaced `dms dl -4 --timeout 10` |
| Services/WeatherService.qml | VERIFIED DMS-FREE | native `curl` fetchers (weather/geocode/reverse-geocode) + migrated `LocationService` (geoclue) + native `GreetdSettings` — no `DMSService`/`dms` references |
| Modules/ControlCenter/…/DragDropGrid.qml | MIGRATE | PluginService |
| Modules/ControlCenter/Details/BluetoothDetail.qml | MIGRATE | native bluez |
| Modules/ControlCenter/Details/NetworkDetail.qml | MIGRATE | remove version gates |
| Modules/DankBar/Widgets/CapsLockIndicator.qml | MIGRATE/DELETE | keyboard state |
| Modules/DankBar/Widgets/WorkspaceSwitcher.qml | MIGRATE | native workspaces |
| Modules/Lock/Lock.qml | MIGRATE | loginctl lock-session / Quickshell.Wayland |
| Modules/Lock/LockScreenContent.qml | MIGRATE | loginctl + keyboard state |
| Modules/Settings/AboutTab.qml | MIGRATE | shell version only |
| Modules/Settings/ClipboardTab.qml | DONE | native ~/.config/cliphist/config read/write |
| Modules/Settings/NetworkTab.qml | MIGRATE | remove version gate |
| Modules/Settings/PluginBrowser.qml | MIGRATE/DELETE | local PluginService only |
| Modules/Settings/PluginListItem.qml | MIGRATE/DELETE | local PluginService only |
| Modules/Settings/PluginsTab.qml | MIGRATE/DELETE | local PluginService only |
| Modules/Settings/ThemeBrowser.qml | MIGRATE/DELETE | local themes only |
| Modules/Settings/ThemeColorsTab.qml | MIGRATE/DELETE | local themes only |

## Prerequisite

Because so many features are wired to `DMSService`, migration order matters:

1. Migrate `Services/` first (`DMSNetworkService` → `Quickshell.Networking` /
   `NetworkService` is the anchor; then Clipboard, Session, Bluetooth →
   `Quickshell.Bluetooth`, etc.). See the checklist at the top.
2. Update all `Modules/`/`Modals/` consumers to the native services.
3. Remove the `dms` deep-link handler in `DMSShell.qml`.
4. Only after no references remain, delete `Services/DMSService.qml`.

Migration order suggestion: **network (`Quickshell.Networking`) → clipboard →
session/loginctl → bluetooth (`Quickshell.Bluetooth`) → workspaces
(extworkspace/dwl) → theme/gamma → plugins/themes UI → settings cleanup**.
