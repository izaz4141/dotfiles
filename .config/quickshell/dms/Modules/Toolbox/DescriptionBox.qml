import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Item {
    id: root

    property alias text: tagDescriptionText.text
    property bool showArrows: true
    property bool showTab: true

    visible: tagDescriptionText.text.length > 0
    Layout.fillWidth: true
    implicitHeight: tagDescriptionBackground.implicitHeight

    Rectangle {
        id: tagDescriptionBackground
        anchors.fill: parent
        color: Theme.surfaceContainerHigh
        radius: Math.max(4, Appearance.rounding.small - 4)
        implicitHeight: descriptionRow.implicitHeight + 10

        RowLayout {
            id: descriptionRow
            spacing: 4
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 10
            }

            StyledText {
                id: tagDescriptionText
                Layout.fillWidth: true
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                wrapMode: Text.Wrap
            }

            KeyHint {
                visible: root.showArrows
                key: "↑"
            }

            KeyHint {
                visible: root.showArrows
                key: "↓"
            }

            StyledText {
                visible: root.showArrows && root.showTab
                text: I18n.tr("or", "AiChat interface")
                font.pixelSize: Theme.fontSizeSmall
            }

            KeyHint {
                visible: root.showTab
                key: "Tab"
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}