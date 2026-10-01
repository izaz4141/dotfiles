import qs.Common
import qs.Widgets
import QtQuick

DankButton {
    id: root
    required property var element
    opacity: element.type != "empty" ? 1 : 0
    implicitHeight: 70
    implicitWidth: 70
    backgroundColor: Theme.surfaceContainerHigh
    radius: Theme.cornerRadius

    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            topMargin: 4
            leftMargin: 4
        }
        color: "transparent"
        radius: Theme.cornerRadius
        implicitWidth: Math.max(20, elementNumber.implicitWidth)
        implicitHeight: Math.max(20, elementNumber.implicitHeight)
        width: height

        StyledText {
            id: elementNumber
            anchors.left: parent.left
            color: Theme.surfaceText
            text: root.element.number
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    Rectangle {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 4
            rightMargin: 4
        }
        color: "transparent"
        radius: Theme.cornerRadius
        implicitWidth: Math.max(20, elementWeight.implicitWidth)
        implicitHeight: Math.max(20, elementWeight.implicitHeight)
        width: height

        StyledText {
            id: elementWeight
            anchors.right: parent.right
            color: Theme.surfaceText
            text: root.element.weight
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    StyledText {
        id: elementSymbol
        anchors.centerIn: parent
        color: Theme.secondary
        font.pixelSize: Theme.fontSizeXLarge
        text: root.element.symbol
    }

    StyledText {
        id: elementName
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 4
        }
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceText
        text: root.element.name
    }
}
