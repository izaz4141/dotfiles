pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Services.ai
import qs.Widgets
import qs.Modules.Toolbox
import org.kde.syntaxhighlighting

ColumnLayout {
    id: root

    property bool editing: false
    property bool renderMarkdown: true
    property bool enableMouseSelection: false
    property var segmentContent: ""
    property var segmentLang: "txt"
    property var messageData: ({})
    property bool isCommandRequest: segmentLang === "command"
    property var displayLang: isCommandRequest ? "bash" : segmentLang

    property real codeBlockBackgroundRounding: Appearance.rounding.small
    property real codeBlockHeaderPadding: 3
    property real codeBlockComponentSpacing: 2
    property real codeBlockBottomSpacing: 4
    property bool sourceMode: !root.renderMarkdown
    property string sourceEditText: ""
    property string sourceText: "```" + (root.segmentLang || "") + "\n" + root.segmentContent.replace(/\n+$/, "") + "\n```"

    function stripFences(t) {
        const m = t.match(/^\s*```[^\n]*\n([\s\S]*?)\n```\s*$/);
        return m ? m[1] : t;
    }

    onEditingChanged: {
        if (root.editing && root.sourceMode) {
            root.sourceEditText = root.sourceText;
        }
    }
    onRenderMarkdownChanged: {
        if (!root.renderMarkdown && root.editing) {
            root.sourceEditText = root.sourceText;
        }
    }

    spacing: codeBlockComponentSpacing

    Rectangle {
        visible: !root.sourceMode
        Layout.fillWidth: true
        topLeftRadius: root.codeBlockBackgroundRounding
        topRightRadius: root.codeBlockBackgroundRounding
        bottomLeftRadius: Math.max(4, Appearance.rounding.small / 2)
        bottomRightRadius: Math.max(4, Appearance.rounding.small / 2)
        color: Theme.surfaceContainerHighest
        implicitHeight: codeBlockTitleBarRowLayout.implicitHeight + root.codeBlockHeaderPadding * 2

        RowLayout {
            id: codeBlockTitleBarRowLayout
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.codeBlockHeaderPadding
            anchors.rightMargin: root.codeBlockHeaderPadding
            spacing: 5

            StyledText {
                id: codeBlockLanguage
                Layout.alignment: Qt.AlignLeft
                Layout.fillWidth: false
                Layout.topMargin: 7
                Layout.bottomMargin: 7
                Layout.leftMargin: 10
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.surfaceText
                text: root.displayLang ? (Repository.definitionForName(root.displayLang).name || root.displayLang) : "plain"
            }

            Item {
                Layout.fillWidth: true
            }

            ToolButtonGroup {
                AiMessageControlButton {
                    id: copyCodeButton
                    buttonIcon: activated ? "inventory" : "content_copy"

                    onClicked: {
                        Quickshell.clipboardText = root.segmentContent;
                        copyCodeButton.activated = true;
                        copyIconTimer.restart();
                    }

                    Timer {
                        id: copyIconTimer
                        interval: 1500
                        repeat: false
                        onTriggered: copyCodeButton.activated = false
                    }

                    tooltipText: I18n.tr("Copy code", "AiChat interface")
                }

                AiMessageControlButton {
                    id: saveCodeButton
                    buttonIcon: activated ? "check" : "save"

                    onClicked: {
                        const downloadPath = Paths.strip(Paths.downloads);
                        const savePath = `${downloadPath}/code.${root.segmentLang || "txt"}`;
                        Quickshell.execDetached(["bash", "-c",
                            `mkdir -p '${downloadPath}' && echo '${StringUtils.shellSingleQuoteEscape(root.segmentContent)}' > '${savePath}'`
                        ]);
                        Quickshell.execDetached(["notify-send",
                            I18n.tr("Code saved to file", "AiChat interface"),
                            I18n.tr("Saved to %1", "AiChat interface").arg(savePath),
                            "-a", "Shell"
                        ]);
                        saveCodeButton.activated = true;
                        saveIconTimer.restart();
                    }

                    Timer {
                        id: saveIconTimer
                        interval: 1500
                        repeat: false
                        onTriggered: saveCodeButton.activated = false
                    }

                    tooltipText: I18n.tr("Save to Downloads", "AiChat interface")
                }
            }
        }
    }

    RowLayout {
        visible: !root.sourceMode
        Layout.bottomMargin: root.sourceMode ? 0 : root.codeBlockBottomSpacing
        spacing: root.codeBlockComponentSpacing

        Rectangle {
            implicitWidth: 40
            implicitHeight: lineNumberColumnLayout.implicitHeight
            Layout.fillHeight: true
            Layout.fillWidth: false
            topLeftRadius: Math.max(4, Appearance.rounding.small / 2)
            bottomLeftRadius: root.codeBlockBackgroundRounding
            topRightRadius: Math.max(4, Appearance.rounding.small / 2)
            bottomRightRadius: Math.max(4, Appearance.rounding.small / 2)
            color: Theme.surfaceContainerHigh

            ColumnLayout {
                id: lineNumberColumnLayout
                anchors {
                    left: parent.left
                    right: parent.right
                    rightMargin: 5
                    top: parent.top
                    topMargin: 6
                }
                spacing: 0

                Repeater {
                    model: codeTextArea.text.split("\n").length

                    Text {
                        required property int index
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignRight
                        text: index + 1
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            topLeftRadius: Math.max(4, Appearance.rounding.small / 2)
            bottomLeftRadius: Math.max(4, Appearance.rounding.small / 2)
            topRightRadius: Math.max(4, Appearance.rounding.small / 2)
            bottomRightRadius: root.codeBlockBackgroundRounding
            color: Theme.surfaceContainerHigh
            implicitHeight: codeColumnLayout.implicitHeight

            ColumnLayout {
                id: codeColumnLayout
                anchors.fill: parent
                spacing: 0

                ScrollView {
                    id: codeScrollView
                    Layout.fillWidth: true
                    implicitWidth: parent.width
                    implicitHeight: codeTextArea.implicitHeight + 1
                    contentWidth: codeTextArea.width - 1
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                    ScrollBar.horizontal: ScrollBar {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        padding: 5
                        policy: ScrollBar.AsNeeded
                        opacity: visualSize == 1 ? 0 : 1
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.durations.quick
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.anim.curves.standard
                            }
                        }

                        contentItem: Rectangle {
                            implicitHeight: 6
                            radius: Math.max(4, Appearance.rounding.small / 2)
                            color: Theme.surfaceContainerHighest
                        }
                    }

                    TextArea {
                        id: codeTextArea
                        Layout.fillWidth: true
                        readOnly: !root.editing
                        selectByMouse: root.enableMouseSelection || root.editing
                        renderType: Text.NativeRendering
                        font.family: Theme.monoFontFamily
                        font.hintingPreference: Font.PreferNoHinting
                        font.pixelSize: Theme.fontSizeSmall
                        selectedTextColor: Theme.primary
                        selectionColor: Theme.primaryContainer
                        color: root.messageData?.thinking ? Theme.surfaceVariantText : Theme.surfaceText
                        background: null
                        text: root.segmentContent

                        onTextChanged: {
                            root.segmentContent = text;
                        }

                        SyntaxHighlighter {
                            id: highlighter
                            textEdit: codeTextArea
                            repository: Repository
                            definition: Repository.definitionForName(root.displayLang || "plaintext")
                            theme: Theme.syntaxHighlightingTheme
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Tab) {
                                const cursor = codeTextArea.cursorPosition;
                                codeTextArea.insert(cursor, "    ");
                                codeTextArea.cursorPosition = cursor + 4;
                                event.accepted = true;
                            } else if ((event.key === Qt.Key_C) && event.modifiers == Qt.ControlModifier) {
                                codeTextArea.copy();
                                event.accepted = true;
                            }
                        }
                    }
                }

                Loader {
                    active: root.isCommandRequest && root.messageData.functionPending
                    visible: active
                    Layout.fillWidth: true
                    Layout.margins: 6
                    Layout.topMargin: 0

                    sourceComponent: RowLayout {
                        Item {
                            Layout.fillWidth: true
                        }

                        ToolButtonGroup {
                            DankButton {
                                expandOnPress: true
                                minWidth: 0
                                horizontalPadding: 8
                                vPadding: 6
                                radius: Appearance.rounding.small
                                backgroundColor: "transparent"
                                textColor: Theme.surfaceText
                                text: I18n.tr("Reject", "AiChat interface")
                                textSize: Theme.fontSizeSmall
                                onClicked: Ai.rejectCommand(root.messageData)
                            }
                            DankButton {
                                toggled: true
                                expandOnPress: true
                                minWidth: 0
                                horizontalPadding: 8
                                vPadding: 6
                                radius: Appearance.rounding.small
                                backgroundColor: "transparent"
                                toggledBackgroundColor: Theme.primary
                                textColor: Theme.surfaceText
                                toggledTextColor: Theme.primaryText
                                text: I18n.tr("Approve", "AiChat interface")
                                textSize: Theme.fontSizeSmall
                                onClicked: Ai.approveCommand(root.messageData)
                            }
                        }
                    }
                }
            }
        }
    }

    TextArea {
        id: sourceTextArea
        visible: root.sourceMode
        Layout.fillWidth: true
        readOnly: !root.editing
        selectByMouse: root.enableMouseSelection || root.editing
        renderType: Text.NativeRendering
        font.family: Theme.monoFontFamily
        font.hintingPreference: Font.PreferNoHinting
        font.pixelSize: Theme.fontSizeSmall
        selectedTextColor: Theme.primary
        selectionColor: Theme.primaryContainer
        color: root.messageData?.thinking ? Theme.surfaceVariantText : Theme.surfaceText
        wrapMode: TextEdit.Wrap
        textFormat: TextEdit.PlainText
        text: root.editing ? root.sourceEditText : root.sourceText
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0
        background: null

        onTextChanged: {
            if (!root.sourceMode) return
            if (root.editing) {
                root.sourceEditText = text;
                root.segmentContent = root.stripFences(text);
            }
        }
    }
}