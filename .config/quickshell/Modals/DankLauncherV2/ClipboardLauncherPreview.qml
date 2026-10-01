pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var entry: null
    property string cachedImageData: ""
    property string cachedMimeType: ""
    property var _requestedEntryId: null

    readonly property int entryId: ClipboardService.getEntryId(entry)
    readonly property string entryType: ClipboardService.getEntryType(entry)
    readonly property bool canLoadImage: typeof entry === "string" && entryType === "image"
    readonly property string sourceUrl: resolvedSourceUrl(cachedImageData, cachedMimeType)

    radius: Math.max(6, Theme.cornerRadius - 2)
    clip: true
    color: Theme.surfaceContainerHigh
    border.color: Theme.withAlpha(Theme.outline, 0.16)
    border.width: 1

    onEntryChanged: reloadPreview()
    Component.onCompleted: reloadPreview()

    function isImageMimeType(mimeType) {
        return (mimeType || "").toString().toLowerCase().startsWith("image/");
    }

    function resolvedSourceUrl(data, mimeType) {
        const rawData = (data || "").toString();
        if (rawData.length === 0)
            return "";
        if (rawData.startsWith("data:"))
            return rawData.startsWith("data:image/") ? rawData : "";
        if (!isImageMimeType(mimeType))
            return "";
        return "data:" + mimeType + ";base64," + rawData;
    }

    function reloadPreview() {
        if (!canLoadImage || entryId < 0) {
            _requestedEntryId = null;
            cachedImageData = "";
            cachedMimeType = "";
            return;
        }
        if (entryId === _requestedEntryId)
            return;

        cachedImageData = "";
        cachedMimeType = "";
        const requestId = entryId;
        _requestedEntryId = requestId;
        ClipboardService.getEntryDataUrl(requestId, (mime, b64) => {
            if (_requestedEntryId !== requestId)
                return;
            if (!mime || !b64) {
                _requestedEntryId = null;
                ClipboardService.refresh();
                return;
            }
            cachedMimeType = mime;
            cachedImageData = b64;
        });
    }

    Image {
        id: previewImage
        anchors.fill: parent
        source: root.sourceUrl
        asynchronous: true
        cache: false
        smooth: true
        sourceSize.width: 128
        sourceSize.height: 128
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
    }

    DankIcon {
        anchors.centerIn: parent
        name: "image"
        size: Math.min(22, Math.max(16, root.height * 0.46))
        color: Theme.primary
        visible: previewImage.status !== Image.Ready
    }
}
