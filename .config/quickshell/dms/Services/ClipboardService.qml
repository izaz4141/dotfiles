pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals.Clipboard

Singleton {
    id: root

    property bool clipboardAvailable: false

    property alias model: listModel
    property alias filteredModel: filteredClipboardModel
    property string searchText: ""
    property int totalCount: 0
    property int selectedIndex: 0
    property bool keyboardNavigationActive: false

    property string pasteTool: ""

    signal entriesLoaded

    ListModel {
        id: listModel
    }

    ListModel {
        id: filteredClipboardModel
    }

    Process {
        id: clipboardProbe
        command: ["sh", "-c", "command -v cliphist"]
        running: false

        onExited: exitCode => {
            root.clipboardAvailable = (exitCode === 0);
        }
    }

    Process {
        id: listProcess
        command: ["cliphist", "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                listModel.clear()
                const lines = text.trim().split('\n')
                for (const line of lines) {
                    if (line.trim().length > 0) {
                        listModel.append({
                            "entry": line
                        })
                    }
                }
                root.updateFilteredModel()
                root.entriesLoaded()
            }
        }
    }

    Process {
        id: deleteProcess
        property string deletedEntry: ""
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                for (var i = 0; i < listModel.count; i++) {
                    if (listModel.get(i).entry === deleteProcess.deletedEntry) {
                        listModel.remove(i)
                        break
                    }
                }
                for (var j = 0; j < filteredClipboardModel.count; j++) {
                    if (filteredClipboardModel.get(j).entry === deleteProcess.deletedEntry) {
                        filteredClipboardModel.remove(j)
                        break
                    }
                }
                root.totalCount = filteredClipboardModel.count
                if (filteredClipboardModel.count === 0) {
                    root.keyboardNavigationActive = false
                    root.selectedIndex = 0
                } else if (root.selectedIndex >= filteredClipboardModel.count) {
                    root.selectedIndex = filteredClipboardModel.count - 1
                }
                Qt.callLater(root.refresh)
            } else {
                console.warn("Failed to delete clipboard entry")
            }
        }
    }

    Process {
        id: wipeProcess
        command: ["sh", "-c", "printf y | cliphist wipe"]
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                listModel.clear()
                filteredClipboardModel.clear()
                root.totalCount = 0
                Qt.callLater(root.refresh)
            } else {
                console.warn("cliphist wipe failed, exit code:", exitCode)
            }
        }
    }

    Process {
        id: copyProcess
        running: false
        property var pendingCallback: null
        onExited: exitCode => {
            const cb = pendingCallback
            pendingCallback = null
            if (cb) cb()
        }
    }

    Process {
        id: pasteKeystroke
        running: false
    }

    Process {
        id: wtypeProbe
        command: ["sh", "-c", "command -v wtype"]
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                root.pasteTool = "wtype"
            } else {
                ydotoolProbe.running = true
            }
        }
    }

    Process {
        id: ydotoolProbe
        command: ["sh", "-c", "command -v ydotool"]
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                root.pasteTool = "ydotool"
            } else {
                root.pasteTool = ""
            }
        }
    }

    Process {
        id: dataUrlDecoder
        running: false
        property int entryId: -1
        property var callback: null

        command: {
            const tmp = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dms-cliphist-" + entryId + "-" + Date.now()
            return ["sh", "-c", `cliphist decode ${entryId} > ${tmp} 2>/dev/null && file -b --mime-type ${tmp} && echo "::TMP::${tmp}"`]
        }

        stdout: StdioCollector {
            id: dataUrlMimeCollector
        }

        onExited: exitCode => {
            const cb = dataUrlDecoder.callback
            dataUrlDecoder.callback = null
            if (exitCode !== 0) {
                if (cb) cb("", "")
                return
            }
            const raw = (dataUrlMimeCollector.text || "").trim()
            const sepIdx = raw.lastIndexOf("::TMP::")
            if (sepIdx < 0) {
                if (cb) cb("", "")
                return
            }
            const mime = raw.substring(0, sepIdx).trim()
            const tmp = raw.substring(sepIdx + "::TMP::".length).trim()
            b64Encoder.tmpPath = tmp
            b64Encoder.mime = mime
            b64Encoder.callback = cb
            b64Encoder.running = true
        }
    }

    Process {
        id: b64Encoder
        running: false
        property string tmpPath: ""
        property string mime: ""
        property var callback: null

        command: ["sh", "-c", `base64 -w0 ${tmpPath}`]

        stdout: StdioCollector {
            id: b64Collector
        }

        onExited: exitCode => {
            const cb = b64Encoder.callback
            const mime = b64Encoder.mime
            const path = b64Encoder.tmpPath
            b64Encoder.callback = null
            b64Encoder.mime = ""
            b64Encoder.tmpPath = ""
            if (exitCode === 0) {
                const b64 = (b64Collector.text || "").trim()
                if (cb) cb(mime, b64)
            } else {
                if (cb) cb("", "")
            }
            if (path) {
                Quickshell.execDetached(["rm", "-f", path])
            }
        }
    }

    Timer {
        id: pasteTimer
        interval: 200
        repeat: false
        property var callback: null
        onTriggered: {
            const cb = callback
            callback = null
            root.sendPasteKeystroke()
            if (cb) {
                Qt.callLater(cb)
            }
        }
    }

    Component.onCompleted: {
        clipboardProbe.running = true
        wtypeProbe.running = true
    }

    function refresh() {
        listProcess.running = true
    }

    function copyEntry(entry, callback) {
        const entryId = entry.split('\t')[0]
        copyProcess.command = ["sh", "-c", `cliphist decode ${entryId} | wl-copy`]
        copyProcess.pendingCallback = callback || null
        copyProcess.running = true
    }

    function pasteEntry(entry, callback) {
        copyEntry(entry, () => {
            pasteTimer.callback = callback || null
            pasteTimer.start()
        })
    }

    function sendPasteKeystroke() {
        if (pasteTool === "wtype") {
            pasteKeystroke.command = ["wtype", "-M", "ctrl", "v", "-m", "ctrl"]
            pasteKeystroke.running = true
        } else if (pasteTool === "ydotool") {
            pasteKeystroke.command = ["ydotool", "key", "ctrl+v"]
            pasteKeystroke.running = true
        } else {
            console.warn("ClipboardService: no paste tool available (install wtype or ydotool)")
        }
    }

    function getEntryId(entry) {
        if (!entry) return -1
        const parts = entry.split('\t')
        const id = parseInt(parts[0])
        return isNaN(id) ? -1 : id
    }

    function invalidateLauncherSearchCache() {
        searchText = ""
    }

    function getEntryDataUrl(id, callback) {
        if (id === undefined || id === null || id < 0) {
            callback("", "")
            return
        }
        dataUrlDecoder.entryId = id
        dataUrlDecoder.callback = callback
        dataUrlDecoder.running = true
    }

    function deleteEntry(entry) {
        deleteProcess.deletedEntry = entry
        deleteProcess.command = ["sh", "-c", `echo '${entry.replace(/'/g, "'\\''")}' | cliphist delete`]
        deleteProcess.running = true
    }

    function clearAll() {
        wipeProcess.running = true
    }

    function getEntryPreview(entry) {
        if (!entry) return ""
        let content = entry.replace(/^\s*\d+\s+/, "");
        if (content.includes("image/") || content.includes("binary data") || /\.(png|jpg|jpeg|gif|bmp|webp)/i.test(content)) {
            const dimensionMatch = content.match(/(\d+)x(\d+)/);
            if (dimensionMatch) {
                return `Image ${dimensionMatch[1]}×${dimensionMatch[2]}`;
            }
            const typeMatch = content.match(/\b(png|jpg|jpeg|gif|bmp|webp)\b/i);
            if (typeMatch) {
                return `Image (${typeMatch[1].toUpperCase()})`;
            }
            return "Image";
        }
        if (content.length > ClipboardConstants.previewLength) {
            return content.substring(0, ClipboardConstants.previewLength) + "...";
        }
        return content;
    }

    function getEntryType(entry) {
        if (!entry) return "text"
        if (entry.includes("image/") || entry.includes("binary data") || /\.(png|jpg|jpeg|gif|bmp|webp)/i.test(entry) || /\b(png|jpg|jpeg|gif|bmp|webp)\b/i.test(entry)) {
            return "image";
        }
        if (entry.length > ClipboardConstants.longTextThreshold) {
            return "long_text";
        }
        return "text";
    }

    function setSearchText(text) {
        searchText = text || ""
        updateFilteredModel()
    }

    function updateFilteredModel() {
        filteredClipboardModel.clear()
        for (var i = 0; i < listModel.count; i++) {
            const entry = listModel.get(i).entry
            if (searchText.trim().length === 0) {
                filteredClipboardModel.append({
                    "entry": entry
                })
            } else {
                const content = getEntryPreview(entry).toLowerCase()
                if (content.includes(searchText.toLowerCase())) {
                    filteredClipboardModel.append({
                        "entry": entry
                    })
                }
            }
        }
        root.totalCount = filteredClipboardModel.count
        if (filteredClipboardModel.count === 0) {
            root.keyboardNavigationActive = false
            root.selectedIndex = 0
        } else if (root.selectedIndex >= filteredClipboardModel.count) {
            root.selectedIndex = filteredClipboardModel.count - 1
        }
    }
}
