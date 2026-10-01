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
        const uiValue = root.toUi(root.storedValue);
        if (typeof uiValue !== "number" || !isFinite(uiValue))
            return;
        slider.value = Math.round(uiValue);
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
        function onSliderValueChanged(newValue) { root.commitStore(newValue); }
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
    property alias value: slider.value
    property alias minimum: slider.minimum
    property alias maximum: slider.maximum
    property alias step: slider.step
    property alias unit: slider.unit
    property alias wheelEnabled: slider.wheelEnabled
    property alias thumbOutlineColor: slider.thumbOutlineColor
    property int defaultValue: -1

    signal sliderValueChanged(int newValue)
    signal sliderDragFinished(int finalValue)
    width: parent?.width ?? 0
    height: headerRow.height + Theme.spacingXS + slider.height

    Column {
        id: contentColumn
        width: parent.width - Theme.spacingM * 2
        x: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        Row {
            id: headerRow
            width: parent.width
            height: labelColumn.height
            spacing: Theme.spacingS

            Column {
                id: labelColumn
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS
                width: parent.width - resetButtonContainer.width - Theme.spacingS

                StyledText {
                    text: root.text
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    visible: root.text !== ""
                    width: parent.width
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

            Item {
                id: resetButtonContainer
                width: root.defaultValue >= 0 ? 36 : 0
                height: 36
                anchors.verticalCenter: parent.verticalCenter

                DankActionButton {
                    id: resetButton
                    anchors.centerIn: parent
                    buttonSize: 36
                    iconName: "restart_alt"
                    iconSize: 20
                    visible: root.defaultValue >= 0 && slider.value !== root.defaultValue
                    backgroundColor: Theme.surfaceContainerHigh
                    iconColor: Theme.surfaceVariantText
                    onClicked: {
                        slider.value = root.defaultValue;
                        root.sliderValueChanged(root.defaultValue);
                        root.sliderDragFinished(root.defaultValue);
                    }
                }
            }
        }

        DankSlider {
            id: slider
            width: parent.width
            height: 32
            showValue: true
            wheelEnabled: false
            thumbOutlineColor: Theme.surfaceContainerHigh
            onSliderValueChanged: newValue => root.sliderValueChanged(newValue)
            onSliderDragFinished: finalValue => root.sliderDragFinished(finalValue)
        }
    }
}
