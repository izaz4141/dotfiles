import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: inputTab

    readonly property var kbLayoutOptions: ["us", "de", "fr", "gb", "it", "es", "se", "no", "dk", "fi", "pt", "br", "jp", "kr", "cn", "ru", "pl", "cz", "hu", "ro", "bg", "hr", "si", "tr", "ara", "he"]
    readonly property var kbLayoutLabels: ["English (US)", "German", "French", "British English", "Italian", "Spanish", "Swedish", "Norwegian", "Danish", "Finnish", "Portuguese", "Brazilian", "Japanese", "Korean", "Chinese", "Russian", "Polish", "Czech", "Hungarian", "Romanian", "Bulgarian", "Croatian", "Slovenian", "Turkish", "Arabic", "Hebrew"]
    readonly property var followMouseOptions: [0, 1, 2]
    readonly property var followMouseLabels: [I18n.tr("Off"), I18n.tr("On"), I18n.tr("Strict")]
    readonly property var sensitivityValues: [-1.0, -0.8, -0.6, -0.4, -0.2, 0, 0.2, 0.4, 0.6, 0.8, 1.0]
    readonly property var sensitivityLabels: ["-1.0", "-0.8", "-0.6", "-0.4", "-0.2", I18n.tr("0 (default)"), "+0.2", "+0.4", "+0.6", "+0.8", "+1.0"]

    property var cachedCursorThemes: SettingsData.availableCursorThemes

    function getInputValue(key, subKey, defaultVal) {
        var hypr = SettingsData.inputSettings?.hyprland;
        if (!hypr)
            return defaultVal;
        if (subKey) {
            var sub = hypr[subKey];
            if (!sub)
                return defaultVal;
            return sub[key] ?? defaultVal;
        }
        return hypr[key] ?? defaultVal;
    }

    function setInputValue(key, subKey, value) {
        var updated = JSON.parse(JSON.stringify(SettingsData.inputSettings || {}));
        if (!updated.hyprland)
            updated.hyprland = {};
        if (subKey) {
            if (!updated.hyprland[subKey])
                updated.hyprland[subKey] = {};
            updated.hyprland[subKey][key] = value;
        } else {
            updated.hyprland[key] = value;
        }
        SettingsData.set("inputSettings", updated);
    }

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
                width: parent.width
                iconName: "keyboard"
                title: I18n.tr("Keyboard", "input_settings_keyboard")
                settingKey: "inputKeyboard"

                SettingsDropdownRow {
                    tab: "input"
                    tags: ["keyboard", "layout", "language"]
                    settingKey: "kbLayout"
                    text: I18n.tr("Keyboard Layout")
                    description: I18n.tr("Keyboard layout for input")
                    currentValue: getInputValue("kb_layout", null, "us")
                    options: kbLayoutLabels
                    onValueChanged: value => {
                        var idx = kbLayoutLabels.indexOf(value);
                        if (idx >= 0)
                            setInputValue("kb_layout", null, kbLayoutOptions[idx]);
                    }
                }

                SettingsDropdownRow {
                    tab: "input"
                    tags: ["mouse", "follow", "focus"]
                    settingKey: "followMouse"
                    text: I18n.tr("Follow Mouse Focus")
                    description: I18n.tr("Window focus follows mouse movement")
                    currentValue: followMouseLabels[followMouseOptions.indexOf(getInputValue("follow_mouse", null, 1))]
                    options: followMouseLabels
                    onValueChanged: value => {
                        var idx = followMouseLabels.indexOf(value);
                        if (idx >= 0)
                            setInputValue("follow_mouse", null, followMouseOptions[idx]);
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "mouse"
                title: I18n.tr("Mouse", "input_settings_mouse")
                settingKey: "inputMouse"

                SettingsDropdownRow {
                    tab: "input"
                    tags: ["mouse", "sensitivity", "speed"]
                    settingKey: "mouseSensitivity"
                    text: I18n.tr("Sensitivity")
                    description: I18n.tr("Mouse sensitivity (-1.0 to +1.0)")
                    currentValue: {
                        var val = getInputValue("sensitivity", null, 0);
                        var idx = sensitivityValues.indexOf(val);
                        return idx >= 0 ? sensitivityLabels[idx] : "0 (default)";
                    }
                    options: sensitivityLabels
                    onValueChanged: value => {
                        var idx = sensitivityLabels.indexOf(value);
                        if (idx >= 0)
                            setInputValue("sensitivity", null, sensitivityValues[idx]);
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "touch_app"
                title: I18n.tr("Touchpad", "input_settings_touchpad")
                settingKey: "inputTouchpad"

                SettingsToggleRow {
                    tab: "input"
                    tags: ["touchpad", "natural", "scroll"]
                    settingKey: "touchpadNaturalScroll"
                    text: I18n.tr("Natural Scrolling")
                    description: I18n.tr("Scroll direction matches finger movement")
                    checked: getInputValue("natural_scroll", "touchpad", true)
                    onToggled: checked => setInputValue("natural_scroll", "touchpad", checked)
                }

                SettingsToggleRow {
                    tab: "input"
                    tags: ["touchpad", "tap", "click"]
                    settingKey: "touchpadTapToClick"
                    text: I18n.tr("Tap to Click")
                    description: I18n.tr("Tap touchpad to click")
                    checked: getInputValue("tap_to_click", "touchpad", true)
                    onToggled: checked => setInputValue("tap_to_click", "touchpad", checked)
                }

                SettingsToggleRow {
                    tab: "input"
                    tags: ["touchpad", "disable", "typing"]
                    settingKey: "touchpadDisableWhileTyping"
                    text: I18n.tr("Disable While Typing")
                    description: I18n.tr("Ignore touchpad input while typing on keyboard")
                    checked: getInputValue("disable_while_typing", "touchpad", false)
                    onToggled: checked => setInputValue("disable_while_typing", "touchpad", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "format_paint"
                title: I18n.tr("Cursor", "input_settings_cursor")
                settingKey: "inputCursor"

                SettingsDropdownRow {
                    tab: "input"
                    tags: ["cursor", "mouse", "pointer", "theme"]
                    settingKey: "inputCursorTheme"
                    text: I18n.tr("Cursor Theme")
                    description: I18n.tr("Mouse pointer appearance")
                    currentValue: SettingsData.cursorSettings.theme
                    enableFuzzySearch: true
                    popupWidthOffset: 100
                    maxPopupHeight: 236
                    options: cachedCursorThemes
                    onValueChanged: value => {
                        SettingsData.setCursorTheme(value);
                    }
                }

                SettingsSliderRow {
                    tab: "input"
                    tags: ["cursor", "mouse", "pointer", "size"]
                    settingKey: "inputCursorSize"
                    text: I18n.tr("Cursor Size")
                    description: I18n.tr("Mouse pointer size in pixels")
                    value: SettingsData.cursorSettings.size
                    minimum: 12
                    maximum: 128
                    unit: "px"
                    defaultValue: 24
                    onSliderValueChanged: newValue => SettingsData.setCursorSize(newValue)
                }

                SettingsToggleRow {
                    tab: "input"
                    tags: ["cursor", "hide", "typing"]
                    settingKey: "inputCursorHideWhenTyping"
                    text: I18n.tr("Hide When Typing")
                    description: I18n.tr("Hide cursor when pressing keyboard keys")
                    visible: CompositorService.isNiri || CompositorService.isHyprland
                    checked: {
                        if (CompositorService.isNiri)
                            return SettingsData.cursorSettings.niri?.hideWhenTyping || false;
                        if (CompositorService.isHyprland)
                            return SettingsData.cursorSettings.hyprland?.hideOnKeyPress || false;
                        return false;
                    }
                    onToggled: checked => {
                        const updated = JSON.parse(JSON.stringify(SettingsData.cursorSettings));
                        if (CompositorService.isNiri) {
                            if (!updated.niri)
                                updated.niri = {};
                            updated.niri.hideWhenTyping = checked;
                        } else if (CompositorService.isHyprland) {
                            if (!updated.hyprland)
                                updated.hyprland = {};
                            updated.hyprland.hideOnKeyPress = checked;
                        }
                        SettingsData.set("cursorSettings", updated);
                    }
                }

                SettingsToggleRow {
                    tab: "input"
                    tags: ["cursor", "hide", "touch"]
                    settingKey: "inputCursorHideOnTouch"
                    text: I18n.tr("Hide on Touch")
                    description: I18n.tr("Hide cursor when using touch input")
                    visible: CompositorService.isHyprland
                    checked: SettingsData.cursorSettings.hyprland?.hideOnTouch || false
                    onToggled: checked => {
                        const updated = JSON.parse(JSON.stringify(SettingsData.cursorSettings));
                        if (!updated.hyprland)
                            updated.hyprland = {};
                        updated.hyprland.hideOnTouch = checked;
                        SettingsData.set("cursorSettings", updated);
                    }
                }

                SettingsSliderRow {
                    tab: "input"
                    tags: ["cursor", "hide", "timeout", "inactive"]
                    settingKey: "inputCursorHideAfterInactive"
                    text: I18n.tr("Auto-Hide Timeout")
                    description: I18n.tr("Hide cursor after inactivity (0 = disabled)")
                    value: {
                        if (CompositorService.isNiri)
                            return SettingsData.cursorSettings.niri?.hideAfterInactiveMs || 0;
                        if (CompositorService.isHyprland)
                            return SettingsData.cursorSettings.hyprland?.inactiveTimeout || 0;
                        if (CompositorService.isDwl)
                            return SettingsData.cursorSettings.dwl?.cursorHideTimeout || 0;
                        return 0;
                    }
                    minimum: 0
                    maximum: CompositorService.isNiri ? 5000 : 10
                    unit: CompositorService.isNiri ? "ms" : "s"
                    defaultValue: 0
                    onSliderValueChanged: newValue => {
                        const updated = JSON.parse(JSON.stringify(SettingsData.cursorSettings));
                        if (CompositorService.isNiri) {
                            if (!updated.niri)
                                updated.niri = {};
                            updated.niri.hideAfterInactiveMs = newValue;
                        } else if (CompositorService.isHyprland) {
                            if (!updated.hyprland)
                                updated.hyprland = {};
                            updated.hyprland.inactiveTimeout = newValue;
                        } else if (CompositorService.isDwl) {
                            if (!updated.dwl)
                                updated.dwl = {};
                            updated.dwl.cursorHideTimeout = newValue;
                        }
                        SettingsData.set("cursorSettings", updated);
                    }
                }
            }
        }
    }
}
