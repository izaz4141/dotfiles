pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Modules.Toolbox.aiChat
import qs.Modules.Toolbox.booru

Item {
    id: root

    property int currentIndex: 0

    signal hideRequested

    readonly property var tabs: [{
        "icon": "neurology",
        "text": I18n.tr("Intelligence", "AiChat toolbar")
    }, {
        "icon": "manga",
        "text": I18n.tr("Booru", "Booru")
    }]

    function focusActiveItem() {
        if (swipeView.currentItem)
            swipeView.currentItem.forceActiveFocus();
    }

    Keys.onEscapePressed: event => {
        root.hideRequested();
        event.accepted = true;
    }

    Keys.onPressed: event => {
        if (event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown) {
                swipeView.incrementCurrentIndex();
                event.accepted = true;
            } else if (event.key === Qt.Key_PageUp) {
                swipeView.decrementCurrentIndex();
                event.accepted = true;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.small

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: tabBar.tabHeight + 12

            DankTabBar {
                id: tabBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                currentIndex: root.currentIndex
                model: root.tabs
                showIcons: true
                equalWidthTabs: true
                onTabClicked: index => root.currentIndex = index
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh
            clip: true

            SwipeView {
                id: swipeView
                anchors.fill: parent
                currentIndex: root.currentIndex
                spacing: Appearance.spacing.small

                onCurrentIndexChanged: root.currentIndex = currentIndex

                AiChat {}
                Booru {}
            }
        }
    }
}
