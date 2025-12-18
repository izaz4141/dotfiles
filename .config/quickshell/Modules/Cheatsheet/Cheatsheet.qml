import qs.Services
import qs.Common
import qs.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.synchronizer
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope { // Scope
    id: root
    property var tabButtonList: [
        {
            "icon": "keyboard",
            "name": I18n.tr("Keybinds")
        },
        {
            "icon": "experiment",
            "name": I18n.tr("Elements")
        },
    ]

    signal closed()

    property int currentTabIndex: 0

    PanelWindow { // Window
        id: cheatsheetRoot
        visible: true

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        function hide() {
            root.closed();
        }
        exclusiveZone: 0
        implicitWidth: Screen.width * 0.7
        implicitHeight: Screen.height * 0.7
        WlrLayershell.namespace: "quickshell:cheatsheet"
        // Hyprland 0.49: Focus is always exclusive and setting this breaks mouse focus grab
        // WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"

        mask: Region {
            item: cheatsheetBackground
        }

        HyprlandFocusGrab { // Click outside to close
            id: grab
            windows: [cheatsheetRoot]
            active: cheatsheetRoot.visible
            onCleared: () => {
                if (!active)
                    cheatsheetRoot.hide();
            }
        }

            // Background
            Rectangle {
                id: cheatsheetBackground
                anchors.fill: parent
                layer.enabled: true
                layer.effect: DropShadow {
                    transparentBorder: true
                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 16
                    samples: 32
                    color: Qt.rgba(0, 0, 0, 0.5)
                }
                color: Theme.surface
                border.width: 1
                border.color: Theme.outline
                radius: Theme.cornerRadius
                property real padding: 20

                Keys.onPressed: event => { // Esc to close
                    if (event.key === Qt.Key_Escape) {
                        cheatsheetRoot.hide();
                    }
                    if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_PageDown) {
                            swipeView.currentIndex = (swipeView.currentIndex + 1) % swipeView.count;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageUp) {
                            swipeView.currentIndex = (swipeView.currentIndex - 1 + swipeView.count) % swipeView.count;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab) {
                            swipeView.currentIndex = (swipeView.currentIndex + 1) % swipeView.count;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Backtab) {
                            swipeView.currentIndex = (swipeView.currentIndex - 1 + swipeView.count) % swipeView.count;
                            event.accepted = true;
                        }
                    }
                }

                DankButton { // Close button
                    id: closeButton
                    // focus: cheatsheetRoot.visible
                    width: 40
                    buttonHeight: 40
                    radius: 100 // Full rounding
                    backgroundColor: "transparent"
                    textColor: Theme.surfaceText
                    iconName: "close"

                    anchors {
                        top: parent.top
                        right: parent.right
                        topMargin: 20
                        rightMargin: 20
                    }

                    onClicked: {
                        cheatsheetRoot.hide();
                    }
                }

                ColumnLayout { // Real content
                    id: cheatsheetColumnLayout
                    anchors.fill: parent
                    anchors.margins: cheatsheetBackground.padding
                    spacing: 10

                    DankTabBar {
                        id: tabBar
                        Layout.alignment: Qt.AlignHCenter
                        width: 300
                        model: root.tabButtonList.map(item => ({ text: item.name, icon: item.icon }))
                        currentIndex: swipeView.currentIndex
                        onTabClicked: (index) => {
                            swipeView.currentIndex = index
                        }
                    }

                    SwipeView { // Content pages
                        id: swipeView
                        Layout.topMargin: 5
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10
                        currentIndex: root.currentTabIndex
                        onCurrentIndexChanged: {
                            root.currentTabIndex = currentIndex;
                        }

                        clip: true
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: swipeView.width
                                height: swipeView.height
                                radius: Theme.cornerRadius
                            }
                        }

                        CheatsheetKeybinds {
                            id: keybindsPage
                        }
                        CheatsheetPeriodicTable {}

                        onCurrentItemChanged: {
                            if (currentItem === keybindsPage) {
                                keybindsPage.forceFocus();
                            }
                        }

                        Connections {
                            target: cheatsheetRoot
                            function onVisibleChanged() {
                                if (cheatsheetRoot.visible && swipeView.currentItem === keybindsPage) {
                                    keybindsPage.forceFocus();
                                }
                            }
                        }
                    }
                }
            }
        }


}
