pragma ComponentBehavior: Bound

import qs.Services
import qs.Common
import qs.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "HyprlandParser.js" as Parser

Item {
    id: root
    property var keybinds: ({ children: [] })
    property real spacing: 20
    property real titleSpacing: 7
    property real padding: 4
    implicitWidth: parent.width
    implicitHeight: parent.height

    // Process to read the config file
    Process {
        id: configReader
        command: ["cat", Quickshell.env("HOME") + "/.config/hypr/conf/keybindings/default.conf"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                var parsed = Parser.parse(text);
                root.keybinds = parsed;
            }
        }
    }

    // Excellent symbol explaination and source :
    // http://xahlee.info/comp/unicode_computing_symbols.html
    // https://www.nerdfonts.com/cheat-sheet
    property var macSymbolMap: ({
        "Ctrl": "󰘴",
        "Alt": "󰘵",
        "Shift": "󰘶",
        "Space": "󱁐",
        "Tab": "↹",
        "Equal": "󰇼",
        "Minus": "",
        "Print": "",
        "BackSpace": "󰭜",
        "Delete": "⌦",
        "Return": "󰌑",
        "Period": ".",
        "Escape": "⎋"
    })
    property var functionSymbolMap: ({
        "F1":  "󱊫",
        "F2":  "󱊬",
        "F3":  "󱊭",
        "F4":  "󱊮",
        "F5":  "󱊯",
        "F6":  "󱊰",
        "F7":  "󱊱",
        "F8":  "󱊲",
        "F9":  "󱊳",
        "F10": "󱊴",
        "F11": "󱊵",
        "F12": "󱊶",
    })

    property var mouseSymbolMap: ({
        "mouse_up": "󱕐",
        "mouse_down": "󱕑",
        "mouse:272": "L󰍽",
        "mouse:273": "R󰍽",
        "Scroll ↑/↓": "󱕒",
        "Page_↑/↓": "⇞/⇟",
    })

    property var keyBlacklist: ["Super_L"]
    property var keySubstitutions: Object.assign({
        "Super": "",
        "$mainMod": "", // Handle $mainMod variable
        "mouse_up": "Scroll ↓",    // ikr, weird
        "mouse_down": "Scroll ↑",  // trust me bro
        "mouse:272": "LMB",
        "mouse:273": "RMB",
        "mouse:275": "MouseBack",
        "Slash": "/",
        "Hash": "#",
        "Return": "Enter",
        // "Shift": "",
        "SUPER": "", // Handle uppercase SUPER from config
        "CTRL": "Ctrl",
        "SHIFT": "Shift",
        "ALT": "Alt",
        "KP_Enter": "Enter",
      },
      // !!Config.options.cheatsheet.superKey ? { "Super": Config.options.cheatsheet.superKey }: {},
      // Config.options.cheatsheet.useMacSymbol ? macSymbolMap : {},
      functionSymbolMap, // Config.options.cheatsheet.useFnSymbol ? functionSymbolMap : {},
      mouseSymbolMap, // Config.options.cheatsheet.useMouseSymbol ? mouseSymbolMap : {},
    )

    property string searchText: ""

    function forceFocus() {
        searchField.forceActiveFocus();
    }

    // Filter logic
    property var filteredKeybinds: {
        if (!keybinds.children) {
            return [];
        }
        
        if (searchText === "") return keybinds.children;
        
        var result = [];
        for (var i = 0; i < keybinds.children.length; i++) {
            var section = keybinds.children[i];
            // Check section name
            if (section.name.toLowerCase().includes(searchText.toLowerCase())) {
                result.push(section);
                continue;
            }
            // Check keybinds
            var matchingKeybinds = section.keybinds.filter(kb => 
                kb.key.toLowerCase().includes(searchText.toLowerCase()) || 
                kb.comment.toLowerCase().includes(searchText.toLowerCase()) ||
                (kb.action && kb.action.toLowerCase().includes(searchText.toLowerCase()))
            );
            
            if (matchingKeybinds.length > 0) {
                // Create a copy of section with filtered keybinds
                result.push({
                    name: section.name,
                    keybinds: matchingKeybinds
                });
            }
        }
        return result;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Search Bar
        DankTextField {
            id: searchField
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            Layout.margins: 10
            placeholderText: "Search keybinds..."
            onTextChanged: root.searchText = text
            
            cornerRadius: Theme.cornerRadius
            backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            normalBorderColor: Theme.outlineMedium
            focusedBorderColor: Theme.primary
            leftIconName: "search"
            showClearButton: true
            textColor: Theme.surfaceText
            font.pixelSize: Theme.fontSizeLarge
            
            focus: true
            Component.onCompleted: forceActiveFocus()
            onVisibleChanged: if (visible) forceActiveFocus()
        }

        // Scrollable Content
        ScrollView {
            id: keybindScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth // Prevent horizontal scroll if possible

            Flow {
                width: keybindScrollView.availableWidth
                spacing: root.spacing
                padding: 10
                
                Repeater {
                    model: filteredKeybinds // Use filtered keybinds directly
                    
                    delegate: Column { // Keybind sections
                        spacing: root.spacing
                        required property var modelData
                        
                        Item { // Section with real keybinds
                            id: keybindSection
                            implicitWidth: sectionColumn.implicitWidth
                            implicitHeight: sectionColumn.implicitHeight

                            Column {
                                id: sectionColumn
                                anchors.centerIn: parent
                                spacing: root.titleSpacing
                                
                                StyledText {
                                    id: sectionTitle
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fontSizeLarge
                                    }
                                    color: Theme.surfaceText
                                    text: modelData.name
                                }

                                GridLayout {
                                    id: keybindGrid
                                    columns: 2
                                    columnSpacing: 4
                                    rowSpacing: 4

                                    Repeater {
                                        model: {
                                            var result = [];
                                            if (!modelData || !modelData.keybinds) return result;
                                            
                                            for (var i = 0; i < modelData.keybinds.length; i++) {
                                                const keybind = modelData.keybinds[i];
                                                var mods = [...keybind.mods];

                                                result.push({
                                                    "type": "keys",
                                                    "mods": mods,
                                                    "key": keybind.key,
                                                });
                                                result.push({
                                                    "type": "comment",
                                                    "comment": keybind.comment,
                                                });
                                            }
                                            return result;
                                        }
                                        delegate: Item {
                                            required property var modelData
                                            implicitWidth: keybindLoader.implicitWidth
                                            implicitHeight: keybindLoader.implicitHeight

                                            Loader {
                                                id: keybindLoader
                                                property var itemModel: modelData
                                                sourceComponent: (modelData.type === "keys") ? keysComponent : commentComponent
                                            }

                                            Component {
                                                id: keysComponent
                                                Row {
                                                    property var modelData: keybindLoader.itemModel
                                                    spacing: 4
                                                    Repeater {
                                                        model: modelData.mods
                                                        delegate: KeyboardKey {
                                                            required property var modelData
                                                            key: keySubstitutions[modelData] || modelData
                                                            pixelSize: Theme.fontSizeSmall
                                                        }
                                                    }
                                                    StyledText {
                                                        id: keybindPlus
                                                        visible: !keyBlacklist.includes(modelData.key) && modelData.mods.length > 0
                                                        text: "+"
                                                        color: Theme.surfaceText
                                                    }
                                                    KeyboardKey {
                                                        id: keybindKey
                                                        visible: !keyBlacklist.includes(modelData.key)
                                                        key: keySubstitutions[modelData.key] || modelData.key
                                                        pixelSize: Theme.fontSizeSmall
                                                        textColor: Theme.surfaceText
                                                    }
                                                }
                                            }

                                            Component {
                                                id: commentComponent
                                                Item {
                                                    id: commentItem
                                                    property var modelData: keybindLoader.itemModel
                                                    implicitWidth: commentText.implicitWidth + 8 * 2
                                                    implicitHeight: commentText.implicitHeight

                                                    StyledText {
                                                        id: commentText
                                                        anchors.centerIn: parent
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        text: modelData.comment
                                                        color: Theme.surfaceText
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
