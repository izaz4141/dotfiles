pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import "../../../Common/markdown2html.js" as Markdown2Html

ColumnLayout {
    id: root

    property bool editing: false
    property bool renderMarkdown: true
    property bool enableMouseSelection: false
    property var segmentContent: ""
    property var messageData: ({})
    property bool done: true
    property bool forceDisableChunkSplitting: false

    property list<string> renderedLatexHashes: []
    property string renderedSegmentContent: ""
    property string shownText: ""
    property bool fadeChunkSplitting: !forceDisableChunkSplitting && !editing && !/\n\|/.test(shownText) && (typeof SettingsData !== "undefined" ? SettingsData.toolboxAiTextFadeIn : false)

    Layout.fillWidth: true

    Timer {
        id: renderTimer
        interval: 1000
        repeat: false
        onTriggered: {
            root.renderLatex()
            for (const hash of renderedLatexHashes) {
                handleRenderedLatex(hash, true);
            }
        }
    }

    function renderLatex() {
        let regex = /(\$\$([\s\S]+?)\$\$)|(\$([^\$]+?)\$)|(\\\[((?:.|\n)+?)\\\])|(\\\(([\s\S]+?)\\\))/g;
        let match;
        while ((match = regex.exec(segmentContent)) !== null) {
            const full = match[0];
            const expression = match[2] || match[4] || match[6] || match[8];
            const display = !!(match[1] || match[5]);
            if (expression) {
                Qt.callLater(() => {
                    const [renderHash, isNew] = LatexRenderer.requestRender(expression.trim(), display, full);
                    if (renderHash && !renderedLatexHashes.includes(renderHash)) {
                        renderedLatexHashes.push(renderHash);
                    }
                });
            }
        }
    }

    function handleRenderedLatex(hash, force = false) {
        if (renderedLatexHashes.includes(hash) || force) {
            const imagePath = LatexRenderer.renderedImagePaths[hash];
            if (!imagePath)
                return;
            const markdownImage = `![latex](${Paths.toFileUrl(imagePath)})`;

            const expression = LatexRenderer.processedExpressions[hash];
            renderedSegmentContent = renderedSegmentContent.replace(expression, markdownImage);
        }
    }

    onDoneChanged: {
        renderTimer.restart();
    }
    onEditingChanged: {
        if (!editing) {
            renderLatex()
        } else {
            root.shownText = segmentContent
        }
    }

    onSegmentContentChanged: {
        renderedSegmentContent = segmentContent;
        if (!root.editing && segmentContent) {
            root.renderLatex();
        }
    }

    onRenderedSegmentContentChanged: {
        if (renderedSegmentContent) {
            root.shownText = renderedSegmentContent;
        }
    }

    Connections {
        target: LatexRenderer
        function onRenderFinished(hash, imagePath) {
            handleRenderedLatex(hash);
        }
    }

    spacing: 0
    Repeater {
        id: textLinesRepeater
        property list<real> textLineOpacities: []
        model: ScriptModel {
            values: root.fadeChunkSplitting ? root.shownText.split(/\n\n(?= {0,2})|\n(?= {0,2}[-\*])/g).filter(line => line.trim() !== "") : [root.shownText]
            onValuesChanged: {
                while (textLinesRepeater.textLineOpacities.length < values.length) {
                    textLinesRepeater.textLineOpacities.push(root.messageData.done ? 1 : 0);
                }
            }
        }
        delegate: TextArea {
            id: textArea
            required property int index
            required property string modelData

            visible: opacity > 0
            opacity: fadeChunkSplitting ? (textLinesRepeater.textLineOpacities[index] ?? (root.messageData.done ? 1 : 0)) : 1

            Connections {
                target: root.messageData
                function onDoneChanged() {
                    if (root.messageData?.done) {
                        textLinesRepeater.textLineOpacities[textArea.index] = 1
                    }
                }
            }
            Connections {
                target: textLinesRepeater.model
                function onValuesChanged() {
                    if (textLinesRepeater.model.values.length > textArea.index + 1) {
                        textLinesRepeater.textLineOpacities[textArea.index] = 1
                    }
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.durations.quick
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }

            Layout.fillWidth: true
            readOnly: !root.editing
            selectByMouse: root.enableMouseSelection || root.editing
            renderType: Text.NativeRendering
            font.family: Theme.fontFamily
            font.hintingPreference: Font.PreferNoHinting
            font.pixelSize: Theme.fontSizeSmall
            selectedTextColor: Theme.primary
            selectionColor: Theme.primaryContainer
            wrapMode: TextEdit.Wrap
            color: root.messageData?.thinking ? Theme.surfaceVariantText : Theme.surfaceText
            textFormat: root.editing
                ? (root.renderMarkdown ? TextEdit.MarkdownText : TextEdit.PlainText)
                : (root.renderMarkdown ? TextEdit.RichText : TextEdit.PlainText)
            text: root.renderMarkdown && !root.editing
                ? Markdown2Html.markdownToHtml(modelData, {
                    linkColor: Theme.primary,
                    paragraphMarginBottom: 4,
                    headingMarginTop: 8,
                    headingMarginBottom: 4,
                    codeMarginTop: 8,
                    codeMarginBottom: 8,
                    listMarginTop: 4,
                    listMarginBottom: 4,
                    tableMarginTop: 8,
                    tableMarginBottom: 8
                  })
                : modelData
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            background: null

            onTextChanged: {
                if (!root.editing) return
                root.segmentContent = text
            }

            onLinkActivated: (link) => {
                Qt.openUrlExternally(link)
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor :
                    (root.enableMouseSelection || root.editing) ? Qt.IBeamCursor : Qt.ArrowCursor
            }
        }
    }
}
