pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property string profileImage: ""
    property int systemColorScheme: 0
    property string colorSchemeCommand: ""
    property bool settingsPortalAvailable: false

    property string _pendingProfileImage: ""

    function getSystemProfileImage() {
        const username = Quickshell.env("USER");
        if (!username)
            return;
        getProfileImageForUser(username);
    }

    function getProfileImageForUser(username) {
        if (!username) {
            profileImage = "";
            return;
        }
        userImageProcess.command = ["bash", "-c", `uid=$(id -u ${username} 2>/dev/null) && [ -n "$uid" ] && dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User$uid org.freedesktop.DBus.Properties.Get string:org.freedesktop.Accounts.User string:IconFile 2>/dev/null | grep -oP 'string "\\K[^"]+' || echo ""`];
        userImageProcess.running = true;
    }

    function setProfileImage(imagePath) {
        _pendingProfileImage = imagePath || "";
        if (!_pendingProfileImage) {
            profileImage = "";
            return;
        }
        setProfileImageProcess.command = ["bash", "-c", `dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User$(id -u) org.freedesktop.Accounts.User.SetIconFile string:"${_pendingProfileImage}" 2>/dev/null && echo "OK" || echo "FAIL"`];
        setProfileImageProcess.running = true;
    }

    function getSystemColorScheme() {
        if (typeof SettingsData !== "undefined" && SettingsData.syncModeWithPortal === false)
            return;
        colorSchemeReadProcess.running = true;
    }

    function setLightMode(isLightMode) {
        if (typeof SettingsData !== "undefined" && SettingsData.syncModeWithPortal === false)
            return;
        setSystemColorScheme(isLightMode);
    }

    function setSystemColorScheme(isLightMode) {
        if (typeof SettingsData !== "undefined" && SettingsData.syncModeWithPortal === false)
            return;

        const targetScheme = isLightMode ? "default" : "prefer-dark";

        if (colorSchemeCommand === "gsettings") {
            Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", targetScheme]);
        }
        if (colorSchemeCommand === "dconf") {
            Quickshell.execDetached(["dconf", "write", "/org/gnome/desktop/interface/color-scheme", `'${targetScheme}'`]);
        }
    }

    function setSystemIconTheme(themeName) {
        if (!themeName || themeName === "")
            return;
        if (colorSchemeCommand === "gsettings") {
            Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", themeName]);
        } else if (colorSchemeCommand === "dconf") {
            Quickshell.execDetached(["dconf", "write", "/org/gnome/desktop/interface/icon-theme", `'${themeName}'`]);
        }
    }

    function probeSettingsPortal() {
        settingsProbeProcess.running = true;
    }

    Component.onCompleted: {
        colorSchemeDetector.running = true;
        getSystemProfileImage();
        probeSettingsPortal();
    }

    Process {
        id: userImageProcess
        command: []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const trimmed = text.trim();
                if (trimmed && trimmed !== "" && !trimmed.includes("Error") && trimmed !== "/var/lib/AccountsService/icons/") {
                    root.profileImage = trimmed;
                } else {
                    root.profileImage = "";
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.profileImage = "";
            }
        }
    }

    Process {
        id: setProfileImageProcess
        command: []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const trimmed = text.trim();
                if (trimmed.includes("OK")) {
                    root.profileImage = root._pendingProfileImage;
                    root._pendingProfileImage = "";
                    Qt.callLater(() => root.getSystemProfileImage());
                } else {
                    const userMessage = I18n.tr("Failed to set profile image");
                    Quickshell.execDetached(["notify-send", "-u", "normal", "-a", "DMS", "-i", "error", I18n.tr("Profile Image Error"), userMessage]);
                    root._pendingProfileImage = "";
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root._pendingProfileImage = "";
            }
        }
    }

    Process {
        id: colorSchemeReadProcess
        command: ["bash", "-c", "dbus-send --session --print-reply --dest=org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.Settings.ReadOne string:\"org.freedesktop.appearance\" string:\"color-scheme\" 2>/dev/null"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/uint32\s+(\d+)/);
                if (match) {
                    root.systemColorScheme = parseInt(match[1]);
                }
            }
        }
    }

    Process {
        id: settingsProbeProcess
        command: ["bash", "-c", "dbus-send --session --print-reply --dest=org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.Settings.ReadOne string:\"org.freedesktop.appearance\" string:\"color-scheme\" 2>/dev/null && echo \"AVAILABLE\" || echo \"UNAVAILABLE\""]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.settingsPortalAvailable = text.includes("AVAILABLE");
                if (root.settingsPortalAvailable && typeof SettingsData !== "undefined" && SettingsData.syncModeWithPortal) {
                    root.getSystemColorScheme();
                }
            }
        }
    }

    Process {
        id: colorSchemeDetector
        command: ["bash", "-c", "command -v gsettings || command -v dconf"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const cmd = text.trim();
                if (cmd.includes("gsettings")) {
                    root.colorSchemeCommand = "gsettings";
                } else if (cmd.includes("dconf")) {
                    root.colorSchemeCommand = "dconf";
                }
            }
        }
    }
}
