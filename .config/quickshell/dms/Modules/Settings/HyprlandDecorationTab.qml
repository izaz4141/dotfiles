pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    property var categoryOrder: ["Window styling", "Blur", "Shadow", "Gaps", "Misc", "Touchpad"]
    property var categoryIcons: ({
        "Window styling": "style",
        "Blur": "blur_on",
        "Shadow": "opacity",
        "Gaps": "space_bar",
        "Misc": "tune",
        "Touchpad": "touch_app"
    })

    property var decorationSections: []

    function rebuildSections() {
        root.decorationSections = root.computeSections();
    }

    function rangeSpec(name, value) {
        if (name === "windowOpacity")
            return { min: 0, max: 100, step: 1, unit: "", float: true };
        if (name === "touchpadScrollFactor")
            return { min: 0, max: 200, step: 5, unit: "", float: true };
        if (typeof value === "number" && Math.round(value) !== value)
            return { min: 0, max: 200, step: 5, unit: "", float: true };
        var table = {
            "blurSize": [0, 20, 1, "px"],
            "blurPasses": [1, 8, 1, "pass"],
            "shadowRange": [0, 200, 1, "px"],
            "shadowRenderPower": [1, 10, 1, "power"],
            "workspaceGaps": [0, 100, 1, "px"],
            "windowGapsIn": [0, 100, 1, "px"],
            "windowGapsOut": [0, 100, 1, "px"],
            "singleWindowGapsOut": [0, 100, 1, "px"],
            "windowRounding": [0, 50, 1, "px"],
            "windowBorderSize": [0, 10, 1, "px"],
            "cursorSize": [12, 64, 2, "px"],
            "volumeStep": [1, 50, 1, "%"],
            "volumeMax": [1, 200, 1, "%"],
            "gestureFingers": [2, 8, 1, ""],
            "workspaceSwipeFingers": [2, 8, 1, ""],
            "gestureFingersMore": [2, 8, 1, ""]
        };
        var spec = table[name];
        if (spec)
            return { min: spec[0], max: spec[1], step: spec[2], unit: spec[3], float: false };
        return { min: 0, max: 200, step: 1, unit: "", float: false };
    }

    Connections {
        target: HyprlandService

        function onKeybindVariablesLoaded() {
            root.rebuildSections();
        }
    }

    function computeSections() {
        var vars = HyprlandService.keybindVariables;
        var out = [];
        for (var c = 0; c < categoryOrder.length; c++) {
            var category = categoryOrder[c];
            var items = [];
            for (var i = 0; i < vars.length; i++) {
                if (vars[i].category === category && !String(vars[i].name).startsWith("kb"))
                    items.push(vars[i]);
            }
            if (items.length > 0)
                out.push({
                    "name": category,
                    "items": items,
                    "icon": categoryIcons[category] || "tune"
                });
        }
        return out;
    }

    function humanize(name) {
        if (!name)
            return "";
        return String(name)
            .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
            .replace(/^[a-z]/, c => c.toUpperCase());
    }

    Component.onCompleted: {
        if (!HyprlandService.keybindVariablesReady)
            HyprlandService.refreshKeybindVariables();
        rebuildSections();
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
            spacing: Theme.spacingM

            SettingsCard {
                tab: "hyprland"
                tags: ["hyprland", "hypr", "decoration", "variables"]
                title: I18n.tr("Hyprland Decoration")
                iconName: "palette"
                visible: !HyprlandService.keybindVariablesReady || root.decorationSections.length === 0

                StyledText {
                    width: parent.width
                    text: HyprlandService.keybindVariablesLoading ? I18n.tr("Loading Hyprland variables...") : I18n.tr("Hyprland variables are not available.")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    wrapMode: Text.Wrap
                }
            }

            Repeater {
                model: root.decorationSections

                delegate: SettingsCard {
                    required property var modelData
                    tab: "hyprland"
                    tags: ["hyprland", "hypr", "decoration"]
                    title: modelData.name
                    iconName: modelData.icon

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: modelData.items

                            delegate: Row {
                                id: valueRow
                                required property var modelData
                                width: parent.width
                                height: Math.max(settingName.implicitHeight, 48)
                                spacing: Theme.spacingM

                                StyledText {
                                    id: settingName
                                    width: 220
                                    height: implicitHeight
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.humanize(valueRow.modelData.name)
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignLeft
                                }

                                Item {
                                    id: valueEditor
                                    readonly property var setting: valueRow.modelData
                                    readonly property bool isBoolean: typeof setting.value === "boolean"
                                    readonly property bool isNumber: typeof setting.value === "number"
                                    readonly property bool isString: typeof setting.value === "string" || (!isBoolean && !isNumber)
                                    property var spec: root.rangeSpec(setting.name, setting.value)
                                    property int sliderInitial: {
                                        var v = isNumber ? Number(setting.value) : 0;
                                        if (spec.float)
                                            v = v * 100;
                                        v = Math.max(spec.min, Math.min(spec.max, v));
                                        return Math.round(v);
                                    }

                                    width: parent.width - settingName.width - parent.spacing
                                    height: valueRow.height
                                    anchors.verticalCenter: parent.verticalCenter

                                    function writeNumber() {
                                        var v;
                                        if (valueEditor.spec.float)
                                            v = numberSlider.value / 100;
                                        else
                                            v = numberSlider.value;
                                        if (v !== valueEditor.setting.value)
                                            HyprlandService.setVariable(valueEditor.setting.name, v);
                                    }

                                    function writeString() {
                                        if (stringEditor.text.trim() === "") {
                                            stringEditor.text = valueEditor.setting.value != null ? String(valueEditor.setting.value) : "";
                                            return;
                                        }
                                        if (valueEditor.setting.value != null && String(valueEditor.setting.value) === stringEditor.text.trim())
                                            return;
                                        HyprlandService.setVariable(valueEditor.setting.name, stringEditor.text.trim());
                                    }

                                    function revertString() {
                                        stringEditor.text = valueEditor.setting.value != null ? String(valueEditor.setting.value) : "";
                                    }

                                    Item {
                                        id: escapeRevertTarget

                                        Keys.onEscapePressed: event => {
                                            event.accepted = true;
                                            valueEditor.revertString();
                                        }
                                    }

                                    Timer {
                                        id: numberWriteTimer
                                        interval: 400
                                        onTriggered: valueEditor.writeNumber()
                                    }

                                    DankToggle {
                                        id: booleanToggle
                                        visible: valueEditor.isBoolean
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: valueEditor.setting.value === true
                                        enabled: HyprlandService.keybindVariablesReady

                                        onToggled: checked => {
                                            booleanToggle.checked = checked;
                                            HyprlandService.setVariable(valueEditor.setting.name, checked);
                                        }
                                    }

                                    Row {
                                        visible: valueEditor.isNumber
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 48
                                        spacing: Theme.spacingM

                                        DankSlider {
                                            id: numberSlider
                                            width: parent.width - valueLabel.width - parent.spacing
                                            anchors.verticalCenter: parent.verticalCenter
                                            minimum: valueEditor.spec.min
                                            maximum: valueEditor.spec.max
                                            step: valueEditor.spec.step
                                            showValue: false
                                            enabled: HyprlandService.keybindVariablesReady
                                            value: valueEditor.sliderInitial

                                            onSliderValueChanged: numberWriteTimer.restart()

                                            onSliderDragFinished: {
                                                numberWriteTimer.stop();
                                                valueEditor.writeNumber();
                                            }
                                        }

                                        StyledText {
                                            id: valueLabel
                                            width: 64
                                            height: implicitHeight
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: valueEditor.spec.float ? (numberSlider.value / 100).toFixed(2) : (numberSlider.value + valueEditor.spec.unit)
                                            horizontalAlignment: Text.AlignRight
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                        }
                                    }

                                    DankTextField {
                                        id: stringEditor
                                        visible: valueEditor.isString
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: Math.round(Theme.fontSizeMedium * 2)
                                        text: valueEditor.setting.value != null ? String(valueEditor.setting.value) : ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                        normalBorderColor: Theme.outlineMedium
                                        focusedBorderColor: Theme.primary
                                        enabled: HyprlandService.keybindVariablesReady
                                        keyForwardTargets: [escapeRevertTarget]

                                        onAccepted: valueEditor.writeString()

                                        onEditingFinished: valueEditor.writeString()
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