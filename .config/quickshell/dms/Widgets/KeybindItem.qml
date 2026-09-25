pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import "../Common/KeyUtils.js" as KeyUtils
import "../Common/KeybindActions.js" as Actions

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var bindData: ({})
    property var panelWindow: null
    property bool recording: false
    property bool isNew: false
    property string restoreKey: ""
    property var collisionInfo: []

    property int editingKeyIndex: -1
    property string editKey: ""
    property string editAction: ""
    property string editDesc: ""
    property int editCooldownMs: 0
    property string editFlags: ""
    property bool editAllowWhenLocked: false
    property var editRepeat: undefined
    property var editAllowInhibiting: undefined
    property int _savedCooldownMs: -1
    property string _savedFlags: ""
    property var _savedAllowWhenLocked: undefined
    property var _savedRepeat: undefined
    property var _savedAllowInhibiting: undefined
    property bool hasChanges: false
    property string _actionType: ""
    property bool addingNewKey: false
    property bool useCustomCompositor: false
    property var _shortcutInhibitor: null
    property bool _altShiftGhost: false
    property bool luaMode: false
    property bool luaReadOnly: false
    property var luaRecordTarget: null
    property string _pendingCombo: ""
    property var _captureMods: ({})
    property var _captureKeys: []

    readonly property bool _hasVarKeys: {
        for (var i = 0; i < keys.length; i++) {
            if (keys[i].isVar)
                return true;
        }
        return false;
    }
    readonly property bool _luaRecordable: {
        if (!luaMode)
            return false;
        return root._hasVarKeys;
    }
    readonly property real _luaRecordSpace: _luaRecordable ? _chipHeight + Theme.spacingM : 0

    readonly property bool _shortcutInhibitorAvailable: {
        try {
            return typeof ShortcutInhibitor !== "undefined";
        } catch (e) {
            return false;
        }
    }

    readonly property var keys: bindData.keys || []
    readonly property bool hasOverride: {
        for (var i = 0; i < keys.length; i++) {
            if (keys[i].isOverride)
                return true;
        }
        return false;
    }
    readonly property var configConflict: bindData.conflict || null
    readonly property bool hasConfigConflict: configConflict !== null
    readonly property bool hasCollisionInfo: Array.isArray(collisionInfo) && collisionInfo.length > 0
    readonly property string _collisionTooltipText: root.hasCollisionInfo ? I18n.tr("Collides with: %1").arg(root.collisionInfo.join(", ")) : ""
    readonly property string _originalKey: editingKeyIndex >= 0 && editingKeyIndex < keys.length ? keys[editingKeyIndex].key : ""
    readonly property var _conflicts: editKey ? KeyUtils.getConflictingBinds(editKey, bindData.action, KeybindsService.getFlatBinds()) : []
    readonly property bool hasConflict: _conflicts.length > 0

    readonly property real _inputHeight: Math.round(Theme.fontSizeMedium * 3)
    readonly property real _chipHeight: Math.round(Theme.fontSizeSmall * 2.3)
    readonly property real _buttonHeight: Math.round(Theme.fontSizeMedium * 2.3)
    readonly property real _keysColumnWidth: Math.round(Theme.fontSizeSmall * 12)
    readonly property real _labelWidth: Math.round(Theme.fontSizeSmall * 5)

    signal saveBind(string originalKey, var newData)
    signal removeBind(string key)
    signal cancelEdit
    signal editVariable(string token, string combo)
    signal editBind

    implicitHeight: contentColumn.implicitHeight
    height: implicitHeight

    Component.onDestruction: _destroyShortcutInhibitor()

    function restoreToKey(keyToFind) {
        for (var i = 0; i < keys.length; i++) {
            if (keys[i].key === keyToFind) {
                editingKeyIndex = i;
                editKey = keyToFind;
                editAction = bindData.action || "";
                editDesc = bindData.desc || "";
                if (_savedCooldownMs >= 0) {
                    editCooldownMs = _savedCooldownMs;
                    _savedCooldownMs = -1;
                } else {
                    editCooldownMs = keys[i].cooldownMs || 0;
                }
                if (_savedFlags) {
                    editFlags = _savedFlags;
                    _savedFlags = "";
                } else {
                    editFlags = keys[i].flags || "";
                }
                if (_savedAllowWhenLocked !== undefined) {
                    editAllowWhenLocked = _savedAllowWhenLocked;
                    _savedAllowWhenLocked = undefined;
                } else {
                    editAllowWhenLocked = keys[i].allowWhenLocked || false;
                }
                if (_savedRepeat !== undefined) {
                    editRepeat = _savedRepeat;
                    _savedRepeat = undefined;
                } else {
                    editRepeat = keys[i].repeat;
                }
                if (_savedAllowInhibiting !== undefined) {
                    editAllowInhibiting = _savedAllowInhibiting;
                    _savedAllowInhibiting = undefined;
                } else {
                    editAllowInhibiting = keys[i].allowInhibiting;
                }
                hasChanges = false;
                _actionType = Actions.getActionType(editAction);
                useCustomCompositor = _actionType === "compositor" && editAction && !Actions.isKnownCompositorAction(KeybindsService.currentProvider, editAction);
                return;
            }
        }
        resetEdits();
    }

    onEditActionChanged: {
        _actionType = Actions.getActionType(editAction);
    }

    function resetEdits() {
        addingNewKey = false;
        editingKeyIndex = keys.length > 0 ? 0 : -1;
        editKey = editingKeyIndex >= 0 ? keys[editingKeyIndex].key : "";
        editAction = bindData.action || "";
        editDesc = bindData.desc || "";
        editCooldownMs = editingKeyIndex >= 0 ? (keys[editingKeyIndex].cooldownMs || 0) : 0;
        editFlags = editingKeyIndex >= 0 ? (keys[editingKeyIndex].flags || "") : "";
        editAllowWhenLocked = editingKeyIndex >= 0 ? (keys[editingKeyIndex].allowWhenLocked || false) : false;
        editRepeat = editingKeyIndex >= 0 ? keys[editingKeyIndex].repeat : undefined;
        editAllowInhibiting = editingKeyIndex >= 0 ? keys[editingKeyIndex].allowInhibiting : undefined;
        hasChanges = false;
        _actionType = Actions.getActionType(editAction);
        useCustomCompositor = _actionType === "compositor" && editAction && !Actions.isKnownCompositorAction(KeybindsService.currentProvider, editAction);
    }

    function startAddingNewKey() {
        addingNewKey = true;
        editingKeyIndex = -1;
        editKey = "";
        hasChanges = true;
    }

    function selectKeyForEdit(index) {
        if (index < 0 || index >= keys.length)
            return;
        addingNewKey = false;
        editingKeyIndex = index;
        editKey = keys[index].key;
        editCooldownMs = keys[index].cooldownMs || 0;
        editFlags = keys[index].flags || "";
        editAllowWhenLocked = keys[index].allowWhenLocked || false;
        editRepeat = keys[index].repeat;
        editAllowInhibiting = keys[index].allowInhibiting;
        hasChanges = false;
    }

    function updateEdit(changes) {
        if (changes.key !== undefined)
            editKey = changes.key;
        if (changes.action !== undefined)
            editAction = changes.action;
        if (changes.desc !== undefined)
            editDesc = changes.desc;
        if (changes.cooldownMs !== undefined)
            editCooldownMs = changes.cooldownMs;
        if (changes.flags !== undefined)
            editFlags = changes.flags;
        if (changes.allowWhenLocked !== undefined)
            editAllowWhenLocked = changes.allowWhenLocked;
        if (changes.repeat !== undefined)
            editRepeat = changes.repeat;
        if (changes.allowInhibiting !== undefined)
            editAllowInhibiting = changes.allowInhibiting;
        const hasKey = editingKeyIndex >= 0 && editingKeyIndex < keys.length;
        const origKey = hasKey ? keys[editingKeyIndex].key : "";
        const origCooldown = hasKey ? (keys[editingKeyIndex].cooldownMs || 0) : 0;
        const origFlags = hasKey ? (keys[editingKeyIndex].flags || "") : "";
        const origAllowWhenLocked = hasKey ? (keys[editingKeyIndex].allowWhenLocked || false) : false;
        const origRepeat = hasKey ? keys[editingKeyIndex].repeat : undefined;
        const origAllowInhibiting = hasKey ? keys[editingKeyIndex].allowInhibiting : undefined;
        hasChanges = editKey !== origKey || editAction !== (bindData.action || "") || editDesc !== (bindData.desc || "") || editCooldownMs !== origCooldown || editFlags !== origFlags || editAllowWhenLocked !== origAllowWhenLocked || editRepeat !== origRepeat || editAllowInhibiting !== origAllowInhibiting;
    }

    function canSave() {
        if (!editKey)
            return false;
        if (!Actions.isValidAction(editAction))
            return false;
        return true;
    }

    function doSave() {
        if (!canSave())
            return;
        const origKey = addingNewKey ? "" : _originalKey;
        const desc = editDesc;
        _savedCooldownMs = editCooldownMs;
        _savedFlags = editFlags;
        _savedAllowWhenLocked = editAllowWhenLocked;
        _savedRepeat = editRepeat;
        _savedAllowInhibiting = editAllowInhibiting;
        saveBind(origKey, {
            "key": editKey,
            "action": editAction,
            "desc": desc,
            "cooldownMs": editCooldownMs,
            "flags": editFlags,
            "allowWhenLocked": editAllowWhenLocked,
            "repeat": editRepeat,
            "allowInhibiting": editAllowInhibiting
        });
        hasChanges = false;
        addingNewKey = false;
    }

    function _createShortcutInhibitor() {
        if (!_shortcutInhibitorAvailable || _shortcutInhibitor)
            return;
        const qmlString = `
        import QtQuick
        import Quickshell.Wayland

        ShortcutInhibitor {
        enabled: false
        window: null
        }
        `;

        _shortcutInhibitor = Qt.createQmlObject(qmlString, root, "KeybindItem.ShortcutInhibitor");
        _shortcutInhibitor.enabled = Qt.binding(() => root.recording);
        _shortcutInhibitor.window = Qt.binding(() => root.panelWindow);
    }

    function _destroyShortcutInhibitor() {
        if (_shortcutInhibitor) {
            _shortcutInhibitor.enabled = false;
            _shortcutInhibitor.destroy();
            _shortcutInhibitor = null;
        }
    }

    function startRecording() {
        _destroyShortcutInhibitor();
        _createShortcutInhibitor();
        recording = true;
    }

    function stopRecording() {
        recording = false;
        _destroyShortcutInhibitor();
    }

    function luaKeyNameFromEvent(event) {
        return KeyUtils.luaKeyNameFromEvent(event);
    }

    function luaModsFromEvent(event) {
        return KeyUtils.luaModsFromEvent(event);
    }

    function luaComboFromEvent(event) {
        return KeyUtils.luaComboFromEvent(event);
    }

    function _ensureLiteralSelection() {
        if (addingNewKey || luaMode)
            return;
        for (var i = 0; i < keys.length; i++) {
            if (!keys[i].isVar) {
                if (editingKeyIndex !== i)
                    root.selectKeyForEdit(i);
                return;
            }
        }
        editingKeyIndex = -1;
        editKey = "";
    }

    function doLuaSave() {
        if (!editKey)
            return;
        const origKey = addingNewKey ? "" : _originalKey;
        saveBind(origKey, {
            "key": editKey
        });
        hasChanges = false;
        addingNewKey = false;
    }

    function luaStartRecordForVar(token) {
        if (!luaMode || recording)
            return;
        root.luaStartRecordFor({
            "kind": "var",
            "token": token || ""
        });
    }

    function luaStartRecordFor(target) {
        if (!target || recording)
            return;
        luaRecordTarget = target;
        _pendingCombo = "";
        _captureMods = {};
        _captureKeys = [];
        root.startRecording();
    }

    function luaStopRecord() {
        luaRecordTarget = null;
        _pendingCombo = "";
        _captureMods = {};
        _captureKeys = [];
        root.stopRecording();
    }

    function commitRecording() {
        if (!recording)
            return;
        const target = root.luaRecordTarget;
        const combo = root._pendingCombo;
        if (combo && target && target.kind === "var")
            root.editVariable(target.token || "", combo);
        root.luaStopRecord();
    }

    function _chipIsRecordTarget(index, data) {
        if (!recording || !luaMode || !luaRecordTarget)
            return false;
        if (luaRecordTarget.kind === "key")
            return luaRecordTarget.keyIndex === index;
        return luaRecordTarget.kind === "var" && luaRecordTarget.token === (data.token || data.key);
    }

    function _modifierClassFromKey(k) {
        switch (k) {
        case Qt.Key_Control:
            return "CTRL";
        case Qt.Key_Shift:
            return "SHIFT";
        case Qt.Key_Alt:
            return "ALT";
        case Qt.Key_Meta:
        case Qt.Key_Super_L:
        case Qt.Key_Super_R:
        case Qt.Key_Hyper_L:
        case Qt.Key_Hyper_R:
            return "SUPER";
        }
        return "";
    }

    function _rebuildPendingCombo() {
        const mods = [];
        if (root._captureMods.SUPER)
            mods.push("SUPER");
        if (root._captureMods.CTRL)
            mods.push("CTRL");
        if (root._captureMods.ALT)
            mods.push("ALT");
        if (root._captureMods.SHIFT)
            mods.push("SHIFT");
        return mods.concat(root._captureKeys).join(" + ");
    }

    function luaCollapsedKeyEvent(event) {
        if (!recording)
            return false;
        event.accepted = true;

        if (event.key === Qt.Key_Escape) {
            root.luaStopRecord();
            return true;
        }

        if (event.key === 0)
            return true;

        const modClass = root._modifierClassFromKey(event.key);
        if (modClass) {
            root._captureMods[modClass] = true;
            root._pendingCombo = root._rebuildPendingCombo();
            return true;
        }

        const name = root.luaKeyNameFromEvent(event);
        if (!name)
            return true;

        if (root._captureKeys.indexOf(name) === -1)
            root._captureKeys.push(name);
        root._pendingCombo = root._rebuildPendingCombo();
        return true;
    }

    function luaCollapsedKeyRelease(event) {
        if (!recording)
            return false;
        event.accepted = true;

        const modClass = root._modifierClassFromKey(event.key);
        if (modClass) {
            delete root._captureMods[modClass];
            return true;
        }

        const name = root.luaKeyNameFromEvent(event);
        if (name) {
            const idx = root._captureKeys.indexOf(name);
            if (idx !== -1)
                root._captureKeys.splice(idx, 1);
        }
        return true;
    }

    Column {
        id: contentColumn
        width: parent.width
        spacing: 0

        Rectangle {
            id: collapsedRect
            width: parent.width
            height: Math.max(root._inputHeight + Theme.spacingM, keysColumn.implicitHeight + Theme.spacingM * 2)
            radius: Theme.cornerRadius
            topLeftRadius: Theme.cornerRadius
            topRightRadius: Theme.cornerRadius
            color: root.hasOverride ? Theme.surfaceContainer : Theme.surfaceContainerHighest
            border.color: root.hasOverride ? Theme.outlineVariant : "transparent"
            border.width: root.hasOverride ? 1 : 0

            RowLayout {
                id: collapsedContent
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                spacing: Theme.spacingM

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    StyledText {
                        text: root.bindData.desc || root.bindData.action || I18n.tr("No action")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                    }

                    RowLayout {
                        spacing: Theme.spacingS
                        Layout.fillWidth: true

                        StyledText {
                            text: I18n.tr("Override")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            visible: root.hasOverride && !root.hasConfigConflict && !root.hasCollisionInfo
                        }

                        DankIcon {
                            name: "warning"
                            size: Theme.iconSizeSmall
                            color: Theme.primary
                            visible: root.hasConfigConflict
                        }

                        StyledText {
                            text: I18n.tr("Overridden by config")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            visible: root.hasConfigConflict
                        }

                        Item {
                            id: collisionIndicator
                            visible: root.hasCollisionInfo
                            width: collisionIcon.width + collisionLabel.width + Theme.spacingXS
                            height: collisionLabel.height

                            DankIcon {
                                id: collisionIcon
                                name: "warning"
                                size: Theme.iconSizeSmall
                                color: Theme.warning
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                id: collisionLabel
                                anchors.left: collisionIcon.right
                                anchors.leftMargin: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.collisionInfo.length === 1 ? I18n.tr("Collides with another shortcut", "Keybind collision count") : I18n.tr("Collides with %1 shortcuts", "Keybind collision count").arg(root.collisionInfo.length)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.warning
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, 180)
                            }

                            MouseArea {
                                id: collisionHoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: collisionTooltip.show(root._collisionTooltipText, collisionIndicator, 0, 0, "bottom")
                                onExited: collisionTooltip.hide()
                            }

                            DankTooltipV2 {
                                id: collisionTooltip
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    StyledText {
                        visible: root.luaMode && root.recording
                        text: root._pendingCombo ? I18n.tr("Press ✓ to confirm · Esc to cancel") : I18n.tr("Recording… press a shortcut · Esc to cancel")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.error
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                Column {
                    id: keysColumn
                    Layout.preferredWidth: root._keysColumnWidth
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.spacingXS

                    Repeater {
                        model: root.keys

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            property bool isSelected: false
                            property bool isRecordTarget: root._chipIsRecordTarget(index, modelData)

                            width: root._keysColumnWidth
                            height: root._chipHeight
                            radius: root._chipHeight / 4
                            color: isSelected ? Theme.primary : (root.luaMode && modelData.isVar ? Theme.withAlpha(Theme.primary, 0.15) : Theme.surfaceVariant)

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: chipArea.pressed ? Theme.surfaceTextHover : (chipArea.containsMouse ? Theme.surfaceTextHover : "transparent")
                            }

                            Rectangle {
                                visible: parent.isRecordTarget
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 2
                                border.color: Theme.primary
                                opacity: 0.9

                                NumberAnimation on opacity {
                                    from: 0.9
                                    to: 0.2
                                    duration: 500
                                    loops: Animation.Infinite
                                    running: parent.visible
                                }
                            }

                            StyledText {
                                visible: !(parent.isRecordTarget && root.recording)
                                text: modelData.key
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: parent.isSelected ? Font.Medium : Font.Normal
                                isMonospace: true
                                color: parent.isSelected ? Theme.primaryText : (root.luaMode && modelData.isVar ? Theme.primary : Theme.surfaceVariantText)
                                anchors.centerIn: parent
                                width: parent.width - Theme.spacingS
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            Row {
                                visible: parent.isRecordTarget && root.recording
                                anchors.centerIn: parent
                                width: parent.width - Theme.spacingS
                                spacing: Theme.spacingXS

                                StyledText {
                                    text: root._pendingCombo || I18n.tr("Press...")
                                    font.pixelSize: Theme.fontSizeSmall
                                    isMonospace: true
                                    color: Theme.primary
                                    width: parent.width - checkIcon.width - parent.spacing
                                    elide: Text.ElideRight
                                }

                                DankIcon {
                                    id: checkIcon
                                    name: "check"
                                    size: Theme.iconSizeSmall
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: root.luaMode && !modelData.isVar ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: {
                                    if (root.recording) {
                                        if (root._chipIsRecordTarget(index, modelData))
                                            root.commitRecording();
                                        return;
                                    }
                                    if (root.luaMode) {
                                        if (modelData.isVar)
                                            root.luaStartRecordForVar(modelData.token || modelData.key);
                                        return;
                                    }
                                    root.selectKeyForEdit(index);
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.preferredWidth: root._luaRecordSpace
                }
            }

            Rectangle {
                id: luaEditButton
                visible: root.luaMode && root._luaRecordable && !root.recording
                width: root._chipHeight
                height: root._chipHeight
                radius: root._chipHeight / 4
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                z: 5
                color: Theme.withAlpha(Theme.primary, 0.15)
                border.color: Theme.withAlpha(Theme.primary, 0.4)
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: luaEditArea.pressed ? Theme.surfaceTextHover : (luaEditArea.containsMouse ? Theme.surfaceTextHover : "transparent")
                }

                DankIcon {
                    name: "edit"
                    size: Theme.iconSizeSmall
                    color: Theme.primary
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: luaEditArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editBind()
                }
            }

            FocusScope {
                id: collapsedCaptureScope
                anchors.fill: parent
                focus: root.recording && root.luaMode

                Component.onCompleted: {
                    if (root.recording)
                        forceActiveFocus();
                }

                Connections {
                    target: root
                    function onRecordingChanged() {
                        if (root.recording)
                            collapsedCaptureScope.forceActiveFocus();
                    }
                }

                Keys.onPressed: event => root.luaCollapsedKeyEvent(event)

                Keys.onReleased: event => root.luaCollapsedKeyRelease(event)
            }
        }
    }
}
