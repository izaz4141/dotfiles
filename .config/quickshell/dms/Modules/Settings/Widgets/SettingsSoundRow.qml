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

    property string eventKey: ""
    property string text: ""
    property string description: ""

    signal browseRequested(string eventKey)

    readonly property bool isHighlighted: settingKey !== "" && SettingsSearchService.highlightSection === settingKey
    readonly property var sourceOptions: AudioService.soundSourceOptions(eventKey)
    readonly property bool hasCustomSound: AudioService.customSoundPath(eventKey) !== ""
    readonly property bool isPreviewing: AudioService.previewPlaying && AudioService.previewKey === eventKey

    width: parent?.width ?? 0
    implicitHeight: Math.max(toggle.height, controls.height)

    function syncSourceLabel() {
        sourceDropdown.currentValue = Qt.binding(() => AudioService.soundSourceLabel(root.eventKey));
    }

    function findParentFlickable() {
        let p = root.parent;
        while (p) {
            if (p.hasOwnProperty("contentY") && p.hasOwnProperty("contentItem")) {
                return p;
            }
            p = p.parent;
        }
        return null;
    }

    Component.onCompleted: {
        syncSourceLabel();
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

    DankToggle {
        id: toggle

        width: Math.max(120, parent.width - controls.width - Theme.spacingM)
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        description: root.description
        checked: AudioService.isSoundEventEnabled(root.eventKey)
        onToggled: checked => AudioService.setEventEnabled(root.eventKey, checked)
    }

    Row {
        id: controls

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        DankDropdown {
            id: sourceDropdown

            compactMode: true
            dropdownWidth: 200
            buttonHeight: 34
            enableFuzzySearch: true
            emptyText: I18n.tr("Default")
            options: root.sourceOptions
            currentValue: AudioService.soundSourceLabel(root.eventKey)

            onValueChanged: value => {
                AudioService.selectSoundSource(root.eventKey, value);
                root.syncSourceLabel();
            }
        }

        DankActionButton {
            iconName: "folder_open"
            buttonSize: 34
            tooltipText: I18n.tr("Choose sound file", "Tooltip on the per-event sound row button that opens a file browser")
            onClicked: root.browseRequested(root.eventKey)
        }

        DankActionButton {
            iconName: root.isPreviewing ? "stop" : "play_arrow"
            buttonSize: 34
            iconColor: root.isPreviewing ? Theme.primary : Theme.surfaceText
            tooltipText: root.isPreviewing ? I18n.tr("Stop preview") : I18n.tr("Preview sound")
            onClicked: AudioService.previewSound(root.eventKey)
        }

        DankActionButton {
            iconName: "restart_alt"
            buttonSize: 34
            visible: root.hasCustomSound
            tooltipText: I18n.tr("Reset to default")
            onClicked: {
                AudioService.clearCustomSound(root.eventKey);
                root.syncSourceLabel();
            }
        }
    }
}
