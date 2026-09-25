pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import "../../Common/KeyUtils.js" as KeyUtils

Item {
    id: root

    property string searchText: ""
    property var sections: root.buildSections(root.searchText)
    property var appDefaultsList: root.buildAppDefaults()

    property var newKeyCombos: []
    property string newLuaCode: ""
    property string newDesc: ""
    property string newVarName: ""
    property string newCategory: ""
    property string newCustomCategoryName: ""
    property bool newCustomCategory: false
    property var newFlags: []
    property bool recordingKey: false
    property bool dialogVisible: false
    property bool _manualKeyEdit: false
    property int _editingComboIndex: -1
    property var _captureMods: ({})
    property var _captureKeys: []
    property string _pendingCombo: ""
    property var _shortcutInhibitor: null
    property var editingBind: null
    property string _editingVarName: ""
    property string _preloadFlagsRaw: ""
    property var _editLiteralKeys: []
    property string saveError: ""
    readonly property bool _isEditing: root.editingBind !== null
    readonly property bool _editPreservesRaw: root._isEditing && root._preloadFlagsRaw.trim() !== ""
    property bool _showDeleteConfirm: false
    readonly property var flagOptions: ["locked", "mouse", "release", "repeating"]
    readonly property var categoryOptions: root.buildCategoryOptions()
    readonly property string newCategoryLabel: I18n.tr("New category…")
    readonly property string _effectiveCategory: root.newCustomCategory ? root.newCustomCategoryName.trim() : root.newCategory
    readonly property bool _canAdd: root.newKeyCombos.some(c => c && String(c).trim() !== "") && root.newLuaCode.trim() !== "" && root.newDesc.trim() !== "" && root._effectiveCategory !== ""
    readonly property string _previewVarName: {
        var words = String(newDesc || "").match(/[A-Za-z0-9]+/g) || [];
        var camel = words.map(function(w, i) { return i === 0 ? w.toLowerCase() : (w[0].toUpperCase() + w.slice(1).toLowerCase()); }).join("");
        if (!camel || camel.length < 2) camel = "kbShortcut";
        else camel = "kb" + camel[0].toUpperCase() + camel.slice(1);
        return camel;
    }

    property var _dragBind: null
    property int _dragStmtIndex: -1
    property string _dragSectionName: ""
    property int _dragFromIndex: -1
    property int _dropIndex: -1
    property real _dragCursorX: 0
    property real _dragCursorY: 0
    readonly property bool _dragging: root._dragBind !== null

    readonly property var collisionGroups: root.computeCollisionGroups()

    function computeCollisionGroups() {
        const result = KeyUtils.computeEditorCollisions(HyprlandService.keybindEditorSections);
        const groups = [];
        for (const combo in result.comboMap) {
            const refs = result.comboMap[combo];
            if (refs.length < 2)
                continue;
            groups.push({
                "combo": combo,
                "display": result.comboDisplay[combo] || combo.toUpperCase(),
                "binds": refs
            });
        }
        groups.sort((a, b) => a.combo.localeCompare(b.combo));
        return groups;
    }

    function collideBindsFor(stmtIndex) {
        const out = [];
        for (let g = 0; g < root.collisionGroups.length; g++) {
            const binds = root.collisionGroups[g].binds;
            let current = null;
            for (let i = 0; i < binds.length; i++) {
                if (binds[i].stmtIndex === stmtIndex) {
                    current = binds[i];
                    break;
                }
            }
            if (!current)
                continue;
            for (let i = 0; i < binds.length; i++) {
                if (binds[i].stmtIndex === stmtIndex)
                    continue;
                const label = binds[i].desc || binds[i].actionText || (binds[i].section || "");
                if (out.indexOf(label) === -1)
                    out.push(label);
            }
        }
        return out;
    }

    function collisionLabelText(group) {
        const parts = [];
        for (let i = 0; i < group.binds.length; i++) {
            const b = group.binds[i];
            const name = b.desc || b.actionText || I18n.tr("(untitled)");
            parts.push(name + " (" + b.section + ")");
        }
        return parts.join(" & ");
    }

    function beginBindDrag(bind, sectionName, fromIndex) {
        if (!bind || !bind.editable) {
            ToastService.showWarning(I18n.tr("This shortcut can't be reordered.", "Reorder restriction"));
            return;
        }
        root._dragBind = bind;
        root._dragStmtIndex = bind.stmtIndex;
        root._dragSectionName = sectionName;
        root._dragFromIndex = fromIndex;
        root._dropIndex = fromIndex;
    }

    function updateBindDrag(mouseArea, boundColumn, repeater, mouseX, mouseY) {
        if (!root._dragging)
            return;
        if (boundColumn) {
            const local = mouseArea.mapToItem(boundColumn, mouseX, mouseY);
            let idx = repeater.count;
            for (let i = 0; i < repeater.count; i++) {
                const it = repeater.itemAt(i);
                if (!it)
                    break;
                if (local.y < it.y + it.height / 2) {
                    idx = i;
                    break;
                }
            }
            root._dropIndex = idx;
        }
        const mapped = mouseArea.mapToItem(root, mouseX, mouseY);
        root._dragCursorX = mapped.x;
        root._dragCursorY = mapped.y;
    }

    function finishBindDrag() {
        if (!root._dragging)
            return;
        const dropIdx = root._dropIndex;
        const stmtIndex = root._dragStmtIndex;
        const fromIdx = root._dragFromIndex;
        const secName = root._dragSectionName;
        root._dragBind = null;
        root._dragStmtIndex = -1;
        root._dragSectionName = "";
        root._dragFromIndex = -1;
        root._dropIndex = -1;
        if (dropIdx < 0 || dropIdx === fromIdx)
            return;
        let binds = [];
        for (let s = 0; s < root.sections.length; s++) {
            if (root.sections[s].name === secName) {
                binds = root.sections[s].binds;
                break;
            }
        }
        const beforeStmtIndex = dropIdx < binds.length ? binds[dropIdx].stmtIndex : -1;
        HyprlandService.reorderKeybind(stmtIndex, beforeStmtIndex, ok => {
            if (!ok)
                ToastService.showError(I18n.tr("Failed to reorder the shortcut.", "Keybind reorder failure"));
        });
    }

    function matches(bind, filter) {
        var f = String(filter || "").trim().toLowerCase();
        if (!f)
            return true;
        if (String(bind.desc || "").toLowerCase().includes(f))
            return true;
        if (String(bind.actionText || "").toLowerCase().includes(f))
            return true;
        for (var i = 0; i < bind.keys.length; i++) {
            if (String(bind.keys[i].combo || "").toLowerCase().includes(f))
                return true;
        }
        return false;
    }

    function buildSections(filter) {
        var out = [];
        var secs = HyprlandService.keybindEditorSections;
        if (!secs || !secs.length)
            return out;
        for (var s = 0; s < secs.length; s++) {
            var binds = secs[s].binds || [];
            var matched = [];
            for (var b = 0; b < binds.length; b++) {
                if (root.matches(binds[b], filter))
                    matched.push(binds[b]);
            }
            if (!matched.length)
                continue;
            out.push({
                "name": secs[s].name,
                "icon": root.iconForSection(secs[s].name),
                "binds": matched
            });
        }
        return out;
    }

    function iconForSection(name) {
        const map = {
            "Apps": "apps",
            "Launcher": "search",
            "Clipboard and emoji picker": "content_paste",
            "Media": "music_note",
            "Volume": "volume_up",
            "Brightness": "brightness_6",
            "Misc": "tune",
            "Testing": "bug_report",
            "Utilities": "build",
            "System": "settings"
        };
        return map[name] || "keyboard";
    }

    function buildAppDefaults() {
        var out = [];
        var vars = HyprlandService.keybindVariables || [];
        for (var i = 0; i < vars.length; i++) {
            if (String(vars[i].category || "") === "Apps" && !String(vars[i].name || "").startsWith("kb"))
                out.push({
                    "name": vars[i].name,
                    "value": vars[i].value
                });
        }
        return out;
    }

    function humanize(name) {
        var s = String(name || "").replace(/([A-Z])/g, " $1").trim();
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    function varNameFromToken(token) {
        var s = String(token || "");
        if (s.startsWith("vars."))
            return s.slice(5);
        var m = s.match(/vars\.(\w+)/);
        return m ? m[1] : "";
    }

    function onEditVariable(bind, token, combo) {
        if (!combo)
            return;
        var name = root.varNameFromToken(token);
        if (name)
            HyprlandService.setVariable(name, combo);
    }

    function buildCategoryOptions() {
        var out = [];
        var secs = HyprlandService.keybindEditorSections || [];
        for (var i = 0; i < secs.length; i++)
            out.push(secs[i].name);
        return out;
    }

    function modifierClassFromKey(key) {
        switch (key) {
        case Qt.Key_Control: return "CTRL";
        case Qt.Key_Shift: return "SHIFT";
        case Qt.Key_Alt: return "ALT";
        case Qt.Key_Meta:
        case Qt.Key_Super_L:
        case Qt.Key_Super_R:
        case Qt.Key_Hyper_L:
        case Qt.Key_Hyper_R:
            return "SUPER";
        }
        return "";
    }

    function pendingComboPreview() {
        const mods = [];
        if (root._captureMods.SUPER) mods.push("SUPER");
        if (root._captureMods.CTRL) mods.push("CTRL");
        if (root._captureMods.ALT) mods.push("ALT");
        if (root._captureMods.SHIFT) mods.push("SHIFT");
        return mods.concat(root._captureKeys).join(" + ");
    }

    function ensureComboTarget() {
        if (root._editingComboIndex >= 0)
            return;
        if (root.newKeyCombos.length === 0)
            root.newKeyCombos = [""];
        root._editingComboIndex = 0;
    }

    function selectComboForEdit(index) {
        if (index < 0 || index >= root.newKeyCombos.length)
            return;
        root.stopKeyRecording();
        root._manualKeyEdit = false;
        root._editingComboIndex = index;
    }

    function addNewCombo() {
        root.stopKeyRecording();
        const arr = root.newKeyCombos.slice();
        arr.push("");
        root.newKeyCombos = arr;
        root._manualKeyEdit = false;
        root._editingComboIndex = arr.length - 1;
        root.startKeyRecording(root._editingComboIndex);
    }

    function removeCombo(index) {
        if (index < 0 || index >= root.newKeyCombos.length)
            return;
        const arr = root.newKeyCombos.slice();
        arr.splice(index, 1);
        root.newKeyCombos = arr;
        if (root._editingComboIndex === index)
            root.stopKeyRecording();
        else if (root._editingComboIndex > index)
            root._editingComboIndex--;
        root._pendingCombo = root.newKeyCombos[root._editingComboIndex] || "";
    }

    function _commitRecordedCombo() {
        if (root._editingComboIndex < 0)
            return;
        const arr = root.newKeyCombos.slice();
        while (arr.length <= root._editingComboIndex)
            arr.push("");
        arr[root._editingComboIndex] = root._pendingCombo;
        root.newKeyCombos = arr;
    }

    function startKeyRecording(index) {
        const target = index !== undefined && index >= 0 ? index : root._editingComboIndex;
        if (target < 0)
            return;
        root._editingComboIndex = target;
        root._destroyShortcutInhibitor();
        root._manualKeyEdit = false;
        root._captureMods = {};
        root._captureKeys = [];
        root._pendingCombo = root.newKeyCombos[target] || "";
        root.recordingKey = true;
        root._createShortcutInhibitor();
        recordingScope.forceActiveFocus();
    }

    function stopKeyRecording() {
        root.recordingKey = false;
        root._destroyShortcutInhibitor();
        root._captureMods = {};
        root._captureKeys = [];
        root._pendingCombo = root._editingComboIndex >= 0 && root._editingComboIndex < root.newKeyCombos.length ? root.newKeyCombos[root._editingComboIndex] || "" : "";
    }

    function keyRecorderDown(event) {
        if (!root.recordingKey)
            return;
        event.accepted = true;
        if (event.key === Qt.Key_Escape) {
            root.stopKeyRecording();
            return;
        }
        const modClass = root.modifierClassFromKey(event.key);
        if (modClass) {
            root._captureMods[modClass] = true;
            root._pendingCombo = root.pendingComboPreview();
            return;
        }
        const name = KeyUtils.luaKeyNameFromEvent(event);
        if (name && root._captureKeys.indexOf(name) === -1) {
            root._captureKeys.push(name);
            root._pendingCombo = root.pendingComboPreview();
        }
    }

    function keyRecorderUp(event) {
        if (!root.recordingKey)
            return;
        event.accepted = true;
        if (root._captureKeys.length > 0)
            return;
        const modClass = root.modifierClassFromKey(event.key);
        if (modClass) {
            delete root._captureMods[modClass];
            root._pendingCombo = root.pendingComboPreview();
        }
    }

    function confirmRecording() {
        if (!root.recordingKey)
            return;
        if (String(root._pendingCombo || "").trim() === "")
            return;
        root._commitRecordedCombo();
        root.stopKeyRecording();
    }

    function toggleManualKeyEdit() {
        root.ensureComboTarget();
        root.stopKeyRecording();
        root._manualKeyEdit = true;
        keyField.forceActiveFocus();
    }

    readonly property bool _shortcutInhibitorAvailable: {
        try {
            return typeof ShortcutInhibitor !== "undefined";
        } catch (e) {
            return false;
        }
    }

    function _createShortcutInhibitor() {
        if (!root._shortcutInhibitorAvailable || root._shortcutInhibitor)
            return;
        const qmlString = `
        import QtQuick
        import Quickshell.Wayland

        ShortcutInhibitor {
            enabled: false
            window: null
        }
        `;
        root._shortcutInhibitor = Qt.createQmlObject(qmlString, root, "KeybindsEditorTab.ShortcutInhibitor");
        root._shortcutInhibitor.enabled = Qt.binding(() => root.recordingKey);
        root._shortcutInhibitor.window = Qt.binding(() => root.window);
    }

    function _destroyShortcutInhibitor() {
        if (root._shortcutInhibitor) {
            root._shortcutInhibitor.enabled = false;
            root._shortcutInhibitor.destroy();
            root._shortcutInhibitor = null;
        }
    }

    function openAddDialog() {
        root.editingBind = null;
        root._editingVarName = "";
        root._preloadFlagsRaw = "";
        root.resetAddForm();
        root.newVarName = "";
        categoryDropdown.currentValue = "";
        root.dialogVisible = true;
        Qt.callLater(() => addDialogScope.forceActiveFocus());
    }

    function openEditDialog(bind, sectionName) {
        if (!bind)
            return;
        root.editingBind = bind;
        root._editingVarName = root.varNameFromToken(bind.keysRaw) || bind.keysRaw.replace(/^vars\./, "");
        root.resetAddForm();
        root.newVarName = root._editingVarName;
        root._preloadFlagsRaw = bind.flagsRaw || "";
        const varVal = HyprlandService.keybindVariablesMap[root._editingVarName];
        if (Array.isArray(varVal))
            root.newKeyCombos = varVal.map(v => String(v)).filter(v => v !== "");
        else if (varVal)
            root.newKeyCombos = [String(varVal)];
        else
            root.newKeyCombos = (bind.keys || []).map(k => k.combo || "");
        root.newLuaCode = root.actionTextOf(bind);
        root._editLiteralKeys = root.literalKeysOf(bind);
        root.newDesc = bind.desc || "";
        root.newCategory = sectionName || "";
        root.newCustomCategory = false;
        root.newCustomCategoryName = "";
        if (!root._editPreservesRaw)
            root.newFlags = (bind.flags || []).slice();
        categoryDropdown.currentValue = root.newCategory;
        root.dialogVisible = true;
        Qt.callLater(() => addDialogScope.forceActiveFocus());
    }

    function actionTextOf(bind) {
        const t = String(bind?.luaRaw !== undefined && bind.luaRaw !== "" ? bind.luaRaw : bind?.actionText || "").trim();
        if (t.startsWith('"') && t.endsWith('"'))
            return t.slice(1, -1).replace(/\\"/g, '"');
        return t;
    }

    function literalKeysOf(bind) {
        const out = [];
        const seen = {};
        const keys = bind?.keys || [];
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i];
            if (k.isVar)
                continue;
            const token = String(k.token || k.raw || k.combo || "").trim();
            if (token !== "" && !seen[token]) {
                seen[token] = true;
                out.push(token);
            }
        }
        return out;
    }

    function closeAddDialog() {
        root.stopKeyRecording();
        if (Qt.inputMethod) {
            Qt.inputMethod.hide();
            Qt.inputMethod.reset();
        }
        root.editingBind = null;
        root._editingVarName = "";
        root._preloadFlagsRaw = "";
        root._editLiteralKeys = [];
        root.saveError = "";
        root._showDeleteConfirm = false;
        root.dialogVisible = false;
    }

    function toggleFlag(flag) {
        const flags = root.newFlags.slice();
        const i = flags.indexOf(flag);
        if (i === -1)
            flags.push(flag);
        else
            flags.splice(i, 1);
        root.newFlags = flags;
    }

    function finishShortcutEdit(success) {
        if (success) {
            root.resetAddForm();
            root.closeAddDialog();
            return;
        }
        root.saveError = I18n.tr("Failed to save the shortcut. Check the shell log for details.", "Keybind save failure");
        ToastService.showError(I18n.tr("Failed to save the shortcut. Check the shell log for details.", "Keybind save failure"));
    }

    function addCustomShortcut() {
        if (!root._canAdd)
            return;
        root.saveError = "";
        const ok = HyprlandService.addCustomBind(root.newKeyCombos, root.newLuaCode, root._effectiveCategory, root.newDesc, root.newFlags, root.newVarName, root.finishShortcutEdit);
        if (!ok)
            root.finishShortcutEdit(false);
    }

    function saveEditShortcut() {
        if (!root._isEditing || !root._canAdd)
            return;
        root.saveError = "";
        const flags = root._editPreservesRaw ? [] : root.newFlags;
        const ok = HyprlandService.updateCustomBind(root.editingBind, root.newKeyCombos, root.newLuaCode, root._effectiveCategory, root.newDesc, flags, root._preloadFlagsRaw, root.newVarName, root._editLiteralKeys, root.finishShortcutEdit);
        if (!ok)
            root.finishShortcutEdit(false);
    }

    function resetAddForm() {
        root.stopKeyRecording();
        root._manualKeyEdit = false;
        root._editingComboIndex = -1;
        root.newKeyCombos = [];
        root.newLuaCode = "";
        root.newDesc = "";
        root.newVarName = "";
        root.newFlags = [];
        root.newCategory = "";
        root.newCustomCategory = false;
        root.newCustomCategoryName = "";
        root._editLiteralKeys = [];
        root.saveError = "";
        root._showDeleteConfirm = false;
    }

    function deleteShortcut(success) {
        if (success) {
            root.resetAddForm();
            root.closeAddDialog();
            return;
        }
        root._showDeleteConfirm = false;
        root.saveError = I18n.tr("Failed to delete the shortcut. Check the shell log for details.", "Keybind delete failure");
        ToastService.showError(I18n.tr("Failed to delete the shortcut. Check the shell log for details.", "Keybind delete failure"));
    }

    function confirmDeleteShortcut() {
        if (!root._isEditing)
            return;
        root.saveError = "";
        const ok = HyprlandService.removeCustomBind(root.editingBind, root.deleteShortcut);
        if (!ok)
            root.deleteShortcut(false);
    }
    Component.onDestruction: root._destroyShortcutInhibitor()

    Component.onCompleted: {
        if (!HyprlandService.keybindVariablesReady)
            HyprlandService.refreshKeybindVariables();
        if (!HyprlandService.keybindEditorLoading)
            HyprlandService.refreshKeybindEditor();
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        enabled: !root.dialogVisible
        interactive: !root._dragging
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
                tags: ["hyprland", "keybinds", "shortcuts"]
                title: I18n.tr("Keyboard Shortcuts")
                iconName: "keyboard"
                visible: !HyprlandService.keybindEditorReady

                StyledText {
                    width: parent.width
                    text: HyprlandService.keybindEditorLoading ? I18n.tr("Loading keyboard shortcuts...") : I18n.tr("Hyprland config is not available.")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    wrapMode: Text.Wrap
                }
            }

            DankTextField {
                width: parent.width
                placeholderText: I18n.tr("Search shortcuts...")
                cornerRadius: Theme.cornerRadius
                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                normalBorderColor: Theme.outlineMedium
                focusedBorderColor: Theme.primary
                leftIconName: "search"
                showClearButton: true
                textColor: Theme.surfaceText
                font.pixelSize: Theme.fontSizeLarge
                text: root.searchText

                onTextChanged: {
                    root.searchText = text;
                }
            }

            SettingsCard {
                tab: "hyprland"
                tags: ["hyprland", "keybinds", "shortcuts"]
                title: I18n.tr("No shortcuts found")
                iconName: "keyboard"
                visible: HyprlandService.keybindEditorReady && root.sections.length === 0

                StyledText {
                    width: parent.width
                    text: root.searchText.trim() ? I18n.tr("No shortcuts match your search.") : I18n.tr("No keyboard shortcuts found in your Hyprland config.")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    wrapMode: Text.Wrap
                }
            }

            SettingsCard {
                tab: "hyprland"
                tags: ["hyprland", "keybinds", "shortcuts"]
                title: root.collisionGroups.length === 1 ? I18n.tr("A shortcut shares its keys with another", "Keybind collision summary") : I18n.tr("%1 shortcuts share the same keys", "Keybind collision summary").arg(root.collisionGroups.length)
                iconName: "warning"
                visible: HyprlandService.keybindEditorReady && root.collisionGroups.length > 0

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.collisionGroups

                        delegate: Item {
                            id: collisionGroupRow
                            required property var modelData
                            width: parent.width
                            height: Math.max(collisionComboLabel.height, Math.max(collisionBindsLabel.height, Theme.fontSizeMedium))

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                StyledText {
                                    id: collisionComboLabel
                                    text: modelData.display
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    isMonospace: true
                                    color: Theme.warning
                                    width: Math.min(implicitWidth, parent.width * 0.3)
                                }

                                StyledText {
                                    id: collisionBindsLabel
                                    anchors.right: parent.right
                                    width: parent.width - collisionComboLabel.width - parent.spacing
                                    text: root.collisionLabelText(modelData)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            Repeater {
                model: root.sections

                delegate: SettingsCard {
                    id: sectionCard
                    required property var modelData
                    tab: "hyprland"
                    tags: ["hyprland", "keybinds", "shortcuts"]
                    title: modelData.name
                    iconName: modelData.icon
                    collapsible: true
                    expanded: true

                    Column {
                        id: bindsColumn
                        width: parent.width
                        spacing: Theme.spacingM

                        Repeater {
                            id: bindsRepeater
                            model: modelData.binds

                            delegate: Item {
                                id: outer
                                required property var modelData
                                required property int index
                                readonly property var bind: modelData
                                readonly property bool _isDragSource: root._dragging && root._dragStmtIndex === outer.bind.stmtIndex
                                readonly property bool _isDropTarget: root._dragging && root._dragSectionName === sectionCard.modelData.name && root._dropIndex === outer.index
                                width: parent.width
                                height: keybindItem.height

                                Rectangle {
                                    visible: outer._isDropTarget
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: 2
                                    color: Theme.primary
                                    z: 6
                                }

                                KeybindItem {
                                    id: keybindItem
                                    width: parent.width
                                    luaMode: true
                                    luaReadOnly: outer.bind ? !outer.bind.editable : true
                                    opacity: outer._isDragSource ? 0.4 : 1.0
                                    collisionInfo: outer.bind ? root.collideBindsFor(outer.bind.stmtIndex) : []

                                    bindData: outer.bind ? ({
                                        keys: outer.bind.keys.map(k => ({
                                            key: k.combo,
                                            isVar: k.isVar,
                                            token: k.token || ""
                                        })),
                                        action: outer.bind.actionText,
                                        desc: outer.bind.desc,
                                        category: outer.bind.desc ? outer.bind.actionText : "",
                                        conflict: null
                                    }) : null

                                    panelWindow: outer.window

                                    onEditVariable: (token, combo) => root.onEditVariable(outer.bind, token, combo)
                                    onEditBind: root.openEditDialog(outer.bind, sectionCard.modelData.name)
                                }

                                MouseArea {
                                    id: dragArea
                                    anchors.fill: parent
                                    z: -1
                                    acceptedButtons: Qt.LeftButton
                                    drag.target: dragProxy
                                    onPressAndHold: root.beginBindDrag(outer.bind, sectionCard.modelData.name, outer.index)
                                    onPositionChanged: mouse => root.updateBindDrag(dragArea, bindsColumn, bindsRepeater, mouse.x, mouse.y)
                                    onReleased: root.finishBindDrag()
                                    onCanceled: root.finishBindDrag()
                                }
                            }
                        }

                        SettingsDivider {
                            visible: sectionCard.modelData.name === "Apps" && root.appDefaultsList.length > 0
                        }

                        StyledText {
                            visible: sectionCard.modelData.name === "Apps" && root.appDefaultsList.length > 0
                            text: I18n.tr("Default applications")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Repeater {
                            model: sectionCard.modelData.name === "Apps" ? root.appDefaultsList : null

                            delegate: Item {
                                id: appRow
                                required property var modelData
                                width: parent.width
                                height: 48

                                StyledText {
                                    width: 220
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.humanize(modelData.name)
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                }

                                Item {
                                    id: appEscapeTarget
                                    anchors.fill: appValueField
                                    Keys.onEscapePressed: event => {
                                        event.accepted = true;
                                        appValueField.text = modelData.value != null ? String(modelData.value) : "";
                                    }
                                }

                                DankTextField {
                                    id: appValueField
                                    anchors.left: parent.left
                                    anchors.leftMargin: 220
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: Math.round(Theme.fontSizeMedium * 2)
                                    text: modelData.value != null ? String(modelData.value) : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                    normalBorderColor: Theme.outlineMedium
                                    focusedBorderColor: Theme.primary
                                    enabled: HyprlandService.keybindVariablesReady
                                    keyForwardTargets: [appEscapeTarget]

                                    onAccepted: appValueField.writeValue()

                                    onEditingFinished: appValueField.writeValue()

                                    function writeValue() {
                                        if (appValueField.text.trim() === "") {
                                            appValueField.text = modelData.value != null ? String(modelData.value) : "";
                                            return;
                                        }
                                        if (modelData.value != null && String(modelData.value) === appValueField.text.trim())
                                            return;
                                        HyprlandService.updateAppDefault(modelData.name, appValueField.text.trim());
}
}
                        }
                    }
                }
            }
        }
    }
}
    DankActionButton {
        id: addFab
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.spacingXL
        anchors.bottomMargin: Theme.spacingXL
        buttonSize: 56
        iconName: "add"
        iconSize: 26
        iconColor: Theme.primary
        backgroundColor: Theme.primaryContainer
        tooltipText: I18n.tr("Add shortcut")
        tooltipSide: "left"
        z: 50
        visible: HyprlandService.keybindEditorReady && !root.dialogVisible
        onClicked: root.openAddDialog()
    }

    Item {
        id: dragProxy
        width: 1
        height: 1
        visible: false
    }

    Rectangle {
        id: dragPill
        visible: root._dragging
        z: 60
        width: Math.min(pillKeys.implicitWidth + pillDesc.implicitWidth + Theme.spacingL * 2, 320)
        height: 44
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.primary
        x: root._dragCursorX - dragPill.width / 2
        y: root._dragCursorY - dragPill.height / 2

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: 2

            StyledText {
                id: pillDesc
                anchors.left: parent.left
                anchors.right: parent.right
                elide: Text.ElideRight
                text: root._dragBind ? (root._dragBind.desc || root._dragBind.actionText || "") : ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
            }

            StyledText {
                id: pillKeys
                anchors.left: parent.left
                anchors.right: parent.right
                elide: Text.ElideRight
                text: root._dragBind ? (root._dragBind.keys || []).map(k => k.combo).join(" + ") : ""
                font.pixelSize: Theme.fontSizeSmall
                isMonospace: true
                color: Theme.primary
            }
        }
    }

    Item {
        id: addDialogContainer
        anchors.fill: parent
        z: 100
        visible: root.dialogVisible

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }

        Rectangle {
            id: addDialogScrim
            anchors.fill: parent
            color: "black"
            opacity: root.dialogVisible ? 0.5 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeAddDialog()
            }
        }

        FocusScope {
            id: addDialogScope
            anchors.fill: parent
            focus: root.dialogVisible

            Keys.onEscapePressed: event => {
                if (root.recordingKey) {
                    root.stopKeyRecording();
                } else {
                    root.closeAddDialog();
                }
            }

            Rectangle {
                id: dialogCard
                width: Math.min(540, parent.width - Theme.spacingL * 2)
                height: Math.min(dialogForm.implicitHeight + headerRow.height + footerRow.height + Theme.spacingM * 2 + Theme.spacingL * 2, parent.height - Theme.spacingL * 2)
                anchors.centerIn: parent
                radius: Theme.cornerRadius + 4
                color: Theme.surfaceContainer
                border.width: 1
                border.color: Theme.outlineMedium
                clip: true
                opacity: root.dialogVisible ? 1 : 0
                scale: root.dialogVisible ? 1 : 0.95

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Item {
                    id: headerRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: Theme.spacingL
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    height: 60

                    StyledText {
                        id: headerTitle
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: root._isEditing ? I18n.tr("Edit shortcut") : I18n.tr("Add shortcut")
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    DankTextField {
                        id: varNameField
                        anchors.left: parent.left
                        anchors.top: headerTitle.bottom
                        anchors.topMargin: Theme.spacingXS
                        width: parent.width - Theme.spacingS
                        height: 24
                        topPadding: 0
                        bottomPadding: 0
                        text: root.newVarName !== "" ? root.newVarName : root._previewVarName
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: "monospace"
                        backgroundColor: "transparent"
                        normalBorderColor: "transparent"
                        focusedBorderColor: Theme.primary
                        placeholderText: root._previewVarName
                        placeholderColor: Theme.surfaceVariantText
                        onTextChanged: root.newVarName = varNameField.text.trim()
                    }

                    DankActionButton {
                        id: closeDialogButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        buttonSize: 28
                        iconName: "close"
                        iconSize: 16
                        iconColor: Theme.surfaceText
                        tooltipText: I18n.tr("Close")
                        tooltipSide: "left"
                        onClicked: root.closeAddDialog()
                    }
                }

                Flickable {
                    id: dialogBody
                    anchors.top: headerRow.bottom
                    anchors.topMargin: Theme.spacingM
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    height: Math.min(dialogForm.implicitHeight, dialogCard.height - headerRow.height - footerRow.height - Theme.spacingM * 2 - Theme.spacingL * 2)
                    contentHeight: dialogForm.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: DankScrollbar {}

                    Column {
                        id: dialogForm
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: I18n.tr("Keys")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }

                        Flow {
                            id: chipsFlow
                            width: parent.width
                            spacing: Theme.spacingS
                            flow: Flow.LeftToRight

                            Repeater {
                                model: root.newKeyCombos

                                delegate: Item {
                                    id: comboChip
                                    required property int index
                                    required property string modelData
                                    readonly property bool isSelected: root._editingComboIndex === index
                                    readonly property bool isEmpty: String(modelData || "").trim() === ""
                                    width: Theme.spacingM + Math.min(chipLabel.implicitWidth, 180) + Theme.spacingXS + 23
                                    height: 26

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 13
                                        color: comboChip.isSelected ? Theme.primaryContainer : (comboChipArea.containsMouse ? Theme.surfaceTextHover : Theme.surfaceContainerHigh)
                                        border.width: 1
                                        border.color: comboChip.isSelected ? Theme.primary : Theme.outlineMedium

                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingM
                                            anchors.right: comboChipRemoveArea.left
                                            anchors.rightMargin: Theme.spacingXS
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Theme.spacingXS

                                            Text {
                                                id: chipLabel
                                                text: comboChip.isEmpty ? I18n.tr("(empty)") : modelData
                                                color: comboChip.isSelected ? Theme.primary : (comboChip.isEmpty ? Theme.surfaceVariantText : Theme.surfaceText)
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.family: "monospace"
                                                elide: Text.ElideRight
                                                verticalAlignment: Text.AlignVCenter
                                                width: Math.min(implicitWidth, 180)
                                            }
                                        }

                                        MouseArea {
                                            id: comboChipArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (comboChip.isSelected && !root.recordingKey)
                                                    root.startKeyRecording(comboChip.index);
                                                else
                                                    root.selectComboForEdit(comboChip.index);
                                            }
                                        }

                                        Rectangle {
                                            id: comboChipRemoveArea
                                            anchors.right: parent.right
                                            anchors.rightMargin: 3
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 20
                                            height: 20
                                            radius: 10
                                            color: containsMouse ? Theme.errorHover : Theme.surfaceContainer
                                            z: 2

                                            DankIcon {
                                                name: "close"
                                                size: 12
                                                color: comboChipRemoveArea.containsMouse ? Theme.error : Theme.outline
                                                anchors.centerIn: parent
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.removeCombo(comboChip.index)
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: addComboChip
                                width: 16 + Theme.spacingXS + addChipLabel.implicitWidth + Theme.spacingM * 2
                                height: 26
                                radius: 13
                                color: addComboArea.containsMouse ? Theme.surfaceTextHover : Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: Theme.primary

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: "add"
                                        size: 16
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        id: addChipLabel
                                        text: I18n.tr("Add")
                                        color: Theme.primary
                                        font.pixelSize: Theme.fontSizeSmall
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: addComboArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.addNewCombo()
                                }
                            }
                        }

                        Item {
                            id: recorderSurface
                            width: parent.width
                            height: 40

                            FocusScope {
                                id: recordingScope
                                anchors.fill: parent
                                focus: root.recordingKey

                                onActiveFocusChanged: {
                                    if (!recordingScope.activeFocus && root.recordingKey)
                                        root.stopKeyRecording();
                                }

                                Keys.onPressed: event => root.keyRecorderDown(event)
                                Keys.onReleased: event => root.keyRecorderUp(event)

                                Rectangle {
                                    id: recorderBg
                                    anchors.fill: parent
                                    visible: !root._manualKeyEdit
                                    radius: Theme.cornerRadius
                                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                    border.width: 1
                                    border.color: root.recordingKey ? Theme.primary : Theme.outlineMedium

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                        }
                                    }
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.right: actionArea.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !root._manualKeyEdit
                                    clip: true

                                    Text {
                                        id: comboPreview
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: root.recordingKey ? (root._pendingCombo || I18n.tr("Press keys…")) : (root._editingComboIndex >= 0 && root.newKeyCombos[root._editingComboIndex] ? root.newKeyCombos[root._editingComboIndex] : I18n.tr("Click to record"))
                                        color: root.recordingKey ? Theme.primary : (root._editingComboIndex >= 0 && root.newKeyCombos[root._editingComboIndex] ? Theme.surfaceText : Theme.surfaceVariantText)
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.family: "monospace"
                                    }
                                }

                                Row {
                                    id: actionArea
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 0

                                    DankActionButton {
                                        id: manualEditButton
                                        buttonSize: 32
                                        iconName: "edit"
                                        iconSize: 15
                                        iconColor: root._manualKeyEdit || keyField.activeFocus ? Theme.primary : Theme.surfaceVariantText
                                        backgroundColor: "transparent"
                                        tooltipText: I18n.tr("Type the combo manually")
                                        tooltipSide: "left"
                                        visible: !root.recordingKey
                                        onClicked: root.toggleManualKeyEdit()
                                    }

                                    DankActionButton {
                                        id: clearRecordingButton
                                        buttonSize: 32
                                        iconName: "close"
                                        iconSize: 15
                                        iconColor: Theme.surfaceVariantText
                                        backgroundColor: "transparent"
                                        tooltipText: I18n.tr("Clear")
                                        tooltipSide: "left"
                                        visible: !root.recordingKey
                                        onClicked: {
                                            root.stopKeyRecording();
                                            root._manualKeyEdit = false;
                                            const arr = root.newKeyCombos.slice();
                                            if (root._editingComboIndex >= 0 && root._editingComboIndex < arr.length)
                                                arr[root._editingComboIndex] = "";
                                            root.newKeyCombos = arr;
                                        }
                                    }

                                    DankActionButton {
                                        id: confirmRecordingButton
                                        buttonSize: 32
                                        iconName: "check"
                                        iconSize: 15
                                        iconColor: root.recordingKey && root._pendingCombo ? Theme.primary : Theme.surfaceVariantText
                                        enabled: root.recordingKey && root._pendingCombo
                                        backgroundColor: "transparent"
                                        tooltipText: I18n.tr("Confirm combo")
                                        tooltipSide: "left"
                                        visible: root.recordingKey
                                        onClicked: root.confirmRecording()
                                    }

                                    DankActionButton {
                                        id: recordButton
                                        buttonSize: 32
                                        iconName: "mic"
                                        iconSize: 15
                                        iconColor: root.recordingKey ? Theme.primary : Theme.surfaceVariantText
                                        backgroundColor: "transparent"
                                        tooltipText: I18n.tr("Record")
                                        tooltipSide: "left"
                                        onClicked: root.recordingKey ? root.stopKeyRecording() : root.startKeyRecording()
                                    }
                                }
                            }

                            MouseArea {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: actionArea.left
                                enabled: !root.recordingKey && !root._manualKeyEdit
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.ensureComboTarget();
                                    root.startKeyRecording();
                                }
                            }

                            DankTextField {
                                id: keyField
                                visible: root._manualKeyEdit
                                anchors.left: parent.left
                                anchors.right: actionArea.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                height: 32
                                text: root._editingComboIndex >= 0 ? (root.newKeyCombos[root._editingComboIndex] || "") : ""
                                placeholderText: I18n.tr("e.g. SUPER + T")
                                font.pixelSize: Theme.fontSizeMedium
                                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                normalBorderColor: Theme.outlineMedium
                                focusedBorderColor: Theme.primary
                                onTextChanged: {
                                    if (root._editingComboIndex >= 0) {
                                        const arr = root.newKeyCombos.slice();
                                        while (arr.length <= root._editingComboIndex)
                                            arr.push("");
                                        arr[root._editingComboIndex] = keyField.text;
                                        root.newKeyCombos = arr;
                                    }
                                }
                            }
                        }

                        StyledText {
                            text: I18n.tr("Lua code")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }

                        DankFlickable {
                            id: luaEditorBox
                            width: parent.width
                            height: Math.min(220, Math.max(104, luaArea.implicitHeight + Theme.spacingM * 2 + 4))
                            clip: true
                            contentWidth: width - 8
                            contentHeight: luaArea.implicitHeight
                            z: 5

                            TextArea.flickable: TextArea {
                                id: luaArea
                                topPadding: Theme.spacingM
                                bottomPadding: Theme.spacingM
                                leftPadding: Theme.spacingM
                                rightPadding: Theme.spacingM
                                placeholderText: I18n.tr("(exec \"…\")")
                                placeholderTextColor: Theme.surfaceVariantText
                                color: Theme.surfaceText
                                selectionColor: Theme.primaryContainer
                                selectedTextColor: Theme.primary
                                text: root.newLuaCode
                                font.family: SettingsData.monoFontFamily || "monospace"
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: TextArea.Wrap
                                textFormat: TextEdit.PlainText
                                selectByMouse: true
                                selectByKeyboard: true
                                activeFocusOnTab: true
                                persistentSelection: true
                                cursorDelegate: Rectangle {
                                    width: 1.5
                                    radius: 1
                                    color: Theme.surfaceText
                                    x: luaArea.cursorRectangle.x
                                    y: luaArea.cursorRectangle.y
                                    height: luaArea.cursorRectangle.height

                                    SequentialAnimation on opacity {
                                        running: luaArea.activeFocus
                                        loops: Animation.Infinite
                                        PropertyAnimation {
                                            from: 1.0
                                            to: 0.0
                                            duration: 650
                                            easing.type: Easing.InOutQuad
                                        }
                                        PropertyAnimation {
                                            from: 0.0
                                            to: 1.0
                                            duration: 650
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }
                                onTextChanged: root.newLuaCode = luaArea.text
                            }
                        }

                        StyledText {
                            text: I18n.tr("Category")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }

                        DankDropdown {
                            id: categoryDropdown
                            width: parent.width
                            options: root.categoryOptions.concat([root.newCategoryLabel])
                            currentValue: root.newCustomCategory ? root.newCategoryLabel : root.newCategory
                            onValueChanged: value => {
                                if (value === root.newCategoryLabel) {
                                    root.newCustomCategory = true;
                                    root.newCustomCategoryName = "";
                                    Qt.callLater(() => newCategoryField.forceActiveFocus());
                                } else {
                                    root.newCustomCategory = false;
                                    root.newCategory = value;
                                }
                            }
                        }

                        DankTextField {
                            id: newCategoryField
                            visible: root.newCustomCategory
                            width: parent.width
                            height: Math.round(Theme.fontSizeMedium * 2 + 4)
                            placeholderText: I18n.tr("New category name")
                            font.pixelSize: Theme.fontSizeMedium
                            backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            normalBorderColor: Theme.outlineMedium
                            focusedBorderColor: Theme.primary
                            onTextChanged: root.newCustomCategoryName = newCategoryField.text.trim()
                        }

                        StyledText {
                            text: I18n.tr("Flags")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }

                        Row {
                            visible: !root._editPreservesRaw
                            spacing: Theme.spacingS
                            Repeater {
                                model: root.flagOptions
                                delegate: Item {
                                    id: flagChip
                                    required property string modelData
                                    property bool on: root.newFlags.indexOf(modelData) !== -1
                                    width: Math.max(flagChipLabel.implicitWidth + 20, 44)
                                    height: 26
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 13
                                        color: flagChip.on ? Theme.primaryContainer : Theme.surfaceContainerHigh
                                        border.width: 1
                                        border.color: flagChip.on ? Theme.primary : Theme.outlineMedium
                                        Text {
                                            id: flagChipLabel
                                            anchors.centerIn: parent
                                            text: flagChip.modelData
                                            color: flagChip.on ? Theme.primary : Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleFlag(flagChip.modelData)
                                        }
                                    }
                                }
                            }
                        }

                        StyledText {
                            visible: root._editPreservesRaw
                            width: parent.width
                            text: I18n.tr("Advanced flag expression is preserved as written.")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            text: I18n.tr("Description")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            id: descriptionField
                            width: parent.width
                            height: Math.round(Theme.fontSizeMedium * 2 + 4)
                            text: root.newDesc
                            placeholderText: I18n.tr("What does this shortcut do?")
                            font.pixelSize: Theme.fontSizeMedium
                            backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            normalBorderColor: Theme.outlineMedium
                            focusedBorderColor: Theme.primary
                            onAccepted: root._isEditing ? root.saveEditShortcut() : root.addCustomShortcut()
                            onTextChanged: root.newDesc = descriptionField.text.trim()
                        }
                    }
                }

                StyledText {
                    visible: root.saveError !== ""
                    anchors.bottom: footerRow.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    anchors.bottomMargin: Theme.spacingS
                    text: root.saveError
                    color: Theme.error
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                }

                Item {
                    id: footerRow
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottomMargin: Theme.spacingL
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    height: Math.max(addButton.height, cancelButton.height)

                    DankButton {
                        id: deleteButton
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root._isEditing && !root._showDeleteConfirm
                        text: I18n.tr("Delete")
                        backgroundColor: Theme.surfaceContainerHigh
                        textColor: Theme.error
                        onClicked: root._showDeleteConfirm = true
                    }

                    StyledText {
                        id: deleteConfirmText
                        anchors.left: parent.left
                        anchors.right: deleteConfirmButton.left
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root._showDeleteConfirm
                        text: I18n.tr("Delete this shortcut? This can't be undone.", "Keybind delete confirmation")
                        color: Theme.error
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                    }

                    DankButton {
                        id: deleteConfirmButton
                        anchors.right: deleteConfirmCancel.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root._showDeleteConfirm
                        text: I18n.tr("Delete")
                        backgroundColor: Theme.error
                        textColor: Theme.primaryText
                        onClicked: root.confirmDeleteShortcut()
                    }

                    DankButton {
                        id: deleteConfirmCancel
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root._showDeleteConfirm
                        text: I18n.tr("Cancel")
                        backgroundColor: Theme.surfaceContainerHigh
                        textColor: Theme.surfaceText
                        onClicked: root._showDeleteConfirm = false
                    }

                    DankButton {
                        id: cancelButton
                        anchors.right: addButton.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root._showDeleteConfirm
                        text: I18n.tr("Cancel")
                        backgroundColor: Theme.surfaceContainerHigh
                        textColor: Theme.surfaceText
                        onClicked: root.closeAddDialog()
                    }

                    DankButton {
                        id: addButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root._showDeleteConfirm
                        text: root._isEditing ? I18n.tr("Save") : I18n.tr("Add")
                        backgroundColor: Theme.primary
                        textColor: Theme.primaryText
                        enabled: root._canAdd
                        onClicked: root._isEditing ? root.saveEditShortcut() : root.addCustomShortcut()
                    }
                }
            }
        }
    }
}
