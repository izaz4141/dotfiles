import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Button {
    id: root

    property string iconName: ""
    property int iconSize: Theme.iconSizeSmall
    property int textSize: Theme.fontSizeMedium
    property bool enableScaleAnimation: false
    property bool enableRipple: typeof SettingsData !== "undefined" ? (SettingsData.enableRippleEffects ?? true) : true
    padding: 0

    property color backgroundColor: Theme.buttonBg
    property color textColor: Theme.buttonText
    property color toggledBackgroundColor: Theme.primary
    property color toggledTextColor: Theme.primaryText
    property bool toggled: false

    property int buttonHeight: 40
    property real vPadding: 6
    property int minWidth: 64
    property real radius: Theme.cornerRadius
    property real radiusPressed: root.radius

    property bool expandOnPress: false
    property real expandOffset: 20
    readonly property real baseWidth: Math.max(root.contentItem.implicitWidth + root.horizontalPadding * 2, root.minWidth)
    readonly property real clickedWidth: root.baseWidth + root.expandOffset

    property bool pointingHandCursor: true
    property var downAction
    property var releaseAction
    property var altAction
    property var middleClickAction
    property string tooltipText: ""
    property string tooltipSide: ""

    property var parentGroup: root.parent
    property int indexInParent: parentGroup ? parentGroup.children.indexOf(root) : -1
    property int clickIndex: parentGroup && parentGroup.clickIndex !== undefined ? parentGroup.clickIndex : -1

    readonly property bool _inGroup: root.expandOnPress && root.parentGroup && root.parentGroup.clickIndex !== undefined

    Layout.fillWidth: root._inGroup ? (root.clickIndex - 1 <= root.indexInParent && root.indexInParent <= root.clickIndex + 1) : false

    width: root.implicitWidth
    height: root.implicitHeight
    implicitWidth: root._inGroup ? (root.down ? root.clickedWidth : root.baseWidth) : root.baseWidth
    implicitHeight: Math.max(root.contentItem.implicitHeight + root.vPadding * 2, root.buttonHeight)

    opacity: root.enabled ? 1 : 0.4

    scale: (root.enableScaleAnimation && root.down) ? 0.98 : 1.0
    Behavior on scale {
        enabled: root.enableScaleAnimation && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
        DankAnim {
            duration: 100
            easing.bezierCurve: Theme.expressiveCurves.standard
        }
    }

    Behavior on implicitWidth {
        enabled: root._inGroup
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    background: Rectangle {
        id: backgroundRect
        radius: root.down ? root.radiusPressed : root.radius
        color: root.toggled ? root.toggledBackgroundColor : root.backgroundColor

        Behavior on color {
            ColorAnimation {
                duration: Theme.shorterDuration
                easing.type: Theme.standardEasing
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: _stateLayerColor()

            function _stateLayerColor() {
                if (!root.enabled)
                    return "transparent";
                const overlay = root.toggled ? root.toggledTextColor : root.textColor;
                if (root.down)
                    return Qt.rgba(overlay.r, overlay.g, overlay.b, 0.20);
                if (root.hovered)
                    return Qt.rgba(overlay.r, overlay.g, overlay.b, 0.12);
                return "transparent";
            }
        }
    }

    contentItem: Item {
        id: contentItemWrapper
        anchors.fill: parent
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankIcon {
                id: buttonIconDank
                anchors.verticalCenter: parent.verticalCenter
                visible: root.iconName !== ""
                name: root.iconName
                size: root.iconSize
                color: root.toggled ? root.toggledTextColor : root.textColor
            }

            StyledText {
                id: buttonTextStyled
                anchors.verticalCenter: parent.verticalCenter
                visible: root.text !== ""
                text: root.text
                font.pixelSize: root.textSize
                font.weight: Font.Medium
                color: root.toggled ? root.toggledTextColor : root.textColor
            }
        }
    }

    DankRipple {
        id: rippleLayer
        anchors.fill: backgroundRect
        rippleColor: root.toggled ? root.toggledTextColor : root.textColor
        cornerRadius: root.radius
        enableRipple: root.enableRipple
    }

    MouseArea {
        id: buttonMouseArea
        anchors.fill: parent
        cursorShape: root.pointingHandCursor && root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: true
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) {
                if (root.middleClickAction) root.middleClickAction();
                return;
            }
            if (event.button === Qt.RightButton) {
                if (root.altAction) root.altAction();
                return;
            }
            root.down = true;
            if (root.enableRipple)
                rippleLayer.trigger(event.x, event.y);
            if (root._inGroup)
                root.parentGroup.clickIndex = root.indexInParent;
            if (root.downAction) root.downAction();
        }

        onReleased: (event) => {
            root.down = false;
            if (event.button !== Qt.LeftButton) return;
            root.click();
            if (root.releaseAction) root.releaseAction();
        }

        onCanceled: root.down = false
    }

    DankHoverTooltip {
        target: root
        text: root.tooltipText
        side: root.tooltipSide
    }
}