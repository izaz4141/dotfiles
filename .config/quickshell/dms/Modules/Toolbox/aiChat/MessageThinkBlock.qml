pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Widgets

Item {
    id: root

    property bool editing: false
    property bool renderMarkdown: true
    property bool enableMouseSelection: false
    property var segmentContent: ""
    property var messageData: ({})
    property bool done: true
    property bool completed: false

    property bool largeCollapse: messageTextBlock.implicitHeight > 40
    property bool collapsed: true

    Layout.fillWidth: true
    implicitHeight: collapsed ? header.implicitHeight : columnLayout.implicitHeight
    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: Appearance.rounding.small
        }
    }

    Behavior on implicitHeight {
        enabled: root.completed
        NumberAnimation {
            duration: root.largeCollapse ? Appearance.anim.durations.normal : Appearance.anim.durations.quick
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.largeCollapse ? Appearance.anim.curves.emphasizedDecel : Appearance.anim.curves.standardAccel
        }
    }

    ColumnLayout {
        id: columnLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        Rectangle {
            id: header
            color: Theme.surfaceContainerHighest
            Layout.fillWidth: true
            implicitHeight: thinkBlockTitleBarRowLayout.implicitHeight + 6

            MouseArea {
                id: headerMouseArea
                enabled: root.completed
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.collapsed = !root.collapsed
            }

            RowLayout {
                id: thinkBlockTitleBarRowLayout
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    right: parent.right
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 10

                DankIcon {
                    Layout.alignment: Qt.AlignVCenter
                    name: "hub"
                    size: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    id: thinkBlockLanguage
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignVCenter
                    text: root.completed ? I18n.tr("Thought", "AiChat interface") :
                        (I18n.tr("Thinking", "AiChat interface") + ".".repeat(Math.random() * 4))
                    color: Theme.surfaceText
                }

                Item {
                    Layout.fillWidth: true
                }

                DankButton {
                    id: expandButton
                    visible: root.completed
                    width: 22
                    height: 22
                    minWidth: 0
                    horizontalPadding: 0
                    radius: Appearance.rounding.small
                    backgroundColor: headerMouseArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                    textColor: Theme.surfaceText

                    onClicked: root.collapsed = !root.collapsed

                    contentItem: DankIcon {
                        anchors.centerIn: parent
                        name: "keyboard_arrow_down"
                        size: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        rotation: root.collapsed ? 0 : 180

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Appearance.anim.durations.quick
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.anim.curves.standard
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: content
            Layout.fillWidth: true
            implicitHeight: collapsed ? 0 : contentBackground.implicitHeight + 2
            clip: true

            Behavior on implicitHeight {
                enabled: root.completed
                NumberAnimation {
                    duration: root.largeCollapse ? Appearance.anim.durations.normal : Appearance.anim.durations.quick
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.largeCollapse ? Appearance.anim.curves.emphasizedDecel : Appearance.anim.curves.standardAccel
                }
            }

            Rectangle {
                id: contentBackground
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: messageTextBlock.implicitHeight
                color: Theme.surfaceContainerHigh

                property bool editing: root.editing
                property bool renderMarkdown: root.renderMarkdown
                property bool enableMouseSelection: root.enableMouseSelection
                property var messageData: root.messageData
                property bool done: root.done

                MessageTextBlock {
                    id: messageTextBlock
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    editing: root.editing
                    renderMarkdown: root.renderMarkdown
                    enableMouseSelection: root.enableMouseSelection
                    messageData: root.messageData
                    done: root.done
                    segmentContent: root.segmentContent
                }
            }
        }
    }
}