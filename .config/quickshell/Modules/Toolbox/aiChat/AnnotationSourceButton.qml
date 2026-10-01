import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

DankButton {
    id: root

    property string displayText
    property string url

    property real faviconSize: 20

    height: 30
    minWidth: 0
    horizontalPadding: 8
    radius: Appearance.rounding.full
    backgroundColor: Theme.surfaceContainerHighest
    textColor: Theme.surfaceText

    onClicked: {
        if (url)
            Qt.openUrlExternally(url)
    }

    contentItem: Item {
        anchors.fill: parent
        clip: true

        RowLayout {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 5

            Loader {
                id: faviconLoader
                active: root.url !== ""
                sourceComponent: Favicon {
                    url: root.url
                    size: root.faviconSize
                    displayText: root.displayText
                }
            }

            Rectangle {
                id: fallbackCircle
                visible: !faviconLoader.active
                width: root.faviconSize
                height: root.faviconSize
                radius: width / 2
                color: Theme.primaryContainer

                StyledText {
                    anchors.centerIn: parent
                    text: root.displayText ? root.displayText.charAt(0).toUpperCase() : "?"
                    color: Theme.primary
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            StyledText {
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.NoWrap
                text: root.displayText
                color: Theme.surfaceText
            }
        }
    }
}