import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.Clipboard

Item {
    id: thumbnail

    required property string entryData
    required property string entryType
    required property var modal
    required property var listView
    required property int itemIndex

    Image {
        id: thumbnailImage

        property bool isVisible: false
        property string cachedImageData: ""
        property string cachedMimeType: ""
        property bool loadQueued: false
        property bool loadInProgress: false

        anchors.fill: parent
        source: ""
        fillMode: Image.PreserveAspectCrop
        smooth: true
        cache: false
        visible: false
        asynchronous: true
        sourceSize.width: 128
        sourceSize.height: 128

        onCachedImageDataChanged: refreshSource()
        onCachedMimeTypeChanged: refreshSource()

        function refreshSource() {
            const rawData = cachedImageData || ""
            let url = ""
            if (rawData.length > 0 && cachedMimeType && cachedMimeType.startsWith("image/")) {
                url = `data:${cachedMimeType};base64,${rawData}`
            }
            source = ""
            source = url
        }

        function tryLoadImage() {
            if (!loadQueued && entryType === "image" && !cachedImageData) {
                loadQueued = true
                if (modal.activeImageLoads < modal.maxConcurrentLoads) {
                    modal.activeImageLoads++
                    startImageLoad()
                } else {
                    retryTimer.restart()
                }
            }
        }

        function startImageLoad() {
            if (!loadQueued || loadInProgress)
                return
            loadInProgress = true
            const requestId = ClipboardService.getEntryId(entryData)
            if (requestId < 0) {
                loadInProgress = false
                loadQueued = false
                if (modal.activeImageLoads > 0)
                    modal.activeImageLoads--
                return
            }
            ClipboardService.getEntryDataUrl(requestId, (mime, b64) => {
                loadInProgress = false
                loadQueued = false
                if (modal.activeImageLoads > 0)
                    modal.activeImageLoads--
                if (mime && b64 && mime.startsWith("image/")) {
                    cachedMimeType = mime
                    cachedImageData = b64
                }
            })
        }

        Timer {
            id: retryTimer
            interval: ClipboardConstants.retryInterval
            onTriggered: {
                if (thumbnailImage.loadQueued && !thumbnailImage.loadInProgress) {
                    if (modal.activeImageLoads < modal.maxConcurrentLoads) {
                        modal.activeImageLoads++
                        thumbnailImage.startImageLoad()
                    } else {
                        retryTimer.restart()
                    }
                }
            }
        }

        Component.onCompleted: {
            if (entryType !== "image") {
                return
            }

            // Check if item is visible on screen initially
            const itemY = itemIndex * (ClipboardConstants.itemHeight + listView.spacing)
            const viewTop = listView.contentY
            const viewBottom = viewTop + listView.height
            isVisible = (itemY + ClipboardConstants.itemHeight >= viewTop && itemY <= viewBottom)

            if (isVisible) {
                tryLoadImage()
            }
        }

        Connections {
            target: listView
            function onContentYChanged() {
                if (entryType !== "image") {
                    return
                }

                const itemY = itemIndex * (ClipboardConstants.itemHeight + listView.spacing)
                const viewTop = listView.contentY - ClipboardConstants.viewportBuffer
                const viewBottom = viewTop + listView.height + ClipboardConstants.extendedBuffer
                const nowVisible = (itemY + ClipboardConstants.itemHeight >= viewTop && itemY <= viewBottom)

                if (nowVisible && !thumbnailImage.isVisible) {
                    thumbnailImage.isVisible = true
                    thumbnailImage.tryLoadImage()
                }
            }
        }
    }

    // Rounded mask effect for images
    MultiEffect {
        anchors.fill: parent
        anchors.margins: 2
        source: thumbnailImage
        maskEnabled: true
        maskSource: clipboardCircularMask
        visible: entryType === "image" && thumbnailImage.status === Image.Ready && thumbnailImage.source != ""
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Item {
        id: clipboardCircularMask
        width: ClipboardConstants.thumbnailSize - 4
        height: ClipboardConstants.thumbnailSize - 4
        layer.enabled: true
        layer.smooth: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "black"
            antialiasing: true
        }
    }

    // Fallback icon
    DankIcon {
        visible: !(entryType === "image" && thumbnailImage.status === Image.Ready && thumbnailImage.source != "")
        name: {
            if (entryType === "image") {
                return "image"
            }
            if (entryType === "long_text") {
                return "subject"
            }
            return "content_copy"
        }
        size: Theme.iconSize
        color: Theme.primary
        anchors.centerIn: parent
    }
}
