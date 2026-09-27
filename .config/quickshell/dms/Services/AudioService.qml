pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool soundsAvailable: MultimediaService.available
    property bool gsettingsAvailable: false
    property var availableSoundThemes: []
    property string currentSoundTheme: ""
    property var soundCandidates: ({})

    readonly property var soundEvents: [
        {
            key: "audio-volume-change",
            bundled: "../assets/sounds/freedesktop/audio-volume-change.wav",
            themeNames: ["audio-volume-change"]
        },
        {
            key: "power-plug",
            bundled: "../assets/sounds/plasma/power-plug.wav",
            themeNames: ["power-plug"]
        },
        {
            key: "power-unplug",
            bundled: "../assets/sounds/plasma/power-unplug.wav",
            themeNames: ["power-unplug"]
        },
        {
            key: "message",
            bundled: "../assets/sounds/freedesktop/message.wav",
            themeNames: ["dialog-information", "message", "message-lowpriority", "bell"]
        },
        {
            key: "message-new-instant",
            bundled: "../assets/sounds/freedesktop/message-new-instant.wav",
            themeNames: ["dialog-warning", "message-new-instant", "message-highlight"]
        },
        {
            key: "alarm-clock-elapsed",
            bundled: "../assets/sounds/freedesktop/alarm-clock-elapsed.oga",
            themeNames: ["alarm-clock-elapsed", "service-login"]
        },
        {
            key: "timer-finished",
            bundled: "../assets/sounds/freedesktop/alarm-clock-elapsed.oga",
            themeNames: ["timer-finished"]
        }
    ]

    readonly property var soundEventKeys: {
        const keys = [];
        for (let i = 0; i < soundEvents.length; i++)
            keys.push(soundEvents[i].key);
        return keys;
    }

    readonly property var bundledThemeOverrides: ({
            "smooth": ["audio-volume-change"]
        })

    property var volumeChangeSound: null
    property var powerPlugSound: null
    property var powerUnplugSound: null
    property var normalNotificationSound: null
    property var criticalNotificationSound: null
    property var alarmSound: null
    property var timerFinishedSound: null
    property var previewPlayer: null
    property string previewKey: ""
    property bool previewPlaying: false
    property bool discoverRunning: false
    property bool discoverQueued: false
    property real notificationsVolume: 1.0
    property bool notificationsAudioMuted: false

    property var mediaDevices: null
    property var mediaDevicesConnections: null

    property var deviceAliases: ({})
    property string wireplumberConfigPath: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/wireplumber/wireplumber.conf.d/51-dms-audio-aliases.conf"
    property bool wireplumberReloading: false

    readonly property int sinkMaxVolume: {
        const name = sink?.name ?? "";
        if (!name)
            return 100;
        return SessionData.deviceMaxVolumes[name] ?? 100;
    }

    signal micMuteChanged
    signal audioOutputCycled(string deviceName, string deviceIcon)
    signal deviceAliasChanged(string nodeName, string newAlias)
    signal wireplumberReloadStarted
    signal wireplumberReloadCompleted(bool success)

    function getMaxVolumePercent(node) {
        if (!node?.name)
            return 100;
        return SessionData.deviceMaxVolumes[node.name] ?? 100;
    }

    Connections {
        target: SessionData
        function onDeviceMaxVolumesChanged() {
            if (!root.sink?.audio)
                return;
            const maxVol = root.sinkMaxVolume;
            const currentPercent = Math.round(root.sink.audio.volume * 100);
            if (currentPercent > maxVol)
                root.sink.audio.volume = maxVol / 100;
        }
    }

    function getAvailableSinks() {
        const hidden = SessionData.hiddenOutputDeviceNames ?? [];
        return Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream && !hidden.includes(node.name));
    }

    function cycleAudioOutput() {
        const sinks = getAvailableSinks();
        if (sinks.length < 2)
            return null;

        const currentName = root.sink?.name ?? "";
        const currentIndex = sinks.findIndex(s => s.name === currentName);
        const nextIndex = (currentIndex + 1) % sinks.length;
        const nextSink = sinks[nextIndex];
        Pipewire.preferredDefaultAudioSink = nextSink;
        const name = displayName(nextSink);
        audioOutputCycled(name, sinkIcon(nextSink));
        return name;
    }

    function getDeviceAlias(nodeName) {
        if (!nodeName)
            return null;
        return deviceAliases[nodeName] || null;
    }

    function hasDeviceAlias(nodeName) {
        if (!nodeName)
            return false;
        return deviceAliases.hasOwnProperty(nodeName) && deviceAliases[nodeName] !== null && deviceAliases[nodeName] !== "";
    }

    function setDeviceAlias(nodeName, customAlias) {
        if (!nodeName) {
            console.error("AudioService: Cannot set alias - nodeName is empty");
            return false;
        }

        if (!customAlias || customAlias.trim() === "") {
            return removeDeviceAlias(nodeName);
        }

        const trimmedAlias = customAlias.trim();

        const updated = Object.assign({}, deviceAliases);
        updated[nodeName] = trimmedAlias;
        deviceAliases = updated;

        writeWireplumberConfig();
        deviceAliasChanged(nodeName, trimmedAlias);
        return true;
    }

    function removeDeviceAlias(nodeName) {
        if (!nodeName)
            return false;

        if (!hasDeviceAlias(nodeName))
            return false;

        const updated = Object.assign({}, deviceAliases);
        delete updated[nodeName];
        deviceAliases = updated;

        writeWireplumberConfig();
        deviceAliasChanged(nodeName, "");
        return true;
    }

    function writeWireplumberConfig() {
        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/wireplumber/wireplumber.conf.d";
        const configContent = generateWireplumberConfig();

        const shellCmd = `mkdir -p "${configDir}" && cat > "${wireplumberConfigPath}" << 'EOFCONFIG'
${configContent}
EOFCONFIG
`;

        Proc.runCommand("writeWireplumberConfig", ["sh", "-c", shellCmd], (output, exitCode) => {
            if (exitCode !== 0) {
                console.error("AudioService: Failed to write WirePlumber config. Exit code:", exitCode);
                console.error("AudioService: Error output:", output);
                ToastService.showError(I18n.tr("Failed to save audio config"), output || "");
                return;
            }

            reloadWireplumberConfig();
        }, 0);
    }

    function generateWireplumberConfig() {
        let config = "# Generated by DankMaterialShell - Audio Device Aliases\n";
        config += "# Do not edit manually - changes will be overwritten\n";
        config += "# Last updated: " + new Date().toISOString() + "\n\n";

        const aliasKeys = Object.keys(deviceAliases);
        if (aliasKeys.length === 0) {
            config += "# No device aliases configured\n";
            return config;
        }

        const alsaAliases = [];
        const bluezAliases = [];
        const otherAliases = [];

        for (const nodeName of aliasKeys) {
            const alias = deviceAliases[nodeName];
            if (!alias)
                continue;

            const rule = {
                nodeName: nodeName,
                alias: alias
            };

            if (nodeName.includes("alsa")) {
                alsaAliases.push(rule);
            } else if (nodeName.includes("bluez")) {
                bluezAliases.push(rule);
            } else {
                otherAliases.push(rule);
            }
        }

        if (alsaAliases.length > 0) {
            config += "monitor.alsa.rules = [\n";
            for (let i = 0; i < alsaAliases.length; i++) {
                const rule = alsaAliases[i];
                config += "  {\n";
                config += `    matches = [ { "node.name" = "${rule.nodeName}" } ]\n`;
                config += `    actions = { update-props = { "node.description" = "${rule.alias}" } }\n`;
                config += "  }";
                if (i < alsaAliases.length - 1)
                    config += ",";
                config += "\n";
            }
            config += "]\n\n";
        }

        if (bluezAliases.length > 0) {
            config += "monitor.bluez.rules = [\n";
            for (let i = 0; i < bluezAliases.length; i++) {
                const rule = bluezAliases[i];
                config += "  {\n";
                config += `    matches = [ { "node.name" = "${rule.nodeName}" } ]\n`;
                config += `    actions = { update-props = { "node.description" = "${rule.alias}" } }\n`;
                config += "  }";
                if (i < bluezAliases.length - 1)
                    config += ",";
                config += "\n";
            }
            config += "]\n\n";
        }

        if (otherAliases.length > 0) {
            config += "# Other device aliases (RAOP, USB, and other devices)\n";
            config += "wireplumber.rules = [\n";
            for (let i = 0; i < otherAliases.length; i++) {
                const rule = otherAliases[i];
                config += "  {\n";
                config += `    matches = [\n`;
                config += `      { "node.name" = "${rule.nodeName}" }\n`;
                config += `    ]\n`;
                config += `    actions = {\n`;
                config += `      update-props = {\n`;
                config += `        "node.description" = "${rule.alias}"\n`;
                config += `        "node.nick" = "${rule.alias}"\n`;
                config += `        "device.description" = "${rule.alias}"\n`;
                config += `      }\n`;
                config += `    }\n`;
                config += "  }";
                if (i < otherAliases.length - 1)
                    config += ",";
                config += "\n";
            }
            config += "]\n";
        }

        return config;
    }

    function reloadWireplumberConfig() {
        if (wireplumberReloading) {
            return;
        }

        wireplumberReloading = true;
        wireplumberReloadStarted();

        Proc.runCommand("restartWireplumber", ["systemctl", "--user", "restart", "wireplumber"], (output, exitCode) => {
            wireplumberReloading = false;

            if (exitCode === 0) {
                ToastService.showInfo(I18n.tr("Audio system restarted"), I18n.tr("Device names updated"));
                wireplumberReloadCompleted(true);
            } else {
                console.error("AudioService: Failed to restart WirePlumber:", output);
                ToastService.showError(I18n.tr("Failed to restart audio system"), output);
                wireplumberReloadCompleted(false);
            }
        }, 5000);
    }

    function loadDeviceAliases() {
        const configPath = wireplumberConfigPath;

        Proc.runCommand("readWireplumberConfig", ["cat", configPath], (output, exitCode) => {
            if (exitCode !== 0) {
                console.log("AudioService: No existing WirePlumber config found");
                return;
            }

            const aliases = {};
            const lines = output.split('\n');
            let currentNodeName = null;

            for (const line of lines) {
                const nodeNameMatch = line.match(/"node\.name"\s*=\s*"([^"]+)"/);
                if (nodeNameMatch) {
                    currentNodeName = nodeNameMatch[1];
                }

                const descriptionMatch = line.match(/"node\.description"\s*=\s*"([^"]+)"/);
                if (descriptionMatch && currentNodeName) {
                    aliases[currentNodeName] = descriptionMatch[1];
                    currentNodeName = null;
                }
            }

            if (Object.keys(aliases).length > 0) {
                deviceAliases = aliases;
                console.log("AudioService: Loaded", Object.keys(aliases).length, "device aliases");
            }
        }, 0);
    }

    Connections {
        target: root.sink?.audio ?? null

        function onVolumeChanged() {
            if (SessionData.suppressOSD)
                return;
            root.playVolumeChangeSoundIfEnabled();
        }
    }

    function checkGsettings() {
        Proc.runCommand("checkGsettings", ["sh", "-c", "gsettings get org.gnome.desktop.sound theme-name 2>/dev/null"], (output, exitCode) => {
            gsettingsAvailable = (exitCode === 0);
            if (gsettingsAvailable) {
                getCurrentSoundTheme();
            }
        }, 0);
    }

    function scanSoundThemes() {
        const xdgDataDirs = Quickshell.env("XDG_DATA_DIRS");
        const searchPaths = xdgDataDirs && xdgDataDirs.trim() !== "" ? xdgDataDirs.split(":").concat(Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation))) : ["/usr/share", "/usr/local/share", Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation))];

        const basePaths = searchPaths.map(p => p + "/sounds").join(" ");
        const script = `
            for base_dir in ${basePaths}; do
                [ -d "$base_dir" ] || continue
                for theme_dir in "$base_dir"/*; do
                    [ -d "$theme_dir/stereo" ] || continue
                    basename "$theme_dir"
                done
            done | sort -u
        `;

        Proc.runCommand("scanSoundThemes", ["sh", "-c", script], (output, exitCode) => {
            if (exitCode === 0 && output.trim()) {
                const themes = output.trim().split('\n').filter(t => t && t.length > 0);
                availableSoundThemes = themes;
            } else {
                availableSoundThemes = [];
            }
            reloadSounds();
        }, 0);
    }

    function getCurrentSoundTheme() {
        Proc.runCommand("getCurrentSoundTheme", ["sh", "-c", "gsettings get org.gnome.desktop.sound theme-name 2>/dev/null | sed \"s/'//g\""], (output, exitCode) => {
            if (exitCode === 0 && output.trim()) {
                currentSoundTheme = output.trim();
            } else {
                currentSoundTheme = "";
            }
            reloadSounds();
        }, 0);
    }

    function setSoundTheme(themeName) {
        if (!themeName || themeName === currentSoundTheme) {
            return;
        }

        Proc.runCommand("setSoundTheme", ["sh", "-c", `gsettings set org.gnome.desktop.sound theme-name '${themeName}'`], (output, exitCode) => {
            if (exitCode === 0) {
                currentSoundTheme = themeName;
                reloadSounds();
            }
        }, 0);
    }

    function soundEventEntry(soundEvent) {
        return soundEvents.find(entry => entry.key === soundEvent) ?? null;
    }

    function bundledPathFor(soundEvent) {
        const entry = soundEventEntry(soundEvent);
        if (!entry)
            return Qt.resolvedUrl("../assets/sounds/freedesktop/message.wav");
        return Qt.resolvedUrl(entry.bundled);
    }

    function bundledFilePath(soundEvent) {
        return Paths.strip(bundledPathFor(soundEvent));
    }

    function customSoundPath(soundEvent) {
        return SettingsData.soundEvents?.[soundEvent]?.custom ?? "";
    }

    function isSoundEventEnabled(soundEvent) {
        if (!SettingsData.soundsEnabled)
            return false;
        return SettingsData.soundEvents?.[soundEvent]?.enabled ?? true;
    }

    function themeSoundPath(soundEvent) {
        if (!SettingsData.useSystemSoundTheme)
            return "";
        if (bundledThemeOverrides[currentSoundTheme.toLowerCase()]?.includes(soundEvent))
            return "";
        const candidates = soundCandidates[soundEvent];
        if (!candidates || candidates.length === 0)
            return "";
        return Paths.toFileUrl(candidates[0]);
    }

    function getSoundPath(soundEvent) {
        const custom = customSoundPath(soundEvent);
        if (custom)
            return Paths.toFileUrl(custom);
        const themed = themeSoundPath(soundEvent);
        if (themed)
            return themed;
        return bundledPathFor(soundEvent);
    }

    function soundSourceOptions(soundEvent) {
        const files = [bundledFilePath(soundEvent)].concat(soundCandidates[soundEvent] ?? []);
        const options = [];
        for (const file of files) {
            const label = Paths.shortenHome(file);
            if (!options.includes(label))
                options.push(label);
        }
        return options;
    }

    function soundSourceLabel(soundEvent) {
        const custom = customSoundPath(soundEvent);
        if (custom)
            return Paths.shortenHome(custom);
        const themed = themeSoundPath(soundEvent);
        if (themed)
            return I18n.tr("System theme");
        return I18n.tr("Default");
    }

    function setEventEnabled(soundEvent, enabled) {
        const current = SettingsData.soundEvents ?? {};
        const entry = Object.assign({}, current[soundEvent] ?? {});
        entry.enabled = enabled;
        const updated = Object.assign({}, current);
        updated[soundEvent] = entry;
        SettingsData.set("soundEvents", updated);
    }

    function setCustomSound(soundEvent, path) {
        if (!path)
            return;
        const current = SettingsData.soundEvents ?? {};
        const entry = Object.assign({}, current[soundEvent] ?? {});
        entry.custom = path;
        const updated = Object.assign({}, current);
        updated[soundEvent] = entry;
        SettingsData.set("soundEvents", updated);
    }

    function clearCustomSound(soundEvent) {
        const current = SettingsData.soundEvents ?? {};
        if (!current[soundEvent]?.custom)
            return;
        const entry = Object.assign({}, current[soundEvent]);
        delete entry.custom;
        const updated = Object.assign({}, current);
        if (Object.keys(entry).length === 0)
            delete updated[soundEvent];
        else
            updated[soundEvent] = entry;
        SettingsData.set("soundEvents", updated);
    }

    function selectSoundSource(soundEvent, label) {
        if (!label)
            return;
        if (label === Paths.shortenHome(bundledFilePath(soundEvent))) {
            clearCustomSound(soundEvent);
            return;
        }
        setCustomSound(soundEvent, Paths.expandTilde(label));
    }

    function previewSound(soundEvent) {
        if (!soundsAvailable || !previewPlayer)
            return;
        if (previewKey === soundEvent && previewPlaying) {
            stopPreview();
            return;
        }
        previewKey = soundEvent;
        previewPlayer.stop();
        previewPlayer.source = getSoundPath(soundEvent);
        previewPlayer.play();
    }

    function stopPreview() {
        if (previewPlayer)
            previewPlayer.stop();
        previewKey = "";
        previewPlaying = false;
    }

    function refreshSoundSources() {
        if (!soundsAvailable)
            return;

        for (const binding of soundPlayerBindings()) {
            const player = root[binding.property];
            if (!player)
                continue;
            const source = String(getSoundPath(binding.key) ?? "");
            if (String(player.source ?? "") === source)
                continue;
            player.stop();
            player.source = source;
        }
    }

    function discoverSoundFiles() {
        if (discoverRunning) {
            discoverQueued = true;
            return;
        }
        discoverRunning = true;

        const xdgDataDirs = Quickshell.env("XDG_DATA_DIRS");
        const searchPaths = xdgDataDirs && xdgDataDirs.trim() !== "" ? xdgDataDirs.split(":").concat(Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation))) : ["/usr/share", "/usr/local/share", Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation))];

        const extensions = ["oga", "ogg", "wav", "mp3", "flac", "opus", "m4a"];

        const themes = [];
        const addTheme = name => {
            if (name && name !== "" && !themes.includes(name))
                themes.push(name);
        };
        addTheme(currentSoundTheme);
        for (const name of availableSoundThemes)
            addTheme(name);
        addTheme("freedesktop");

        if (themes.length === 0) {
            soundCandidates = {};
            discoverRunning = false;
            refreshSoundSources();
            return;
        }

        const script = soundEvents.map(entry => `for event_name in ${entry.themeNames.join(" ")}; do
    for theme in ${themes.join(" ")}; do
        for base_path in ${searchPaths.join(" ")}; do
            for ext in ${extensions.join(" ")}; do
                file_path="$base_path/sounds/$theme/stereo/$event_name.$ext"
                [ -f "$file_path" ] && echo "${entry.key}=$file_path"
            done
        done
    done
done`).join("\n");

        Proc.runCommand("discoverSoundFiles", ["sh", "-c", script], (output, exitCode) => {
            const found = {};
            if (exitCode === 0 && output.trim()) {
                for (const line of output.trim().split('\n')) {
                    const separator = line.indexOf('=');
                    if (separator < 1)
                        continue;
                    const key = line.slice(0, separator);
                    const filePath = line.slice(separator + 1);
                    if (!found[key])
                        found[key] = [];
                    if (!found[key].includes(filePath))
                        found[key].push(filePath);
                }
            }

            const candidates = {};
            for (const entry of soundEvents)
                candidates[entry.key] = found[entry.key] ?? [];
            soundCandidates = candidates;

            discoverRunning = false;
            if (discoverQueued) {
                discoverQueued = false;
                discoverSoundFiles();
            }
            refreshSoundSources();
        }, 0);
    }

    function reloadSounds() {
        discoverSoundFiles();
    }

    function setupMediaDevices() {
        if (!soundsAvailable || mediaDevices) {
            return;
        }

        try {
            mediaDevices = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                MediaDevices {
                    id: devices
                    Component.onCompleted: {
                        console.log("AudioService: MediaDevices initialized, default output:", defaultAudioOutput?.description)
                    }
                }
            `, root, "AudioService.MediaDevices");

            if (mediaDevices) {
                mediaDevicesConnections = Qt.createQmlObject(`
                    import QtQuick
                    Connections {
                        target: root.mediaDevices
                        function onDefaultAudioOutputChanged() {
                            console.log("AudioService: Default audio output changed, recreating sound players")
                            root.destroySoundPlayers()
                            root.createSoundPlayers()
                        }
                    }
                `, root, "AudioService.MediaDevicesConnections");
            }
        } catch (e) {
            console.log("AudioService: MediaDevices not available, using default audio output");
            mediaDevices = null;
        }
    }

    function soundPlayerBindings() {
        return [
            { property: "volumeChangeSound", key: "audio-volume-change", loops: false },
            { property: "powerPlugSound", key: "power-plug", loops: false },
            { property: "powerUnplugSound", key: "power-unplug", loops: false },
            { property: "normalNotificationSound", key: "message", loops: false },
            { property: "criticalNotificationSound", key: "message-new-instant", loops: false },
            { property: "alarmSound", key: "alarm-clock-elapsed", loops: true },
            { property: "timerFinishedSound", key: "timer-finished", loops: true }
        ];
    }

    function destroySoundPlayers() {
        previewPlaying = false;
        previewKey = "";

        for (const binding of soundPlayerBindings()) {
            const player = root[binding.property];
            if (!player)
                continue;
            player.destroy();
            root[binding.property] = null;
        }

        if (previewPlayer) {
            previewPlayer.destroy();
            previewPlayer = null;
        }
    }

    function createSoundPlayers() {
        if (!soundsAvailable) {
            return;
        }

        setupMediaDevices();

        const deviceProperty = mediaDevices ? "device: root.mediaDevices.defaultAudioOutput\n                        " : "";

        try {
            for (const binding of soundPlayerBindings()) {
                const loopsProperty = binding.loops ? "loops: MediaPlayer.Infinite\n                    " : "";
                root[binding.property] = Qt.createQmlObject(`
                    import QtQuick
                    import QtMultimedia
                    MediaPlayer {
                        source: "${getSoundPath(binding.key)}"
                        ${loopsProperty}audioOutput: AudioOutput {
                            ${deviceProperty}volume: notificationsVolume
                        }
                    }
                `, root, `AudioService.${binding.property}`);
            }

            previewPlayer = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                MediaPlayer {
                    audioOutput: AudioOutput {
                        ${deviceProperty}volume: notificationsVolume
                    }
                    onPlaybackStateChanged: root.previewPlaying = playbackState === MediaPlayer.PlayingState
                }
            `, root, "AudioService.PreviewPlayer");
        } catch (e) {
            console.warn("AudioService: Error creating sound players:", e);
        }
    }

    function isMediaPlaying() {
        return MprisController.activePlayer?.isPlaying ?? false;
    }

    function playVolumeChangeSound() {
        if (!soundsAvailable || !volumeChangeSound || notificationsAudioMuted || isMediaPlaying())
            return;
        if (!isSoundEventEnabled("audio-volume-change"))
            return;
        volumeChangeSound.play();
    }

    function playPowerPlugSound() {
        if (!soundsAvailable || !powerPlugSound || notificationsAudioMuted || isMediaPlaying())
            return;
        if (!isSoundEventEnabled("power-plug"))
            return;
        powerPlugSound.play();
    }

    function playPowerUnplugSound() {
        if (!soundsAvailable || !powerUnplugSound || notificationsAudioMuted || isMediaPlaying())
            return;
        if (!isSoundEventEnabled("power-unplug"))
            return;
        powerUnplugSound.play();
    }

    function playNormalNotificationSound() {
        if (!soundsAvailable || !normalNotificationSound || SessionData.doNotDisturb || notificationsAudioMuted || isMediaPlaying())
            return;
        if (!isSoundEventEnabled("message"))
            return;
        normalNotificationSound.play();
    }

    function playCriticalNotificationSound() {
        if (!soundsAvailable || !criticalNotificationSound || SessionData.doNotDisturb || notificationsAudioMuted || isMediaPlaying())
            return;
        if (!isSoundEventEnabled("message-new-instant"))
            return;
        criticalNotificationSound.play();
    }

    function playVolumeChangeSoundIfEnabled() {
        if (SettingsData.soundsEnabled && !notificationsAudioMuted) {
            playVolumeChangeSound();
        }
    }

    function playAlarmRing() {
        if (!soundsAvailable || !alarmSound)
            return;
        if (!isSoundEventEnabled("alarm-clock-elapsed"))
            return;
        alarmSound.stop();
        alarmSound.position = 0;
        alarmSound.play();
    }

    function stopAlarmRing() {
        if (!alarmSound)
            return;
        alarmSound.stop();
        alarmSound.position = 0;
    }

    function playTimerFinished() {
        if (!soundsAvailable || !timerFinishedSound)
            return;
        if (!isSoundEventEnabled("timer-finished"))
            return;
        timerFinishedSound.stop();
        timerFinishedSound.position = 0;
        timerFinishedSound.play();
    }

    function stopTimerFinished() {
        if (!timerFinishedSound)
            return;
        timerFinishedSound.stop();
        timerFinishedSound.position = 0;
    }

    function sinkIcon(node) {
        if (!node)
            return "speaker";

        const props = node.properties || {};
        const formFactor = (props["device.form-factor"] || "").toLowerCase();

        switch (formFactor) {
        case "headphone":
        case "headset":
        case "hands-free":
        case "handset":
            return "headset";
        case "tv":
        case "monitor":
            return "tv";
        case "speaker":
        case "computer":
        case "hifi":
        case "portable":
        case "car":
            return "speaker";
        }

        const bus = (props["device.bus"] || "").toLowerCase();
        if (bus === "bluetooth")
            return "headset";

        const name = (node.name || "").toLowerCase();
        if (name.includes("hdmi"))
            return "tv";
        if (name.includes("iec958") || name.includes("spdif"))
            return "speaker";

        if (bus === "usb")
            return "headset";

        return "speaker";
    }

    function displayName(node) {
        if (!node) {
            return "";
        }

        // FIRST: Check if we have a custom alias in our deviceAliases map
        // This ensures we always show the user's custom name, regardless of
        // whether WirePlumber has applied it to the node properties yet
        if (node.name && deviceAliases[node.name]) {
            return deviceAliases[node.name];
        }

        // Check node.properties["node.description"] for WirePlumber-applied aliases
        // This is the live property updated by WirePlumber rules
        if (node.properties && node.properties["node.description"]) {
            const desc = node.properties["node.description"];
            if (desc !== node.name) {
                return desc;
            }
        }

        // Check cached description as fallback
        if (node.description && node.description !== node.name) {
            return node.description;
        }

        // Fallback to device description property
        if (node.properties && node.properties["device.description"]) {
            return node.properties["device.description"];
        }

        // Fallback to nickname
        if (node.nickname && node.nickname !== node.name) {
            return node.nickname;
        }

        // Fallback to friendly names based on node name patterns
        if (node.name.includes("analog-stereo")) {
            return "Built-in Audio Analog Stereo";
        }
        if (node.name.includes("bluez")) {
            return "Bluetooth Audio";
        }
        if (node.name.includes("usb")) {
            return "USB Audio";
        }
        if (node.name.includes("hdmi")) {
            return "HDMI Audio";
        }

        return node.name;
    }

    function originalName(node) {
        if (!node) {
            return "";
        }

        // Get the original name without checking for custom aliases
        // Check pattern-based friendly names FIRST (before device.description)
        // This ensures we show user-friendly names like "Built-in Audio Analog Stereo"
        // instead of hardware chip names like "ALC274 Analog"
        if (node.name.includes("analog-stereo")) {
            return "Built-in Audio Analog Stereo";
        }
        if (node.name.includes("bluez")) {
            return "Bluetooth Audio";
        }
        if (node.name.includes("usb")) {
            return "USB Audio";
        }
        if (node.name.includes("hdmi")) {
            return "HDMI Audio";
        }
        if (node.name.includes("raop_sink")) {
            // Extract friendly name from RAOP node name
            const match = node.name.match(/raop_sink\.([^.]+)/);
            if (match) {
                return match[1].replace(/-/g, " ");
            }
        }

        // Fallback to device.description property
        if (node.properties && node.properties["device.description"]) {
            return node.properties["device.description"];
        }

        // Fallback to nickname
        if (node.nickname && node.nickname !== node.name) {
            return node.nickname;
        }

        return node.name;
    }

    function subtitle(name) {
        if (!name) {
            return "";
        }

        if (name.includes('usb-')) {
            if (name.includes('SteelSeries')) {
                return "USB Gaming Headset";
            }
            if (name.includes('Generic')) {
                return "USB Audio Device";
            }
            return "USB Audio";
        }

        if (name.includes('pci-')) {
            if (name.includes('01_00.1') || name.includes('01:00.1')) {
                return "NVIDIA GPU Audio";
            }
            return "PCI Audio";
        }

        if (name.includes('bluez')) {
            return "Bluetooth Audio";
        }
        if (name.includes('analog')) {
            return "Built-in Audio";
        }
        if (name.includes('hdmi')) {
            return "HDMI Audio";
        }

        return "";
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => node.audio && !node.isStream)
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            if (soundsAvailable) {
                Qt.callLater(root.destroySoundPlayers);
                Qt.callLater(root.createSoundPlayers);
            }
        }
    }

    function setVolume(percentage) {
        if (!root.sink?.audio)
            return "No audio sink available";

        const maxVol = root.sinkMaxVolume;
        const clampedVolume = Math.max(0, Math.min(maxVol, percentage));
        root.sink.audio.volume = clampedVolume / 100;
        return `Volume set to ${clampedVolume}%`;
    }

    function toggleMute() {
        if (!root.sink?.audio) {
            return "No audio sink available";
        }

        root.sink.audio.muted = !root.sink.audio.muted;
        return root.sink.audio.muted ? "Audio muted" : "Audio unmuted";
    }

    function setMicVolume(percentage) {
        if (!root.source?.audio) {
            return "No audio source available";
        }

        const clampedVolume = Math.max(0, Math.min(100, percentage));
        root.source.audio.volume = clampedVolume / 100;
        return `Microphone volume set to ${clampedVolume}%`;
    }

    function toggleMicMute() {
        if (!root.source?.audio) {
            return "No audio source available";
        }

        root.source.audio.muted = !root.source.audio.muted;
        return root.source.audio.muted ? "Microphone muted" : "Microphone unmuted";
    }

    IpcHandler {
        target: "audio"

        function setvolume(percentage: string): string {
            return root.setVolume(parseInt(percentage));
        }

        function increment(step: string): string {
            if (!root.sink?.audio)
                return "No audio sink available";

            if (root.sink.audio.muted)
                root.sink.audio.muted = false;

            const maxVol = root.sinkMaxVolume;
            const currentVolume = Math.round(root.sink.audio.volume * 100);
            const stepValue = parseInt(step || "5");
            const newVolume = Math.max(0, Math.min(maxVol, currentVolume + stepValue));

            root.sink.audio.volume = newVolume / 100;
            return `Volume increased to ${newVolume}%`;
        }

        function decrement(step: string): string {
            if (!root.sink?.audio)
                return "No audio sink available";

            if (root.sink.audio.muted)
                root.sink.audio.muted = false;

            const maxVol = root.sinkMaxVolume;
            const currentVolume = Math.round(root.sink.audio.volume * 100);
            const stepValue = parseInt(step || "5");
            const newVolume = Math.max(0, Math.min(maxVol, currentVolume - stepValue));

            root.sink.audio.volume = newVolume / 100;
            return `Volume decreased to ${newVolume}%`;
        }

        function mute(): string {
            return root.toggleMute();
        }

        function setmic(percentage: string): string {
            return root.setMicVolume(parseInt(percentage));
        }

        function micmute(): string {
            const result = root.toggleMicMute();
            root.micMuteChanged();
            return result;
        }

        function status(): string {
            let result = "Audio Status:\n";

            if (root.sink?.audio) {
                const volume = Math.round(root.sink.audio.volume * 100);
                const muteStatus = root.sink.audio.muted ? " (muted)" : "";
                const maxVol = root.sinkMaxVolume;
                result += `Output: ${volume}%${muteStatus} (max: ${maxVol}%)\n`;
            } else {
                result += "Output: No sink available\n";
            }

            if (root.source?.audio) {
                const micVolume = Math.round(root.source.audio.volume * 100);
                const muteStatus = root.source.audio.muted ? " (muted)" : "";
                result += `Input: ${micVolume}%${muteStatus}`;
            } else {
                result += "Input: No source available";
            }

            return result;
        }

        function getmaxvolume(): string {
            return `${root.sinkMaxVolume}`;
        }

        function setmaxvolume(percent: string): string {
            if (!root.sink?.name)
                return "No audio sink available";
            const val = parseInt(percent);
            if (isNaN(val))
                return "Invalid percentage";
            SessionData.setDeviceMaxVolume(root.sink.name, val);
            return `Max volume set to ${SessionData.getDeviceMaxVolume(root.sink.name)}%`;
        }

        function getmaxvolumefor(nodeName: string): string {
            if (!nodeName)
                return "No node name specified";
            return `${SessionData.getDeviceMaxVolume(nodeName)}`;
        }

        function setmaxvolumefor(nodeName: string, percent: string): string {
            if (!nodeName)
                return "No node name specified";
            const val = parseInt(percent);
            if (isNaN(val))
                return "Invalid percentage";
            SessionData.setDeviceMaxVolume(nodeName, val);
            return `Max volume for ${nodeName} set to ${SessionData.getDeviceMaxVolume(nodeName)}%`;
        }

        function cycleoutput(): string {
            const result = root.cycleAudioOutput();
            if (!result)
                return "Only one audio output available";
            return `Switched to: ${result}`;
        }
    }

    Connections {
        target: SettingsData
        function onUseSystemSoundThemeChanged() {
            reloadSounds();
        }
        function onSoundEventsChanged() {
            refreshSoundSources();
        }
    }

    Component.onCompleted: {
        if (soundsAvailable) {
            checkGsettings();
            scanSoundThemes();
            Qt.callLater(createSoundPlayers);
        }

        loadDeviceAliases();
    }
}
