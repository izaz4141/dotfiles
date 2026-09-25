import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Scope {
    id: overlayRoot

    property bool active: false
    property string target: "clipboard"
    property var targetScreen: null

    signal regionCaptureFinished()

    function show(screen) {
        targetScreen = screen ? screen : CompositorService.getFocusedScreen();
        active = true;
        PopoutManager.screenshotActive = true;
    }

    function hide() {
        PopoutManager.screenshotActive = false;
        active = false;
    }

    function finalize(rx, ry, rw, rh, screen) {
        const crx = Math.max(rx, 0);
        const cry = Math.max(ry, 0);
        const crw = Math.max(rw, 1);
        const crh = Math.max(rh, 1);
        PopoutManager.screenshotActive = false;
        active = false;
        Qt.callLater(() => {
            ScreenshotService.captureRegion(
                screen, crx, cry, crw, crh, target,
                (err, result) => { overlayRoot.regionCaptureFinished(); }
            );
        });
    }

    Loader {
        id: regionLoader
        active: overlayRoot.active
        asynchronous: false

        sourceComponent: Variants {
            id: regionVariants
            model: Quickshell.screens

            PanelWindow {
                id: win
                required property var modelData

                screen: modelData
                visible: overlayRoot.active
                color: "transparent"

                WlrLayershell.namespace: "dms:screenshot-region"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: overlayRoot.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                Item {
                    id: selector
                    anchors.fill: parent

                    property real regionX: 0
                    property real regionY: 0
                    property real regionWidth: 0
                    property real regionHeight: 0
                    property real dragStartX: 0
                    property real dragStartY: 0
                    property bool dragActive: false

                    Rectangle {
                        id: dimTop
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: selector.regionY
                        color: "#66000000"
                        visible: selector.dragActive || selector.regionHeight > 0
                    }

                    Rectangle {
                        id: dimBottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height - (selector.regionY + selector.regionHeight)
                        color: "#66000000"
                        visible: selector.dragActive || selector.regionHeight > 0
                    }

                    Rectangle {
                        id: dimLeft
                        x: 0
                        y: selector.regionY
                        width: selector.regionX
                        height: selector.regionHeight
                        color: "#66000000"
                        visible: selector.dragActive || selector.regionHeight > 0
                    }

                    Rectangle {
                        id: dimRight
                        x: selector.regionX + selector.regionWidth
                        y: selector.regionY
                        width: parent.width - (selector.regionX + selector.regionWidth)
                        height: selector.regionHeight
                        color: "#66000000"
                        visible: selector.dragActive || selector.regionHeight > 0
                    }

                    Rectangle {
                        id: selectionBorder
                        x: selector.regionX
                        y: selector.regionY
                        width: selector.regionWidth
                        height: selector.regionHeight
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.primary
                        visible: selector.dragActive || selector.regionHeight > 0
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        cursorShape: Qt.CrossCursor
                        hoverEnabled: true

                        onPressed: mouse => {
                            selector.dragStartX = mouse.x;
                            selector.dragStartY = mouse.y;
                            selector.regionX = mouse.x;
                            selector.regionY = mouse.y;
                            selector.regionWidth = 0;
                            selector.regionHeight = 0;
                            selector.dragActive = true;
                        }

                        onPositionChanged: mouse => {
                            if (!selector.dragActive)
                                return;
                            selector.regionX = Math.min(selector.dragStartX, mouse.x);
                            selector.regionY = Math.min(selector.dragStartY, mouse.y);
                            selector.regionWidth = Math.abs(mouse.x - selector.dragStartX);
                            selector.regionHeight = Math.abs(mouse.y - selector.dragStartY);
                        }

                        onReleased: mouse => {
                            if (!selector.dragActive)
                                return;
                            selector.dragActive = false;
                            overlayRoot.finalize(
                                selector.regionX, selector.regionY,
                                selector.regionWidth, selector.regionHeight,
                                win.screen
                            );
                        }
                    }
                }

                FocusScope {
                    id: focusScope
                    anchors.fill: parent
                    visible: overlayRoot.active
                    focus: overlayRoot.active

                    Keys.onEscapePressed: event => {
                        event.accepted = true;
                        overlayRoot.hide();
                    }

                    onVisibleChanged: {
                        if (visible)
                            Qt.callLater(() => focusScope.forceActiveFocus());
                    }
                }

                onVisibleChanged: {
                    if (visible)
                        Qt.callLater(() => focusScope.forceActiveFocus());
                }
            }
        }
    }
}
