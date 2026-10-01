pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Toolbox.booru

Rectangle {
    id: root

    property var responseData
    property var tagInputField

    property string previewDownloadPath
    property string downloadPath
    property string nsfwPath

    property real availableWidth: parent ? parent.width : 0
    property real rowTooShortThreshold: 190
    property real imageSpacing: 5
    property real responsePadding: 5

    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    implicitHeight: columnLayout.implicitHeight + root.responsePadding * 2

    Component.onCompleted: {
        availableWidth = parent.width;
    }

    Connections {
        target: parent
        function onWidthChanged() {
            updateWidthTimer.restart();
        }
    }

    Timer {
        id: updateWidthTimer
        interval: 100
        onTriggered: availableWidth = parent.width
    }

    radius: Theme.cornerRadius
    color: Theme.surfaceContainer

    property var imageRows: {
        const responseList = root.responseData.images || [];
        let i = 0;
        let rows = [];
        const minRowHeight = root.rowTooShortThreshold;
        const availableImageWidth = root.availableWidth - root.imageSpacing - (root.responsePadding * 2);

        while (i < responseList.length) {
            let row = {
                height: 0,
                images: []
            };
            let j = i;
            let combinedAspect = 0;
            let rowHeight = 0;

            while (j < responseList.length) {
                combinedAspect += responseList[j].aspect_ratio;
                let imagesInRow = j - i + 1;
                let totalSpacing = root.imageSpacing * (imagesInRow - 1);
                let rowAvailableWidth = availableImageWidth - totalSpacing;
                rowHeight = rowAvailableWidth / combinedAspect;
                if (rowHeight < minRowHeight) {
                    combinedAspect -= responseList[j].aspect_ratio;
                    imagesInRow -= 1;
                    totalSpacing = root.imageSpacing * (imagesInRow - 1);
                    rowAvailableWidth = availableImageWidth - totalSpacing;
                    rowHeight = rowAvailableWidth / combinedAspect;
                    break;
                }
                j++;
            }

            if (j === i) {
                row.images.push(responseList[i]);
                row.height = availableImageWidth / responseList[i].aspect_ratio;
                rows.push(row);
                i++;
            } else {
                for (let k = i; k < j; k++) {
                    row.images.push(responseList[k]);
                }
                let imagesInRow = j - i;
                let totalSpacing = root.imageSpacing * (imagesInRow - 1);
                let rowAvailableWidth = availableImageWidth - totalSpacing;
                row.height = rowAvailableWidth / combinedAspect;
                rows.push(row);
                i = j;
            }
        }
        return rows;
    }

    ColumnLayout {
        id: columnLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.responsePadding
        spacing: root.imageSpacing

        RowLayout {
            Rectangle {
                id: providerNameWrapper
                color: Theme.primaryContainer
                radius: Appearance.rounding.small
                implicitWidth: providerName.implicitWidth + 20
                implicitHeight: Math.max(providerName.implicitHeight + 10, 30)
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    id: providerName
                    anchors.centerIn: parent
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.primary
                    text: Booru.providers[root.responseData.provider]?.name ?? root.responseData.provider
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Item {
                visible: root.responseData.page != "" && root.responseData.page > 0
                implicitWidth: Math.max(pageNumber.implicitWidth + 20, 30)
                implicitHeight: pageNumber.implicitHeight + 10
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    id: pageNumber
                    anchors.centerIn: parent
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    text: I18n.tr("Page %1", "Booru").arg(root.responseData.page)
                }
            }
        }

        Flickable {
            id: tagsFlickable
            visible: root.responseData.tags.length > 0
            Layout.alignment: Qt.AlignLeft
            Layout.fillWidth: true
            implicitHeight: tagRowLayout.implicitHeight
            contentWidth: tagRowLayout.implicitWidth

            clip: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: tagsFlickable.width
                    height: tagsFlickable.height
                    radius: Appearance.rounding.small
                }
            }

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }

            RowLayout {
                id: tagRowLayout
                Layout.alignment: Qt.AlignBottom

                Repeater {
                    id: tagRepeater
                    model: root.responseData.tags

                    DankButton {
                        required property var modelData
                        Layout.fillWidth: false
                        expandOnPress: false
                        minWidth: 0
                        horizontalPadding: 8
                        vPadding: 4
                        buttonHeight: 30
                        radius: Appearance.rounding.small
                        backgroundColor: Theme.surfaceContainerHigh
                        textColor: Theme.surfaceText
                        text: modelData
                        textSize: Theme.fontSizeSmall
                        onClicked: {
                            if (root.tagInputField.text.length !== 0)
                                root.tagInputField.text += " ";
                            root.tagInputField.text += modelData;
                        }
                    }
                }
            }
        }

        StyledText {
            id: messageText
            Layout.fillWidth: true
            visible: root.responseData.message.length > 0
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            text: root.responseData.message
            wrapMode: Text.WordWrap
            Layout.margins: root.responsePadding
            textFormat: Text.MarkdownText
            onLinkActivated: (link) => Qt.openUrlExternally(link)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }

        DankSpinner {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            Layout.bottomMargin: 8
            size: Theme.fontSizeXLarge
            running: root.responseData.images.length === 0 && !root.responseData.done
            visible: running
        }

        Repeater {
            model: root.imageRows

            delegate: RowLayout {
                id: imageRow
                required property var modelData
                property var rowHeight: modelData.height
                spacing: root.imageSpacing

                Repeater {
                    model: imageRow.modelData.images

                    delegate: BooruImage {
                        required property var modelData
                        imageData: modelData
                        rowHeight: imageRow.rowHeight
                        imageRadius: Appearance.rounding.normal
                        manualDownload: ["danbooru", "waifu.im", "t.alcy.cc", "konachan"].includes(root.responseData.provider)
                        previewDownloadPath: root.previewDownloadPath
                        downloadPath: root.downloadPath
                        nsfwPath: root.nsfwPath
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 5

            DankButton {
                id: prevPageButton
                visible: root.responseData.page != "" && root.responseData.page > 0
                enabled: root.responseData.done && root.responseData.page > 1
                width: 30
                height: 30
                minWidth: 0
                horizontalPadding: 0
                radius: Appearance.rounding.full
                backgroundColor: Theme.surfaceContainerHigh
                textColor: Theme.surfaceText
                tooltipText: I18n.tr("Previous page", "Booru")

                onClicked: Booru.prevPage(root.responseData)

                contentItem: Item {
                    anchors.centerIn: parent
                    width: 24
                    height: 24

                    DankIcon {
                        anchors.centerIn: parent
                        name: "chevron_left"
                        size: Theme.fontSizeLarge
                        color: Theme.surfaceText
                    }
                }
            }

            DankButton {
                id: nextPageButton
                visible: root.responseData.page != "" && root.responseData.page > 0
                enabled: root.responseData.done
                width: 30
                height: 30
                minWidth: 0
                horizontalPadding: 0
                radius: Appearance.rounding.full
                backgroundColor: Theme.surfaceContainerHigh
                textColor: Theme.surfaceText
                tooltipText: I18n.tr("Next page", "Booru")

                onClicked: Booru.nextPage(root.responseData)

                contentItem: Item {
                    anchors.centerIn: parent
                    width: 24
                    height: 24

                    DankIcon {
                        anchors.centerIn: parent
                        name: "chevron_right"
                        size: Theme.fontSizeLarge
                        color: Theme.surfaceText
                    }
                }
            }
        }
    }
}