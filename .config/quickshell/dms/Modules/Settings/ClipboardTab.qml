import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    property var config: ({})
    property bool configLoaded: false
    property bool configError: false
    property bool saving: false
    property bool configExists: false
    property string configPath: ""

    readonly property var maxItemsOptions: [
        {
            text: "100",
            value: 100
        },
        {
            text: "250",
            value: 250
        },
        {
            text: "500",
            value: 500
        },
        {
            text: "750",
            value: 750
        },
        {
            text: "1,000",
            value: 1000
        },
        {
            text: "2,500",
            value: 2500
        },
        {
            text: "5,000",
            value: 5000
        }
    ]

    readonly property var maxStoreSizeOptions: [
        {
            text: "1 MB",
            value: "1MB"
        },
        {
            text: "2 MB",
            value: "2MB"
        },
        {
            text: "5 MB",
            value: "5MB"
        },
        {
            text: "10 MB",
            value: "10MB"
        },
        {
            text: "20 MB",
            value: "20MB"
        },
        {
            text: "50 MB",
            value: "50MB"
        },
        {
            text: "100 MB",
            value: "100MB"
        }
    ]

    readonly property var previewWidthOptions: [
        {
            text: "50",
            value: 50
        },
        {
            text: "100",
            value: 100
        },
        {
            text: "200",
            value: 200
        },
        {
            text: "500",
            value: 500
        }
    ]

    readonly property var dedupeOptions: [
        {
            text: "50",
            value: 50
        },
        {
            text: "100",
            value: 100
        },
        {
            text: "200",
            value: 200
        },
        {
            text: "500",
            value: 500
        }
    ]

    function configPathFromEnv() {
        return Quickshell.env.CIPHIST_CONFIG_PATH
            || (Quickshell.env.XDG_CONFIG_HOME || (Quickshell.env.HOME + "/.config")) + "/cliphist/config"
    }

    function parseConfig(text) {
        const out = {}
        if (!text)
            return out
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const raw = lines[i].trim()
            if (!raw || raw.startsWith("#"))
                continue
            const spaceIdx = raw.indexOf(" ")
            if (spaceIdx < 0)
                continue
            const key = raw.substring(0, spaceIdx).trim()
            const value = raw.substring(spaceIdx + 1).trim()
            if (key.length > 0)
                out[key] = value
        }
        return out
    }

    function serializeConfig(obj) {
        const keys = Object.keys(obj)
        if (keys.length === 0)
            return ""
        let out = ""
        for (let i = 0; i < keys.length; i++) {
            out += keys[i] + " " + obj[keys[i]] + "\n"
        }
        return out
    }

    function loadConfig() {
        configLoaded = false
        configError = false
        configPath = configPathFromEnv()
        configFile.path = Qt.resolvedUrl("file://" + configPath)
        configFile.reload()
    }

    function saveConfig(key, value) {
        if (saving)
            return
        const next = {}
        for (const k in config)
            next[k] = config[k]
        next[key] = String(value)
        saving = true
        config = next
        configFile.setText(serializeConfig(next))
    }

    FileView {
        id: configFile
        onLoaded: {
            root.config = root.parseConfig(text())
            root.configLoaded = true
            root.configExists = true
        }
        onLoadFailed: error => {
            if (error === 2 || (error && error.toString().indexOf("No such file") >= 0)) {
                root.config = {}
                root.configLoaded = true
                root.configExists = false
            } else {
                root.configError = true
                root.configLoaded = true
            }
        }
    }

    Component.onCompleted: loadConfig()

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

            Rectangle {
                width: parent.width
                height: warningContent.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                visible: !root.configLoaded || root.configError

                Row {
                    id: warningContent
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
                        font.pixelSize: Theme.fontSizeSmall
                        text: root.configError ? I18n.tr("Failed to load clipboard configuration.") : I18n.tr("Loading clipboard configuration...")
                        wrapMode: Text.WordWrap
                        width: parent.width - Theme.iconSizeSmall - Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            SettingsCard {
                tab: "clipboard"
                tags: ["clipboard", "history", "limit"]
                title: I18n.tr("History Settings")
                iconName: "history"
                visible: root.configLoaded && !root.configError

                SettingsDropdownRow {
                    id: maxItemsDropdown
                    tab: "clipboard"
                    tags: ["clipboard", "history", "max", "limit"]
                    settingKey: "maxItems"
                    text: I18n.tr("Maximum History")
                    description: I18n.tr("Maximum number of clipboard entries to keep")
                    options: root.maxItemsOptions.map(opt => opt.text)

                    Component.onCompleted: {
                        currentValue = String(parseInt(root.config["max-items"]) || 750)
                    }

                    onValueChanged: value => {
                        for (let opt of root.maxItemsOptions) {
                            if (opt.text === value) {
                                root.saveConfig("max-items", opt.value)
                                return
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onConfigChanged() {
                            maxItemsDropdown.currentValue = String(parseInt(root.config["max-items"]) || 750)
                        }
                    }
                }

                SettingsDropdownRow {
                    id: maxStoreSizeDropdown
                    tab: "clipboard"
                    tags: ["clipboard", "entry", "size", "limit"]
                    settingKey: "maxStoreSize"
                    text: I18n.tr("Maximum Store Size")
                    description: I18n.tr("Maximum total disk size of the clipboard database")
                    options: root.maxStoreSizeOptions.map(opt => opt.text)

                    Component.onCompleted: {
                        currentValue = root.config["max-store-size"] || "5MB"
                    }

                    onValueChanged: value => {
                        for (let opt of root.maxStoreSizeOptions) {
                            if (opt.text === value) {
                                root.saveConfig("max-store-size", opt.value)
                                return
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onConfigChanged() {
                            maxStoreSizeDropdown.currentValue = root.config["max-store-size"] || "5MB"
                        }
                    }
                }

                SettingsDropdownRow {
                    id: previewWidthDropdown
                    tab: "clipboard"
                    tags: ["clipboard", "preview", "width"]
                    settingKey: "previewWidth"
                    text: I18n.tr("List Preview Width")
                    description: I18n.tr("How many characters of each entry to show in the list. Higher = more readable, lower = more compact.")
                    options: root.previewWidthOptions.map(opt => opt.text)

                    Component.onCompleted: {
                        currentValue = String(parseInt(root.config["preview-width"]) || 100)
                    }

                    onValueChanged: value => {
                        for (let opt of root.previewWidthOptions) {
                            if (opt.text === value) {
                                root.saveConfig("preview-width", opt.value)
                                return
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onConfigChanged() {
                            previewWidthDropdown.currentValue = String(parseInt(root.config["preview-width"]) || 100)
                        }
                    }
                }
            }

            SettingsCard {
                tab: "clipboard"
                tags: ["clipboard", "behavior"]
                title: I18n.tr("Behavior")
                iconName: "settings"
                visible: root.configLoaded && !root.configError

                SettingsToggleRow {
                    tab: "clipboard"
                    tags: ["clipboard", "enter", "paste", "behavior"]
                    settingKey: "clipboardEnterToPaste"
                    text: I18n.tr("Enter to Paste")
                    description: I18n.tr("Press Enter to paste, Shift+Enter to copy", "Clipboard behavior setting description")
                    checked: SettingsData.clipboardEnterToPaste
                    onToggled: checked => SettingsData.set("clipboardEnterToPaste", checked)
                }
            }

            SettingsCard {
                tab: "clipboard"
                tags: ["clipboard", "advanced"]
                title: I18n.tr("Advanced")
                iconName: "tune"
                collapsible: true
                expanded: false
                visible: root.configLoaded && !root.configError

                SettingsDropdownRow {
                    id: minStoreLengthDropdown
                    tab: "clipboard"
                    tags: ["clipboard", "min", "length"]
                    settingKey: "minStoreLength"
                    text: I18n.tr("Minimum Store Length")
                    description: I18n.tr("Minimum number of characters before an entry is stored")
                    options: ["0", "1", "3", "5", "10"]

                    Component.onCompleted: {
                        currentValue = root.config["min-store-length"] || "0"
                    }

                    onValueChanged: value => {
                        root.saveConfig("min-store-length", value)
                    }

                    Connections {
                        target: root
                        function onConfigChanged() {
                            minStoreLengthDropdown.currentValue = root.config["min-store-length"] || "0"
                        }
                    }
                }

                SettingsDropdownRow {
                    id: dedupeDropdown
                    tab: "clipboard"
                    tags: ["clipboard", "dedupe"]
                    settingKey: "maxDedupeSearch"
                    text: I18n.tr("Deduplication Search Depth")
                    description: I18n.tr("How many recent items to scan when looking for duplicates")
                    options: root.dedupeOptions.map(opt => opt.text)

                    Component.onCompleted: {
                        currentValue = String(parseInt(root.config["max-dedupe-search"]) || 100)
                    }

                    onValueChanged: value => {
                        for (let opt of root.dedupeOptions) {
                            if (opt.text === value) {
                                root.saveConfig("max-dedupe-search", opt.value)
                                return
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onConfigChanged() {
                            dedupeDropdown.currentValue = String(parseInt(root.config["max-dedupe-search"]) || 100)
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: configInfo.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                visible: root.configLoaded && !root.configError

                Row {
                    id: configInfo
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "info"
                        size: Theme.iconSizeSmall
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        font.pixelSize: Theme.fontSizeSmall
                        text: I18n.tr("Configuration file: ") + root.configPath
                        wrapMode: Text.Wrap
                        width: parent.width - Theme.iconSizeSmall - Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
