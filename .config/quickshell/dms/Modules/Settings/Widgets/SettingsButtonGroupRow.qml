pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string tab: ""
    property var tags: []
    property string settingKey: ""

    property string text: ""
    property string description: ""

    property string storeKey: ""
    property var storedValue: undefined
    property var encodeValue: null
    property var decodeValue: null

    readonly property bool isHighlighted: settingKey !== "" && SettingsSearchService.highlightSection === settingKey

    function toStored(uiValue) {
        return root.encodeValue ? root.encodeValue(uiValue) : uiValue;
    }

    function toUi(stored) {
        return root.decodeValue ? root.decodeValue(stored) : stored;
    }

    function commitStore(uiValue) {
        if (!root.storeKey)
            return;
        const value = root.toStored(uiValue);
        if (SettingsData[root.storeKey] === value)
            return;
        SettingsData.set(root.storeKey, value);
    }

    function syncFromStore() {
        if (!root.storeKey)
            return;
        const index = root.toUi(root.storedValue);
        if (typeof index !== "number" || !isFinite(index))
            return;
        buttonGroup.currentIndex = index;
    }

    function findParentFlickable() {
        let p = root.parent;
        while (p) {
            if (p.hasOwnProperty("contentY") && p.hasOwnProperty("contentItem"))
                return p;
            p = p.parent;
        }
        return null;
    }

    Component.onCompleted: {
        root.syncFromStore();
        if (!settingKey)
            return;
        let flickable = findParentFlickable();
        if (flickable)
            SettingsSearchService.registerCard(settingKey, root, flickable);
    }

    Component.onDestruction: {
        if (settingKey)
            SettingsSearchService.unregisterCard(settingKey);
    }

    onStoredValueChanged: root.syncFromStore()

    Connections {
        target: root
        function onSelectionChanged(index, selected) {
            if (root.selectionMode !== "single")
                return;
            root.commitStore(index);
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.primary, root.isHighlighted ? 0.2 : 0)
        visible: root.isHighlighted

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    property alias model: buttonGroup.model
    property alias currentIndex: buttonGroup.currentIndex
    property alias selectionMode: buttonGroup.selectionMode
    property alias buttonHeight: buttonGroup.buttonHeight
    property alias minButtonWidth: buttonGroup.minButtonWidth
    property alias buttonPadding: buttonGroup.buttonPadding
    property alias checkIconSize: buttonGroup.checkIconSize
    property alias textSize: buttonGroup.textSize
    property alias spacing: buttonGroup.spacing
    property alias checkEnabled: buttonGroup.checkEnabled

    signal selectionChanged(int index, bool selected)

    width: parent?.width ?? 0
    height: 60

    Row {
        id: contentRow
        width: parent.width - Theme.spacingM * 2
        x: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingM

        Column {
            width: parent.width - buttonGroup.width - Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            StyledText {
                text: root.text
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                elide: Text.ElideRight
                width: parent.width
                visible: root.text !== ""
                horizontalAlignment: Text.AlignLeft
            }

            StyledText {
                text: root.description
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                visible: root.description !== ""
                horizontalAlignment: Text.AlignLeft
            }
        }

        DankButtonGroup {
            id: buttonGroup
            anchors.verticalCenter: parent.verticalCenter
            selectionMode: "single"
            onSelectionChanged: (index, selected) => root.selectionChanged(index, selected)
        }
    }
}
