pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Button {
    id: root

    property var imageData
    property var rowHeight
    property bool manualDownload: false
    property string previewDownloadPath
    property string downloadPath
    property string nsfwPath
    property string booruSavePath: FileUtils.trimFileProtocol(Paths.pictures) + "/Booru"
    property string fileName: decodeURIComponent((imageData.file_url).substring((imageData.file_url).lastIndexOf('/') + 1))
    property string filePath: `${root.previewDownloadPath}/${root.fileName}`
    property int maxTagStringLineLength: 50
    property real imageRadius: Appearance.rounding.small
    property string tooltipText: StringUtils.wordWrap(root.imageData?.tags ?? "", root.maxTagStringLineLength)
    property string tooltipSide: "bottom"

    property bool downloaded: false

    function probeImageDimensions() {
        if (root.imageData.width && root.imageData.height) return;
        if (imageObject.status === Image.Ready) {
            root.imageData.width = imageObject.sourceSize.width;
            root.imageData.height = imageObject.sourceSize.height;
            root.imageData.aspect_ratio = imageObject.sourceSize.width / imageObject.sourceSize.height;
        }
    }

    Process {
        id: imageDownloader
        running: root.manualDownload
        command: ["curl", "-sL", "-o", root.filePath, root.imageData.preview_url ?? root.imageData.sample_url]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.downloaded = true;
                imageObject.source = Qt.resolvedUrl(root.filePath);
            }
        }
    }

    Process {
        id: copyProcess

        onExited: (exitCode) => {
            if (exitCode === 0) {
                ToastService.showInfo(I18n.tr("Image copied", "booru image copied to clipboard"));
            } else {
                ToastService.showError(I18n.tr("Failed to copy image", "booru image copy failure"));
            }
        }
    }

    Process {
        id: saveProcess

        onExited: (exitCode) => {
            if (exitCode === 0) {
                ToastService.showInfo(I18n.tr("Image saved", "booru image saved to disk"));
            } else {
                ToastService.showError(I18n.tr("Failed to save image", "booru image save failure"));
            }
        }
    }

    padding: 0
    implicitWidth: root.rowHeight * root.imageData.aspect_ratio
    implicitHeight: root.rowHeight

    background: Rectangle {
        implicitWidth: root.rowHeight * root.imageData.aspect_ratio
        implicitHeight: root.rowHeight
        radius: root.imageRadius
        color: Theme.surfaceContainerHigh
    }

    contentItem: Item {
        anchors.fill: parent

        Image {
            id: imageObject
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            source: root.downloaded ? Qt.resolvedUrl(root.filePath) : (root.imageData.preview_url ?? "")
            onStatusChanged: root.probeImageDimensions()

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: imageObject.width
                    height: imageObject.height
                    radius: root.imageRadius
                }
            }
        }

        DankButton {
            id: openLinkButton
            anchors.top: parent.top
            anchors.left: parent.left
            property real buttonSize: 30
            anchors.margins: 6
            width: buttonSize
            height: buttonSize
            minWidth: 0
            horizontalPadding: 0

            radius: Appearance.rounding.full
            backgroundColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.3)
            textColor: Theme.surfaceText
            tooltipText: I18n.tr("Open image link", "Booru")
            visible: root.hovered
            opacity: visible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            contentItem: Item {
                anchors.centerIn: parent
                width: 20
                height: 20

                DankIcon {
                    anchors.centerIn: parent
                    name: "open_in_new"
                    size: Theme.fontSizeLarge
                    color: Theme.surfaceText
                }
            }

            onClicked: Qt.openUrlExternally(root.imageData.file_url)
        }

        DankButton {
            id: saveButton
            anchors.top: parent.top
            anchors.right: parent.right
            property real buttonSize: 30
            anchors.margins: 6
            width: buttonSize
            height: buttonSize
            minWidth: 0
            horizontalPadding: 0

            radius: Appearance.rounding.full
            backgroundColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.3)
            textColor: Theme.surfaceText
            tooltipText: I18n.tr("Save image", "Booru")
            visible: root.hovered
            opacity: visible ? 1 : 0
            enabled: !saveProcess.running

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            contentItem: Item {
                anchors.centerIn: parent
                width: 20
                height: 20

                DankIcon {
                    anchors.centerIn: parent
                    name: "download"
                    size: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    visible: !saveProcess.running
                }

                DankSpinner {
                    anchors.centerIn: parent
                    size: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    visible: saveProcess.running
                    running: saveProcess.running
                }
            }

            onClicked: {
                saveProcess.command = [
                    "bash", "-c",
                    `mkdir -p '${root.booruSavePath}' && curl -sL '${StringUtils.shellSingleQuoteEscape(root.imageData.file_url)}' -o '${root.booruSavePath}/${root.fileName}'`
                ];
                saveProcess.running = true;
            }
        }

        DankButton {
            id: copyButton
            anchors.top: parent.top
            anchors.right: saveButton.left
            property real buttonSize: 30
            anchors.margins: 6
            width: buttonSize
            height: buttonSize
            minWidth: 0
            horizontalPadding: 0

            radius: Appearance.rounding.full
            backgroundColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.3)
            textColor: Theme.surfaceText
            tooltipText: I18n.tr("Copy image", "Booru")
            visible: root.hovered
            opacity: visible ? 1 : 0
            enabled: !copyProcess.running

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            contentItem: Item {
                anchors.centerIn: parent
                width: 20
                height: 20

                DankIcon {
                    anchors.centerIn: parent
                    name: "content_copy"
                    size: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    visible: !copyProcess.running
                }

                DankSpinner {
                    anchors.centerIn: parent
                    size: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    visible: copyProcess.running
                    running: copyProcess.running
                }
            }

            onClicked: {
                const ext = root.fileName.split(".").pop() || "img";
                copyProcess.command = [
                    "bash", "-c",
                    `tmp="$(mktemp --suffix=.${ext})"; if curl -sL '${StringUtils.shellSingleQuoteEscape(root.imageData.file_url)}' -o "$tmp" && wl-copy < "$tmp"; then rm -f "$tmp"; exit 0; else rm -f "$tmp"; exit 1; fi`
                ];
                copyProcess.running = true;
            }
        }
    }

    DankHoverTooltip {
        target: root
        text: root.tooltipText
        side: root.tooltipSide
        multiLine: true
        maxWidth: 420
    }
}