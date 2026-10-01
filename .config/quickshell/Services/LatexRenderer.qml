pragma Singleton
pragma ComponentBehavior: Bound

import qs.Common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property real renderPadding: 4

    property list<string> processedHashes: []
    property var processedExpressions: ({})
    property var renderedImagePaths: ({})
    readonly property url rendererScriptUrl: Qt.resolvedUrl("../Scripts/latex2svg.sh")
    readonly property string rendererScriptPath: FileUtils.trimFileProtocol(root.rendererScriptUrl)
    readonly property string latexOutputPath: FileUtils.trimFileProtocol(Paths.latexOutput)
    property bool rendererAvailable: false
    property string rendererSource: "none"
    property bool latexRendererAvailable: root.rendererAvailable
    property var renderQueue: []
    property string lastRenderStderr: ""

    signal renderFinished(string hash, string imagePath)

    Process {
        id: latexAvailabilityProcess
        running: true
        command: [root.rendererScriptPath, "--check"]
        stdout: SplitParser {
            onRead: data => {
                const text = data.trim()
                if (!text)
                    return
                try {
                    const status = JSON.parse(text)
                    root.rendererAvailable = !!status.renderer
                    root.rendererSource = status.source || "none"
                } catch (error) {
                    console.warn("LatexRenderer: failed to parse availability:", text)
                    root.rendererAvailable = false
                }
                if (root.rendererAvailable) {
                    Paths.mkdir(Paths.latexOutput)
                    texRenderProcess.startNext()
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.rendererAvailable = false
            }
        }
    }

    Timer {
        id: recheckTimer
        interval: 800
        repeat: false
        onTriggered: {
            if (!root.rendererAvailable && !root.latexAvailabilityProcess?.running)
                root.refreshAvailability()
        }
    }

    Timer {
        id: failsafeTimer
        interval: 10000
        repeat: true
        running: true
        onTriggered: {
            if (!root.rendererAvailable && !root.latexAvailabilityProcess?.running && root.renderQueue.length > 0)
                root.refreshAvailability()
        }
    }

    function refreshAvailability() {
        Paths.mkdir(Paths.latexOutput)
        latexAvailabilityProcess.running = false
        latexAvailabilityProcess.running = true
    }

    Process {
        id: texRenderProcess
        property var pending: null
        command: []
        running: false
        stderr: StdioCollector {
            onStreamFinished: root.lastRenderStderr = text.trim()
        }

        function startNext() {
            if (texRenderProcess.running || root.renderQueue.length === 0)
                return

            root.lastRenderStderr = ""
            texRenderProcess.pending = root.renderQueue.shift()
            texRenderProcess.command = [
                root.rendererScriptPath,
                "--input", texRenderProcess.pending.expression,
                "--output", texRenderProcess.pending.imagePath,
                "--display", texRenderProcess.pending.display ? "1" : "0",
                "--color", Theme.surfaceText,
                "--textsize", String(Theme.fontSizeMedium),
                "--padding", String(root.renderPadding)
            ]
            texRenderProcess.running = true
        }

        onExited: (exitCode, exitStatus) => {
            if (texRenderProcess.pending) {
                if (exitCode === 0) {
                    root.renderedImagePaths[texRenderProcess.pending.hash] = texRenderProcess.pending.imagePath
                    root.renderFinished(texRenderProcess.pending.hash, texRenderProcess.pending.imagePath)
                } else {
                    console.warn("LatexRenderer: failed to render:", texRenderProcess.pending.expression, "exit code:", exitCode, root.lastRenderStderr)
                    const retryIdx = root.processedHashes.indexOf(texRenderProcess.pending.hash)
                    if (retryIdx !== -1)
                        root.processedHashes.splice(retryIdx, 1)
                }
                texRenderProcess.pending = null
            }
            texRenderProcess.startNext()
        }
    }

    function requestRender(expression, display = false, replaceKey = "") {
        if (!expression)
            return ["", false]

        const hash = Qt.md5(expression)
        const imagePath = `${latexOutputPath}/${hash}.svg`

        if (processedHashes.includes(hash)) {
            Qt.callLater(() => renderFinished(hash, imagePath))
            return [hash, false]
        } else {
            root.processedHashes.push(hash)
            root.processedExpressions[hash] = replaceKey || expression
        }

        root.renderQueue.push({
            "hash": hash,
            "expression": expression,
            "imagePath": imagePath,
            "display": display
        })

        if (!root.latexRendererAvailable) {
            recheckTimer.start()
            return [hash, true]
        }

        texRenderProcess.startNext()
        return [hash, true]
    }
}