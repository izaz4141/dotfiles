import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property int selectedMode: 0
    property int selectedTimer: 0
    property int selectedTarget: 0
    property int openDropdown: -1
    property bool dragging: false

    property real panelX: 0
    property real panelY: 0
    property int hoverButton: -1
    property int pressedButton: -1
    property alias shown: toolbar.visible

    readonly property var modeOptions: [
        { icon: "crop", label: I18n.tr("Region", "screenshot capture region") },
        { icon: "crop_landscape", label: I18n.tr("All", "screenshot entire screen") },
        { icon: "crop_free", label: I18n.tr("Active Window", "screenshot active window") }
    ]
    readonly property var timerOptions: [
        { icon: "timer_off", label: I18n.tr("Immediate", "screenshot taken immediately") },
        { icon: "timer", label: I18n.tr("3 seconds", "screenshot with 3 second delay") },
        { icon: "schedule", label: I18n.tr("5 seconds", "screenshot with 5 second delay") },
        { icon: "more_time", label: I18n.tr("10 seconds", "screenshot with 10 second delay") }
    ]
    readonly property var targetOptions: [
        { icon: "content_paste", label: I18n.tr("Clipboard", "copy screenshot to clipboard") },
        { icon: "save", label: I18n.tr("Save", "save screenshot to file") },
        { icon: "content_copy", label: I18n.tr("Both", "save and copy screenshot") }
    ]
    readonly property var timerDelays: [0, 3, 5, 10]
    readonly property var targetStrings: ["clipboard", "path", "both"]
    readonly property var modeStrings: ["region", "all", "activewindow"]

    readonly property var modeIcons: ["crop", "crop_landscape", "crop_free"]
    readonly property var timerIcons: ["timer_off", "timer", "schedule", "more_time"]
    readonly property var targetIcons: ["content_paste", "save", "content_copy"]

    readonly property real segWidth: Theme.spacingXL * 1.5
    readonly property real segHeight: Theme.spacingXL
    readonly property real rowSpacing: Theme.spacingXS
    readonly property real rowX: toolbarRow.x
    readonly property real rowY: toolbarRow.y
    readonly property real dragThreshold: Theme.spacingXS * 2

    property point pressLocalPos
    property point prevLocalPos
    property point panelStartPos
    property real dragDeltaX: 0
    property real dragDeltaY: 0
    property bool pressIsDrag: false

    function toolbarTop() {
        var screen = CompositorService.getFocusedScreen()
        var screenH = screen?.height ?? Screen.height
        return Math.max(0, screenH - toolbar.implicitHeight - Theme.barHeight - Theme.spacingM)
    }

    function show() {
        panelX = Theme.spacingM
        panelY = toolbarTop()
        toolbar.visible = true
        Qt.callLater(() => toolbarFocus.forceActiveFocus())
    }

    function hide() {
        openDropdown = -1
        toolbar.visible = false
    }

    function toggle() {
        if (toolbar.visible) hide(); else show();
    }

    function capture() {
        var mode = modeStrings[selectedMode]
        var target = targetStrings[selectedTarget]
        var delay = timerDelays[selectedTimer]
        ScreenshotService.captureDelayed(mode, target, delay)
        hide()
    }

    function buttonIndexAt(localX) {
        for (var i = 0; i < 3; i++) {
            var x0 = rowX + i * (segWidth + rowSpacing)
            if (localX >= x0 && localX <= x0 + segWidth)
                return i
        }
        var capX = rowX + 3 * (segWidth + rowSpacing) + 1 + rowSpacing
        if (localX >= capX && localX <= capX + segWidth)
            return 3
        return -1
    }

    function toggleSegment(index) {
        if (openDropdown === index) {
            openDropdown = -1
        } else {
            var segXInRoot = rowX + index * (segWidth + rowSpacing)
            openDropdown = index
            dropdown.show(segXInRoot, segWidth, segHeight)
        }
    }

    function handleClick(localX, localY) {
        var btn = buttonIndexAt(localX)
        if (btn >= 0 && btn <= 2) {
            toggleSegment(btn)
        } else if (btn === 3) {
            capture()
        } else if (openDropdown >= 0) {
            openDropdown = -1
        }
    }

    function triggerRipple(index, localX, localY) {
        if (index === 3) {
            captureRipple.trigger(localX, localY)
        } else if (index >= 0 && index <= 2) {
            var item = segmentRepeater.itemAt(index)
            if (item && item.triggerRipple)
                item.triggerRipple(localX, localY)
        }
    }

    function onPress(mouse) {
        pressLocalPos = Qt.point(mouse.x, mouse.y)
        prevLocalPos = Qt.point(mouse.x, mouse.y)
        panelStartPos = Qt.point(panelX, panelY)
        dragDeltaX = 0
        dragDeltaY = 0
        pressIsDrag = false
        dragging = false
        pressedButton = buttonIndexAt(mouse.x)
        if (pressedButton >= 0) {
            var buttonLocalY = mouse.y - rowY
            if (pressedButton === 3) {
                var capX = rowX + 3 * (segWidth + rowSpacing) + 1 + rowSpacing
                triggerRipple(3, mouse.x - capX, buttonLocalY)
            } else {
                triggerRipple(pressedButton, mouse.x - (rowX + pressedButton * (segWidth + rowSpacing)), buttonLocalY)
            }
        }
    }

    function onMove(mouse) {
        if (!interactionArea.pressed) {
            hoverButton = buttonIndexAt(mouse.x)
            return
        }
        var netX = mouse.x - pressLocalPos.x
        var netY = mouse.y - pressLocalPos.y
        if (!pressIsDrag && (Math.abs(netX) > dragThreshold || Math.abs(netY) > dragThreshold)) {
            pressIsDrag = true
            dragging = true
            pressedButton = -1
            dragDeltaX += netX
            dragDeltaY += netY
        } else if (pressIsDrag) {
            dragDeltaX += mouse.x - prevLocalPos.x
            dragDeltaY += mouse.y - prevLocalPos.y
        }
        prevLocalPos = Qt.point(mouse.x, mouse.y)
        if (pressIsDrag) {
            var screen = CompositorService.getFocusedScreen()
            var screenW = screen?.width ?? Screen.width
            var screenH = screen?.height ?? Screen.height
            panelX = Math.round(Math.max(0, Math.min(screenW - toolbar.implicitWidth, panelStartPos.x + dragDeltaX)))
            panelY = Math.round(Math.max(0, Math.min(screenH - toolbar.implicitHeight, panelStartPos.y + dragDeltaY)))
        } else {
            hoverButton = buttonIndexAt(mouse.x)
        }
    }

    function onRelease(mouse) {
        if (!pressIsDrag)
            handleClick(pressLocalPos.x, pressLocalPos.y)
        pressIsDrag = false
        dragging = false
        pressedButton = -1
        hoverButton = buttonIndexAt(mouse.x)
    }

    PanelWindow {
        id: toolbar

        WlrLayershell.namespace: "dms:screenshot-controls"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: visible ? (CompositorService.useHyprlandFocusGrab ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

        visible: false
        color: "transparent"

        implicitWidth: toolbarRow.width + Theme.spacingM * 2
        implicitHeight: toolbarRow.height + Theme.spacingS * 2

        anchors {
            top: true
            left: true
        }

        margins {
            left: root.panelX
            top: root.panelY
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Theme.surfaceContainer
            border.color: Theme.outlineMedium
            border.width: 1
        }

        MouseArea {
            id: interactionArea
            anchors.fill: parent
            hoverEnabled: true
            onHoveredChanged: root.hoverButton = containsMouse ? root.hoverButton : -1
            onExited: root.hoverButton = -1
            cursorShape: {
                if (root.dragging) return Qt.ClosedHandCursor
                if (containsMouse && root.hoverButton >= 0) return Qt.PointingHandCursor
                return Qt.OpenHandCursor
            }
            onPressed: mouse => root.onPress(mouse)
            onPositionChanged: mouse => root.onMove(mouse)
            onReleased: mouse => root.onRelease(mouse)
        }

        Row {
            id: toolbarRow
            anchors.centerIn: parent
            spacing: root.rowSpacing

            Repeater {
                id: segmentRepeater
                model: 3

                Rectangle {
                    id: segment

                    required property int index
                    property bool isOpen: root.openDropdown === index
                    property bool hovered: root.hoverButton === index && !root.dragging
                    property bool pressed: root.pressedButton === index && !root.dragging

                    width: root.segWidth
                    height: root.segHeight
                    radius: Theme.cornerRadius
                    color: {
                        if (isOpen) return Theme.buttonBg
                        if (hovered) return Theme.surfaceContainerHigh
                        return Theme.surfaceVariant
                    }
                    border.color: isOpen ? Theme.primary : "transparent"
                    border.width: isOpen ? 2 : 0

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shorterDuration
                            easing.type: Theme.standardEasing
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: {
                            if (pressed && !isOpen) return Theme.withAlpha(Theme.surfaceText, 0.20)
                            if (hovered && !isOpen) return Theme.withAlpha(Theme.surfaceText, 0.12)
                            return "transparent"
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shorterDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    DankRipple {
                        id: segmentRipple
                        rippleColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.25)
                        cornerRadius: Theme.cornerRadius
                    }

                    function triggerRipple(localX, localY) {
                        segmentRipple.trigger(localX, localY)
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: {
                            if (segment.index === 0) return root.modeIcons[root.selectedMode]
                            if (segment.index === 1) return root.timerIcons[root.selectedTimer]
                            return root.targetIcons[root.selectedTarget]
                        }
                        size: Theme.iconSize
                        color: isOpen ? Theme.buttonText : Theme.surfaceText
                    }
                }
            }

            Rectangle {
                width: 1
                height: root.segHeight
                color: Theme.outlineMedium
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                id: captureButton

                width: root.segWidth
                height: root.segHeight
                radius: Theme.cornerRadius
                color: Theme.primary
                scale: (root.pressedButton === 3 && !root.dragging) ? 0.94 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: {
                        if (root.pressedButton === 3 && !root.dragging) return Theme.withAlpha(Theme.surfaceText, 0.20)
                        if (root.hoverButton === 3 && !root.dragging) return Theme.withAlpha(Theme.surfaceText, 0.12)
                        return "transparent"
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shorterDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }

                DankRipple {
                    id: captureRipple
                    rippleColor: Theme.withAlpha(Theme.surfaceText, 0.25)
                    cornerRadius: Theme.cornerRadius
                }

                DankIcon {
                    anchors.centerIn: parent
                    name: "photo_camera"
                    size: Theme.iconSize
                    color: Theme.buttonText
                }
            }
        }

        FocusScope {
            id: toolbarFocus
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: event => {
                if (root.openDropdown >= 0) {
                    root.openDropdown = -1
                } else {
                    root.hide()
                }
                event.accepted = true
            }
        }
    }

    PanelWindow {
        id: dropdown

        WlrLayershell.namespace: "dms:screenshot-controls-dropdown"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: -1

        visible: root.openDropdown >= 0
        color: "transparent"

        property real dropdownX: 0
        property real dropdownY: 0
        property real dropdownWidth: Theme.spacingXL * 6

        function show(segX, segW, segH) {
            dropdownX = root.panelX + segX + (segW - dropdownWidth) / 2
            dropdownY = root.panelY + toolbar.implicitHeight + Theme.spacingXS
        }

        implicitWidth: dropdownWidth
        implicitHeight: dropdownColumn.implicitHeight + Theme.spacingS * 2

        anchors {
            top: true
            left: true
        }

        margins {
            left: {
                var screen = CompositorService.getFocusedScreen()
                var screenW = screen?.width ?? Screen.width
                return Math.round(Math.max(Theme.spacingS, Math.min(screenW - implicitWidth - Theme.spacingS, dropdownX)))
            }
            top: {
                var screen = CompositorService.getFocusedScreen()
                var screenH = screen?.height ?? Screen.height
                var val = dropdownY
                if (val + implicitHeight > screenH - Theme.spacingS)
                    val = root.panelY - implicitHeight - Theme.spacingXS
                return Math.round(Math.max(Theme.spacingS, val))
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Theme.surfaceContainer
            border.color: Theme.outlineMedium
            border.width: 1
        }

        Column {
            id: dropdownColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: Theme.spacingS
            anchors.leftMargin: Theme.spacingS
            width: parent.width - Theme.spacingS * 2
            spacing: 2

            Repeater {
                model: ScriptModel {
                    values: {
                        if (root.openDropdown === 0) return root.modeOptions
                        if (root.openDropdown === 1) return root.timerOptions
                        if (root.openDropdown === 2) return root.targetOptions
                        return []
                    }
                }

                Rectangle {
                    id: optionDelegate

                    required property var modelData
                    required property int index

                    property bool isSelected: {
                        if (root.openDropdown === 0) return root.selectedMode === index
                        if (root.openDropdown === 1) return root.selectedTimer === index
                        if (root.openDropdown === 2) return root.selectedTarget === index
                        return false
                    }

                    width: dropdownColumn.width
                    height: Theme.spacingL + Theme.spacingS
                    radius: Theme.cornerRadius
                    color: isSelected ? Theme.primaryHoverLight : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shorterDuration
                            easing.type: Theme.standardEasing
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: {
                            if (optionArea.pressed) return Theme.withAlpha(Theme.surfaceText, 0.20)
                            if (optionArea.containsMouse) return Theme.withAlpha(Theme.surfaceText, 0.12)
                            return "transparent"
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shorterDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: optionDelegate.modelData.icon
                            size: Theme.iconSizeSmall
                            color: isSelected ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: optionDelegate.modelData.label
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: isSelected ? Font.Medium : Font.Normal
                            color: isSelected ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.iconSizeSmall - Theme.spacingS
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: optionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.openDropdown === 0)
                                root.selectedMode = index
                            else if (root.openDropdown === 1)
                                root.selectedTimer = index
                            else if (root.openDropdown === 2)
                                root.selectedTarget = index
                            root.openDropdown = -1
                        }
                    }
                }
            }
        }

        Keys.onEscapePressed: event => {
            root.openDropdown = -1
            event.accepted = true
        }
    }
}