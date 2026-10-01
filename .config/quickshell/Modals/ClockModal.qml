import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modules.Clock
import qs.Widgets

FloatingWindow {
    id: root

    property bool disablePopupTransparency: true
    property alias shouldBeVisible: root.visible

    signal closingModal

    function show() {
        visible = true;
    }

    function hide() {
        visible = false;
    }

    function toggle() {
        visible = !visible;
    }

    objectName: "clockModal"
    title: I18n.tr("Clock", "clock window title")
    minimumSize: Qt.size(400, 500)
    implicitWidth: 460
    implicitHeight: 620
    color: Theme.surfaceContainer
    visible: false

    onClosed: visible = false

    onVisibleChanged: {
        if (!visible)
            closingModal();
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        Keys.onEscapePressed: root.hide()

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Theme.fontSizeMedium * 3.4)

                MouseArea {
                    anchors.fill: parent
                    onPressed: (e) => windowControls.tryStartMove(e)
                    onDoubleClicked: windowControls.tryToggleMaximize()
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingL
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "schedule"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Clock")
                        font.pixelSize: Theme.fontSizeXLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                DankActionButton {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    circular: false
                    iconName: "close"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: root.hide()
                }
            }

            ClockApp {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Theme.spacingL
                Layout.rightMargin: Theme.spacingL
                Layout.topMargin: Theme.spacingM
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }
}
