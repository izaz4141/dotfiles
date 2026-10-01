import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services

Scope {
    id: overviewScope

    property bool overviewOpen: false
    property bool closing: false

    function closeOverview() {
        closing = true
        overviewOpen = false
    }

    Loader {
        id: hyprlandLoader
        active: overviewScope.overviewOpen
        asynchronous: false

        sourceComponent: Variants {
            id: overviewVariants
            model: Quickshell.screens

            PanelWindow {
                id: root
                required property var modelData
                readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
                property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
                property int lastDispatchedWorkspaceId: -1

                screen: modelData
                visible: overviewScope.overviewOpen
                color: "transparent"

                WlrLayershell.namespace: "dms:workspace-overview"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: {
                    if (!overviewScope.overviewOpen)
                        return WlrKeyboardFocus.None;
                    if (CompositorService.useHyprlandFocusGrab)
                        return WlrKeyboardFocus.OnDemand;
                    return WlrKeyboardFocus.Exclusive;
                }

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

            HyprlandFocusGrab {
                id: grab
                windows: [root]
                active: false
                property bool hasBeenActivated: false
                onActiveChanged: {
                    if (active) {
                        hasBeenActivated = true
                    }
                }
                onCleared: () => {
                    if (hasBeenActivated && overviewScope.overviewOpen) {
                        overviewScope.closeOverview()
                    }
                }
            }

            Connections {
                target: overviewScope
                function onOverviewOpenChanged() {
                    if (overviewScope.overviewOpen) {
                        closing = false
                        grab.hasBeenActivated = false
                        if (CompositorService.useHyprlandFocusGrab)
                            delayedGrabTimer.start()
                    } else {
                        delayedGrabTimer.stop()
                        grab.active = false
                        grab.hasBeenActivated = false
                    }
                }
            }

            Connections {
                target: root
                function onMonitorIsFocusedChanged() {
                    if (!CompositorService.useHyprlandFocusGrab)
                        return;
                    if (overviewScope.overviewOpen && root.monitorIsFocused && !grab.active) {
                        grab.hasBeenActivated = false
                        grab.active = true
                    } else if (overviewScope.overviewOpen && !root.monitorIsFocused && grab.active) {
                        grab.active = false
                    }
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: 150
                repeat: false
                onTriggered: {
                    if (CompositorService.useHyprlandFocusGrab && overviewScope.overviewOpen && root.monitorIsFocused) {
                        grab.active = true
                    }
                }
            }

            Rectangle {
                id: background
                anchors.fill: parent
                color: "black"
                opacity: overviewScope.overviewOpen ? 0.5 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: closing ? 0 : Theme.expressiveDurations.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: overviewScope.overviewOpen ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse => {
                        const localPos = mapToItem(contentContainer, mouse.x, mouse.y)
                        if (localPos.x < 0 || localPos.x > contentContainer.width || localPos.y < 0 || localPos.y > contentContainer.height) {
                            overviewScope.closeOverview()
                        }
                    }
                }
            }

            Item {
                id: contentContainer
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 100
                width: childrenRect.width
                height: childrenRect.height

                opacity: overviewScope.overviewOpen ? 1 : 0
                transform: [scaleTransform, motionTransform]

                Scale {
                    id: scaleTransform
                    origin.x: contentContainer.width / 2
                    origin.y: contentContainer.height / 2
                    xScale: overviewScope.overviewOpen ? 1 : 0.96
                    yScale: overviewScope.overviewOpen ? 1 : 0.96

                    Behavior on xScale {
                        NumberAnimation {
                            duration: closing ? 0 : Theme.expressiveDurations.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: overviewScope.overviewOpen ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                        }
                    }

                    Behavior on yScale {
                        NumberAnimation {
                            duration: closing ? 0 : Theme.expressiveDurations.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: overviewScope.overviewOpen ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                        }
                    }
                }

                Translate {
                    id: motionTransform
                    x: 0
                    y: overviewScope.overviewOpen ? 0 : Theme.spacingL

                    Behavior on y {
                        NumberAnimation {
                            duration: closing ? 0 : Theme.expressiveDurations.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: overviewScope.overviewOpen ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: closing ? 0 : Theme.expressiveDurations.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: overviewScope.overviewOpen ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                    }
                }

                Loader {
                    id: overviewLoader
                    active: overviewScope.overviewOpen
                    asynchronous: false

                    sourceComponent: OverviewWidget {
                        panelWindow: root
                        overviewOpen: overviewScope.overviewOpen
                    }
                }

                Connections {
                    target: overviewLoader.item
                    function onCloseRequested() {
                        overviewScope.closeOverview()
                    }
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                visible: overviewScope.overviewOpen
                focus: overviewScope.overviewOpen && root.monitorIsFocused

                Keys.onEscapePressed: event => {
                    if (!root.monitorIsFocused) return
                    overviewScope.closeOverview()
                    event.accepted = true
                }

                Keys.onPressed: event => {
                    if (!root.monitorIsFocused) return
                    if (!overviewLoader.item) return

                    const thisMonitorWorkspaceIds = overviewLoader.item.thisMonitorWorkspaceIds
                    if (thisMonitorWorkspaceIds.length === 0) return

                    const activeId = root.lastDispatchedWorkspaceId !== -1 ? root.lastDispatchedWorkspaceId : (root.monitor.activeWorkspace?.id ?? thisMonitorWorkspaceIds[0])
                    const currentIndex = thisMonitorWorkspaceIds.indexOf(activeId)
                    if (currentIndex < 0) return

                    let targetIndex
                    if (event.key === Qt.Key_Left) {
                        targetIndex = currentIndex - 1
                        if (targetIndex < 0) targetIndex = thisMonitorWorkspaceIds.length - 1
                    } else if (event.key === Qt.Key_Right) {
                        targetIndex = currentIndex + 1
                        if (targetIndex >= thisMonitorWorkspaceIds.length) targetIndex = 0
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                        const columns = overviewLoader.item.effectiveColumns
                        const col = currentIndex % columns
                        if (event.key === Qt.Key_Up) {
                            targetIndex = currentIndex - columns
                            if (targetIndex < 0)
                                targetIndex = thisMonitorWorkspaceIds.length - 1 - ((thisMonitorWorkspaceIds.length - 1) % columns) + col
                        } else {
                            targetIndex = currentIndex + columns
                            if (targetIndex >= thisMonitorWorkspaceIds.length)
                                targetIndex = col
                        }
                    } else {
                        return
                    }

                    const targetId = thisMonitorWorkspaceIds[targetIndex]
                    root.lastDispatchedWorkspaceId = targetId
                    HyprlandService.focusWorkspace(targetId)
                    Hyprland.refreshWorkspaces()
                    if (CompositorService.useHyprlandFocusGrab) {
                        grab.hasBeenActivated = false
                        grab.active = false
                        Qt.callLater(() => { grab.active = true })
                    }
                    event.accepted = true
                }

                onVisibleChanged: {
                    if (visible && overviewScope.overviewOpen && root.monitorIsFocused) {
                        Qt.callLater(() => focusScope.forceActiveFocus())
                    }
                }

                Connections {
                    target: root
                    function onMonitorIsFocusedChanged() {
                        if (root.monitorIsFocused && overviewScope.overviewOpen) {
                            Qt.callLater(() => focusScope.forceActiveFocus())
                        }
                    }
                }
            }

            onVisibleChanged: {
                if (visible && overviewScope.overviewOpen) {
                    Qt.callLater(() => focusScope.forceActiveFocus())
                } else if (!visible) {
                    grab.active = false
                }
            }

            Connections {
                target: overviewScope
                function onOverviewOpenChanged() {
                    if (overviewScope.overviewOpen) {
                        closing = false
                        root.visible = true
                        root.lastDispatchedWorkspaceId = -1
                        Qt.callLater(() => focusScope.forceActiveFocus())
                    } else {
                        grab.active = false
                    }
                }
            }
        }
        }
    }
}
