import QtQuick
import Quickshell
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    property string browseTarget: ""

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4

            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                tab: "sounds"
                tags: ["sound", "audio", "notification", "volume"]
                title: I18n.tr("System Sounds")
                settingKey: "systemSounds"
                iconName: SettingsData.soundsEnabled ? "volume_up" : "volume_off"
                visible: AudioService.soundsAvailable

                SettingsToggleRow {
                    tab: "sounds"
                    tags: ["sound", "enable", "system"]
                    settingKey: "soundsEnabled"
                    text: I18n.tr("Enable System Sounds")
                    description: I18n.tr("Play sounds for system events")
                    checked: SettingsData.soundsEnabled
                    onToggled: checked => SettingsData.set("soundsEnabled", checked)
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: SettingsData.soundsEnabled

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                    }

                    SettingsToggleRow {
                        tab: "sounds"
                        tags: ["sound", "theme", "system"]
                        settingKey: "useSystemSoundTheme"
                        visible: AudioService.gsettingsAvailable
                        text: I18n.tr("Use System Theme")
                        description: I18n.tr("Use sound theme from system settings")
                        checked: SettingsData.useSystemSoundTheme
                        onToggled: checked => SettingsData.set("useSystemSoundTheme", checked)
                    }

                    SettingsDropdownRow {
                        tab: "sounds"
                        tags: ["sound", "theme", "select"]
                        settingKey: "soundTheme"
                        visible: SettingsData.useSystemSoundTheme && AudioService.availableSoundThemes.length > 0
                        enabled: SettingsData.useSystemSoundTheme && AudioService.availableSoundThemes.length > 0
                        text: I18n.tr("Sound Theme")
                        description: I18n.tr("Select system sound theme")
                        options: AudioService.availableSoundThemes
                        currentValue: {
                            const theme = AudioService.currentSoundTheme;
                            if (theme && AudioService.availableSoundThemes.includes(theme))
                                return theme;
                            return AudioService.availableSoundThemes.length > 0 ? AudioService.availableSoundThemes[0] : "";
                        }
                        onValueChanged: value => {
                            if (value && value !== AudioService.currentSoundTheme)
                                AudioService.setSoundTheme(value);
                        }
                    }
                }
            }

            SettingsCard {
                tab: "sounds"
                tags: ["sound", "audio", "custom", "event"]
                title: I18n.tr("Individual Sounds")
                settingKey: "soundEvents"
                iconName: "music_note"
                visible: AudioService.soundsAvailable && SettingsData.soundsEnabled

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    SettingsSoundRow {
                        tab: "sounds"
                        tags: ["sound", "volume", "slider", "changed"]
                        settingKey: "soundVolumeChange"
                        eventKey: "audio-volume-change"
                        text: I18n.tr("Volume Changed", "Row label for the output volume change sound setting")
                        description: I18n.tr("Plays when the output volume is adjusted")
                        onBrowseRequested: key => root.openSoundBrowser(key)
                    }

                    SettingsSoundRow {
                        tab: "sounds"
                        tags: ["sound", "battery", "power", "charge", "plugged"]
                        settingKey: "soundPowerPlug"
                        eventKey: "power-plug"
                        visible: BatteryService.batteryAvailable
                        text: I18n.tr("Power Plugged In", "Row label for the charger connected sound setting")
                        description: I18n.tr("Plays when the charger is connected")
                        onBrowseRequested: key => root.openSoundBrowser(key)
                    }

                    SettingsSoundRow {
                        tab: "sounds"
                        tags: ["sound", "battery", "power", "charge", "unplugged"]
                        settingKey: "soundPowerUnplug"
                        eventKey: "power-unplug"
                        visible: BatteryService.batteryAvailable
                        text: I18n.tr("Power Unplugged", "Row label for the charger removed sound setting")
                        description: I18n.tr("Plays when the charger is removed")
                        onBrowseRequested: key => root.openSoundBrowser(key)
                    }

                    SettingsSoundRow {
                        tab: "sounds"
                        tags: ["sound", "notification", "new", "message"]
                        settingKey: "soundMessage"
                        eventKey: "message"
                        text: I18n.tr("Notification", "Row label for the normal notification sound setting")
                        description: I18n.tr("Plays when a notification arrives")
                        onBrowseRequested: key => root.openSoundBrowser(key)
                    }

                    SettingsSoundRow {
                        tab: "sounds"
                        tags: ["sound", "notification", "urgent", "critical"]
                        settingKey: "soundCriticalNotification"
                        eventKey: "message-new-instant"
                        text: I18n.tr("Urgent Notification", "Row label for the critical notification sound setting")
                        description: I18n.tr("Plays when a critical notification arrives")
                        onBrowseRequested: key => root.openSoundBrowser(key)
                    }

                    SettingsSoundRow {
                        tab: "sounds"
                        tags: ["sound", "alarm", "clock", "wake"]
                        settingKey: "soundAlarm"
                        eventKey: "alarm-clock-elapsed"
                        text: I18n.tr("Alarm", "Row label for the alarm sound setting")
                        description: I18n.tr("Plays while an alarm is ringing")
                        onBrowseRequested: key => root.openSoundBrowser(key)
                    }

                    SettingsSoundRow {
                        tab: "sounds"
                        tags: ["sound", "timer", "clock", "countdown"]
                        settingKey: "soundTimerFinished"
                        eventKey: "timer-finished"
                        text: I18n.tr("Timer Finished", "Row label for the timer finished sound setting")
                        description: I18n.tr("Plays when a timer counts down to zero")
                        onBrowseRequested: key => root.openSoundBrowser(key)
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: notAvailableText.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                visible: !AudioService.soundsAvailable

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "info"
                        size: Theme.iconSizeSmall
                        color: Theme.warning
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        id: notAvailableText
                        font.pixelSize: Theme.fontSizeSmall
                        text: I18n.tr("System sounds are not available. Install %1 for sound support.").arg("qt6-multimedia")
                        wrapMode: Text.WordWrap
                        width: parent.width - Theme.iconSizeSmall - Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    function openSoundBrowser(eventKey) {
        root.browseTarget = eventKey;
        soundBrowserLoader.active = true;
        soundBrowserLoader.item.open();
    }

    LazyLoader {
        id: soundBrowserLoader

        active: false

        FileBrowserModal {
            browserTitle: I18n.tr("Select Sound File")
            browserIcon: "audio_file"
            browserType: "sound"
            fileExtensions: ["*.wav", "*.ogg", "*.oga", "*.mp3", "*.flac", "*.opus", "*.m4a"]

            onFileSelected: path => {
                if (root.browseTarget !== "")
                    AudioService.setCustomSound(root.browseTarget, Paths.strip(path));
                root.browseTarget = "";
            }
        }
    }
}
