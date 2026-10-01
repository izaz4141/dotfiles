pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    signal remove()

    property bool canRemove: true
    property string filePath: ""
    property string mimeType: ""
    property real maxHeight: 200
    property real imageWidth: -1
    property real imageHeight: -1
    property real scale: Math.min(root.maxHeight / imageHeight, root.width / imageWidth)

    onFilePathChanged: refresh()
    visible: filePath !== ""

    function refresh() {
        root.mimeType = "";
        root.imageWidth = -1;
        root.imageHeight = -1;
        fileTypeProc.exec(["file", "-b", "--mime-type", root.filePath]);
    }

    Process {
        id: fileTypeProc
        command: ["file", "-b", "--mime-type", root.filePath]
        stdout: StdioCollector {
            onStreamFinished: {
                root.mimeType = text.trim();
                if (root.mimeType.startsWith("image/"))
                    imageSizeProc.exec(["identify", "-format", "%wx%h", root.filePath]);
            }
        }
    }

    Process {
        id: imageSizeProc
        command: ["identify", "-format", "%wx%h", root.filePath]
        stdout: StdioCollector {
            onStreamFinished: {
                const dimensions = text.trim().split("x");
                root.imageWidth = parseInt(dimensions[0]);
                root.imageHeight = parseInt(dimensions[1]);
            }
        }
    }

    property real horizontalPadding: 10
    property real verticalPadding: 10

    radius: Math.max(4, Appearance.rounding.small - 4)
    color: Theme.surfaceContainerHigh
    implicitHeight: visible ? (contentItem.implicitHeight + verticalPadding * 2) : 0

    ColumnLayout {
        id: contentItem
        anchors {
            fill: parent
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
        }

        RowLayout {
            spacing: 8

            DankIcon {
                Layout.alignment: Qt.AlignTop
                name: {
                    if (root.mimeType.startsWith("image/"))
                        return "image";
                    if (root.mimeType.startsWith("audio/"))
                        return "music_note";
                    if (root.mimeType.startsWith("video/"))
                        return "movie";
                    if (root.mimeType === "application/pdf")
                        return "picture_as_pdf";
                    if (root.mimeType.startsWith("text/"))
                        return "description";
                    return "file_present";
                }
                size: Theme.fontSizeXLarge
                color: Theme.surfaceVariantText
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 4
                text: root.filePath
                font.pixelSize: Theme.fontSizeSmall
                isMonospace: true
                wrapMode: Text.Wrap
            }

            DankButton {
                visible: root.canRemove
                Layout.alignment: Qt.AlignTop
                width: 28
                height: 28
                minWidth: 0
                horizontalPadding: 0
                radius: Appearance.rounding.full
                backgroundColor: Theme.surfaceContainerHigh
                textColor: Theme.surfaceVariantText

                contentItem: DankIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: Theme.fontSizeLarge
                    color: Theme.surfaceVariantText
                }

                onClicked: root.remove()
            }
        }

        Loader {
            id: imagePreviewLoader
            visible: (root.imageWidth != -1) && (root.imageHeight != -1)
            Layout.alignment: Qt.AlignHCenter

            sourceComponent: Item {
                implicitHeight: root.imageHeight * root.scale
                implicitWidth: imagePreview.implicitWidth

                Image {
                    id: imagePreview
                    anchors.fill: parent
                    source: root.filePath ? Qt.resolvedUrl(root.filePath) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize.width: Math.round(root.imageWidth * root.scale)
                    sourceSize.height: Math.round(root.imageHeight * root.scale)

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: imagePreview.width
                            height: imagePreview.height
                            radius: Appearance.rounding.normal
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.outlineVariant
                    radius: Appearance.rounding.normal
                }
            }
        }
    }
}