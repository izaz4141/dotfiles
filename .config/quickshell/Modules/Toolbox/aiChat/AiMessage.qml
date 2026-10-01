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

Rectangle {
    id: root

    property int messageIndex
    property var messageData
    property var messageInputField

    property real messagePadding: 7
    property real contentSpacing: 3

    property bool enableMouseSelection: false
    property bool renderMarkdown: true
    property bool previousRenderMarkdown: true
    property bool editing: false

    property var messageBlocks: StringUtils.splitMarkdownBlocks(root.messageData?.content)

    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    implicitHeight: columnLayout.implicitHeight + root.messagePadding * 2

    radius: Theme.cornerRadius
    color: Theme.surfaceContainer

    function saveMessage() {
        if (!root.editing) return;
        const segments = messageContentColumnLayout.children.map(child => child.segment).filter(segment => (segment));
        const newContent = segments.map(segment => {
            if (segment.type === "code") {
                const lang = segment.lang ? segment.lang : "";
                const code = segment.content.replace(/\n+$/, "");
                return "```" + lang + "\n" + code + "\n```";
            }
            return segment.content;
        }).join("");
        root.editing = false;
        root.messageData.content = newContent;
        root.renderMarkdown = root.previousRenderMarkdown;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Control || event.key === Qt.Key_Shift || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
            event.accepted = true;
        }
        if ((event.key === Qt.Key_S) && event.modifiers == Qt.ControlModifier) {
            root.saveMessage();
            event.accepted = true;
        }
    }

    ColumnLayout {
        id: columnLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.messagePadding
        spacing: root.contentSpacing

        Rectangle {
            Layout.fillWidth: true
            implicitWidth: headerRowLayout.implicitWidth + 8
            implicitHeight: headerRowLayout.implicitHeight + 8
            color: Theme.primaryContainer
            radius: Appearance.rounding.small

            RowLayout {
                id: headerRowLayout
                anchors {
                    fill: parent
                    margins: 4
                }
                spacing: 18

                Item {
                    id: nameWrapper
                    implicitHeight: Math.max(nameRowLayout.implicitHeight + 10, 30)
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        id: nameRowLayout
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillHeight: true
                            implicitWidth: Math.max(modelIcon.implicitWidth, roleIcon.implicitWidth)
                            implicitHeight: Math.max(modelIcon.implicitHeight, roleIcon.implicitHeight)

                            DankIcon {
                                id: modelIcon
                                anchors.centerIn: parent
                                width: Math.round(Theme.fontSizeLarge)
                                height: Math.round(Theme.fontSizeLarge)
                                visible: root.messageData?.role === 'assistant' && Ai.models[root.messageData?.model] !== undefined
                                name: Ai.models[root.messageData?.model]?.icon ?? "neurology"
                                size: Theme.fontSizeLarge
                                color: Theme.primary
                            }

                            DankIcon {
                                id: roleIcon
                                anchors.centerIn: parent
                                width: Math.round(Theme.fontSizeLarge)
                                height: Math.round(Theme.fontSizeLarge)
                                visible: !modelIcon.visible
                                name: root.messageData?.role === 'user' ? 'person' :
                                    root.messageData?.role === 'interface' ? 'settings' :
                                    root.messageData?.role === 'assistant' ? 'neurology' : 'computer'
                                size: Theme.fontSizeLarge
                                color: Theme.primary
                            }
                        }

                        StyledText {
                            id: providerName
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.primary
                            text: root.messageData?.role === 'assistant' ? (Ai.models[root.messageData?.model]?.name ?? "") :
                                (root.messageData?.role === 'user' && SystemInfo.username) ? SystemInfo.username :
                                I18n.tr("Interface", "AiChat interface")
                        }
                    }
                }

                Button {
                    id: modelVisibilityIndicator
                    visible: root.messageData?.role === 'interface'
                    implicitWidth: 16
                    implicitHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    background: Item

                    DankIcon {
                        anchors.centerIn: parent
                        width: Math.round(Theme.fontSizeSmall)
                        height: Math.round(Theme.fontSizeSmall)
                        name: "visibility_off"
                        size: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankHoverTooltip {
                        target: modelVisibilityIndicator
                        text: I18n.tr("Not visible to model", "AiChat interface")
                    }
                }

                ToolButtonGroup {
                    AiMessageControlButton {
                        id: regenButton
                        buttonIcon: "refresh"
                        visible: root.messageData?.role === 'assistant'
                        onClicked: Ai.regenerate(root.messageIndex)
                        tooltipText: I18n.tr("Regenerate", "AiChat interface")
                    }

                    AiMessageControlButton {
                        id: copyButton
                        buttonIcon: activated ? "inventory" : "content_copy"
                        onClicked: {
                            Quickshell.clipboardText = root.messageData?.content;
                            copyButton.activated = true;
                            copyIconTimer.restart();
                        }

                        Timer {
                            id: copyIconTimer
                            interval: 1500
                            repeat: false
                            onTriggered: copyButton.activated = false
                        }

                        tooltipText: I18n.tr("Copy", "AiChat interface")
                    }

                    AiMessageControlButton {
                        id: editButton
                        activated: root.editing
                        enabled: root.messageData?.done ?? false
                        buttonIcon: "edit"
                        onClicked: {
                            root.editing = !root.editing;
                            if (root.editing) {
                                root.previousRenderMarkdown = root.renderMarkdown;
                                root.renderMarkdown = false;
                            } else {
                                root.saveMessage();
                            }
                        }
                        tooltipText: root.editing ? I18n.tr("Save", "AiChat interface") : I18n.tr("Edit", "AiChat interface")
                    }

                    AiMessageControlButton {
                        id: toggleMarkdownButton
                        activated: !root.renderMarkdown
                        buttonIcon: "code"
                        onClicked: root.renderMarkdown = !root.renderMarkdown
                        tooltipText: I18n.tr("View Markdown source", "AiChat interface")
                    }

                    AiMessageControlButton {
                        id: deleteButton
                        buttonIcon: "close"
                        onClicked: Ai.removeMessage(root.messageIndex)
                        tooltipText: I18n.tr("Delete", "AiChat interface")
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            active: root.messageData?.localFilePath && root.messageData?.localFilePath.length > 0
            sourceComponent: AttachedFileIndicator {
                filePath: root.messageData?.localFilePath
                canRemove: false
            }
        }

        ColumnLayout {
            id: messageContentColumnLayout
            spacing: 0

            Item {
                Layout.fillWidth: true
                implicitHeight: loadingSpinner.visible ? 32 : 0
                visible: implicitHeight > 0

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Appearance.anim.durations.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }

                DankSpinner {
                    id: loadingSpinner
                    anchors.centerIn: parent
                    size: 28
                    visible: (root.messageBlocks.length < 1) && (!root.messageData?.done)
                }
            }

            Repeater {
                model: root.messageBlocks

                delegate: Loader {
                    id: blockLoader
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    property var seg: modelData
                    property var segment: ({
                        "type": seg.type,
                        "lang": seg.lang,
                        "content": (item && item.segmentContent !== undefined) ? item.segmentContent : seg.content
                    })
                    sourceComponent: seg.type === "code" ? codeComponent : seg.type === "think" ? thinkComponent : textComponent

                    Component {
                        id: codeComponent
                        MessageCodeBlock {
                            editing: root.editing
                            renderMarkdown: root.renderMarkdown
                            enableMouseSelection: root.enableMouseSelection
                            segmentContent: blockLoader.seg.content
                            segmentLang: blockLoader.seg.lang
                            messageData: root.messageData
                        }
                    }

                    Component {
                        id: thinkComponent
                        MessageThinkBlock {
                            editing: root.editing
                            renderMarkdown: root.renderMarkdown
                            enableMouseSelection: root.enableMouseSelection
                            segmentContent: blockLoader.seg.content
                            messageData: root.messageData
                            done: root.messageData?.done ?? false
                            completed: blockLoader.seg.completed ?? false
                        }
                    }

                    Component {
                        id: textComponent
                        MessageTextBlock {
                            editing: root.editing
                            renderMarkdown: root.renderMarkdown
                            enableMouseSelection: root.enableMouseSelection
                            segmentContent: blockLoader.seg.content
                            messageData: root.messageData
                            done: root.messageData?.done ?? false
                            forceDisableChunkSplitting: root.messageData?.content.includes("```") ?? true
                        }
                    }
                }
            }
        }

        Flow {
            visible: (root.messageData?.annotationSources?.length ?? 0) > 0
            spacing: 5
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft

            Repeater {
                model: root.messageData?.annotationSources || []

                delegate: AnnotationSourceButton {
                    required property var modelData
                    displayText: modelData.text
                    url: modelData.url
                }
            }
        }

        Flow {
            visible: (root.messageData?.searchQueries?.length ?? 0) > 0
            spacing: 5
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft

            Repeater {
                model: root.messageData?.searchQueries || []

                delegate: SearchQueryButton {
                    required property var modelData
                    query: modelData
                }
            }
        }
    }
}