pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Toolbox
import qs.Modules.Toolbox.aiChat
import "../../Common/fzf.js" as Fzf

Item {
    id: root

    property real padding: 4
    property var inputField: messageInputField
    property string commandPrefix: "/"

    property var suggestionQuery: ""
    property var suggestionList: []

    property var visibleMessageIDs: []

    property real lastScrolledContentY: 0
    property bool statusBarHidden: false

    property string cliphistBinary: "cliphist"
    property bool cliphistAvailable: false
    readonly property string cacheDir: Paths.cache + "/ai/attachments"

    onFocusChanged: focus => {
        if (focus)
            root.inputField.forceActiveFocus();
    }

    Component.onCompleted: root.refreshVisibleMessages()

    property var streamingMessage: Ai.messageByID[Ai.messageIDs[Ai.messageIDs.length - 1]]

    Connections {
        target: Ai
        function onMessageIDsChanged() {
            root.refreshVisibleMessages();
            messageListView.followContent();
        }
    }

    Connections {
        target: root.streamingMessage
        function onContentChanged() {
            messageListView.followContent();
        }
        function onDoneChanged() {
            messageListView.followContent();
        }
    }

    Connections {
        target: messageListView
        function onContentYChanged() {
            const delta = messageListView.contentY - root.lastScrolledContentY;
            if ((messageListView.isUserScrolling || messageListView.isMomentumActive) && delta > 0)
                root.statusBarHidden = true;
            else if (delta < 0)
                root.statusBarHidden = false;
            root.lastScrolledContentY = messageListView.contentY;
        }
    }

    function refreshVisibleMessages() {
        root.visibleMessageIDs = Ai.messageIDs.filter(id => {
            const message = Ai.messageByID[id];
            return message?.visibleToUser ?? true;
        });
    }

    Keys.onPressed: event => {
        messageInputField.forceActiveFocus();
        if (event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageUp) {
                messageListView.contentY = Math.max(0, messageListView.contentY - messageListView.height / 2);
                root.statusBarHidden = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_PageDown) {
                messageListView.contentY = Math.min(messageListView.contentHeight - messageListView.height / 2, messageListView.contentY + messageListView.height / 2);
                root.statusBarHidden = true;
                event.accepted = true;
            }
        }
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_O)
            Ai.clearMessages();
    }

    property var allCommands: [{
        "name": "attach",
        "icon": "attach_file",
        "description": I18n.tr("Attach a file. Only works with Gemini.", "AiChat toolbar"),
        "execute": args => Ai.attachFile(args.join(" ").trim())
    }, {
        "name": "model",
        "icon": "psychology",
        "description": I18n.tr("Choose model", "AiChat toolbar"),
        "execute": args => Ai.setModel(args[0])
    }, {
        "name": "tool",
        "icon": "service_toolbox",
        "description": I18n.tr("Set the tool to use for the model.", "AiChat toolbar"),
        "execute": args => {
            if (args.length == 0 || args[0] == "get") {
                Ai.addMessage(I18n.tr("Usage: %1tool TOOL_NAME", "AiChat toolbar").arg(root.commandPrefix), Ai.interfaceRole);
            } else {
                const tool = args[0];
                if (Ai.setTool(tool))
                    Ai.addMessage(I18n.tr("Tool set to: %1", "AiChat toolbar").arg(tool), Ai.interfaceRole);
            }
        }
    }, {
        "name": "prompt",
        "icon": "notes",
        "description": I18n.tr("Set the system prompt for the model.", "AiChat toolbar"),
        "execute": args => {
            if (args.length === 0 || args[0] === "get") {
                Ai.printPrompt();
                return;
            }
            Ai.loadPrompt(args.join(" ").trim());
        }
    }, {
        "name": "key",
        "icon": "key",
        "description": I18n.tr("Set API key", "AiChat toolbar"),
        "execute": args => {
            if (args[0] == "get") {
                Ai.printApiKey();
            } else {
                Ai.setApiKey(args[0]);
            }
        }
    }, {
        "name": "save",
        "icon": "save",
        "description": I18n.tr("Save chat", "AiChat toolbar"),
        "execute": args => {
            const joinedArgs = args.join(" ");
            if (joinedArgs.trim().length == 0) {
                Ai.addMessage(I18n.tr("Usage: %1save CHAT_NAME", "AiChat toolbar").arg(root.commandPrefix), Ai.interfaceRole);
                return;
            }
            Ai.saveChat(joinedArgs);
        }
    }, {
        "name": "load",
        "icon": "folder_open",
        "description": I18n.tr("Load chat", "AiChat toolbar"),
        "execute": args => {
            const joinedArgs = args.join(" ");
            if (joinedArgs.trim().length == 0) {
                Ai.addMessage(I18n.tr("Usage: %1load CHAT_NAME", "AiChat toolbar").arg(root.commandPrefix), Ai.interfaceRole);
                return;
            }
            Ai.loadChat(joinedArgs);
        }
    }, {
        "name": "clear",
        "icon": "delete_sweep",
        "description": I18n.tr("Clear chat history", "AiChat toolbar"),
        "execute": () => Ai.clearMessages()
    }, {
        "name": "temp",
        "icon": "device_thermostat",
        "description": I18n.tr("Set temperature (randomness) of the model. Values range between 0 to 2 for Gemini, 0 to 1 for other models. Default is 0.5.", "AiChat toolbar"),
        "execute": args => {
            if (args.length == 0 || args[0] == "get") {
                Ai.printTemperature();
            } else {
                Ai.setTemperature(parseFloat(args[0]));
            }
        }
    }, {
        "name": "test",
        "icon": "science",
        "description": I18n.tr("Markdown test", "AiChat toolbar"),
        "execute": () => {
            Ai.addMessage(`
thinking
A longer think block to test the revealing animation
It should fade in chunk by chunk as the model streams. Every paragraph is a separate
line of the fade-in animation, so longer replies feel alive while they generate.
response
## ✏️ Markdown test
### Formatting

- *Italic*, \`Monospace\`, **Bold**, [Link](https://example.com)
- Arch lincox icon <img src="${Quickshell.shellPath("assets/icons/arch-symbolic.svg")}" height="${Theme.fontSizeMedium}"/>

### Table

Quickshell vs AGS/Astal

|                          | Quickshell       | AGS/Astal         |
|--------------------------|------------------|-------------------|
| UI Toolkit               | Qt               | Gtk3/Gtk4         |
| Language                 | QML              | Js/Ts/Lua         |
| Reactivity               | Implied          | Needs declaration |
| Widget placement         | Mildly difficult | More intuitive    |
| Bluetooth & Wifi support | ❌               | ✅                |
| No-delay keybinds        | ✅               | ❌                |
| Development              | New APIs         | New syntax        |

### Code block

Just a hello world with syntax highlighting...

\`\`\`cpp
#include <bits/stdc++.h>
// This is intentionally very long to test scrolling
const std::string GREETING = "UwU";
int main(int argc, char* argv[]) {
    std::cout << GREETING;
}
\`\`\`

### LaTeX

Inline w/ dollar signs: $\\frac{1}{2} = \\frac{2}{4}$

Inline w/ double dollar signs: $$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$$

Inline w/ backslash and square brackets \\[\\int_0^\\infty \\frac{1}{x^2} dx = \\infty\\]

Inline w/ backslash and round brackets \\(e^{i\\pi} + 1 = 0\\)
`, Ai.interfaceRole);
        }
    }]

    function handleInput(inputText) {
        if (inputText.startsWith(root.commandPrefix)) {
            const command = inputText.split(" ")[0].substring(1);
            const args = inputText.split(" ").slice(1);
            const commandObj = root.allCommands.find(cmd => cmd.name === `${command}`);
            if (commandObj) {
                commandObj.execute(args);
            } else {
                Ai.addMessage(I18n.tr("Unknown command: ", "AiChat interface") + command, Ai.interfaceRole);
            }
        } else {
            Ai.sendUserMessage(inputText);
        }

        messageListView.positionViewAtEnd();
    }

    function makeFinder(items) {
        return new Fzf.Finder(items, {
            "selector": item => item,
            "limit": 20,
            "casing": "case-insensitive"
        });
    }

    function commandIcon(name) {
        return root.allCommands.find(cmd => cmd.name === name)?.icon ?? "";
    }

    function makeSuggestionEntry(text, name, displayName, description, icon) {
        const leadingToken = text.trim().split(/\s+/).length == 1;
        return {
            "name": `${leadingToken ? name : ""}${text.split(" ")[1] ?? ""}`,
            "displayName": displayName,
            "description": description,
            "icon": icon
        };
    }

    function updateSuggestions() {
        const text = messageInputField.text;
        if (text.length === 0) {
            root.suggestionQuery = "";
            root.suggestionList = [];
            return;
        }

        if (text.startsWith(root.commandPrefix + "model")) {
            root.suggestionQuery = text.split(" ")[1] ?? "";
            root.suggestionList = root.makeFinder(Ai.modelList).find(root.suggestionQuery).map(r => root.makeSuggestionEntry(text, root.commandPrefix + "model " + r.item, Ai.models[r.item].name, Ai.models[r.item].description, root.commandIcon("model")));
        } else if (text.startsWith(root.commandPrefix + "prompt")) {
            root.suggestionQuery = text.split(" ")[1] ?? "";
            root.suggestionList = root.makeFinder(Ai.promptFiles).find(root.suggestionQuery).map(r => root.makeSuggestionEntry(text, root.commandPrefix + "prompt " + r.item, FileUtils.trimFileExt(FileUtils.fileNameForPath(r.item)), I18n.tr("Load prompt from %1", "AiChat toolbar").arg(r.item), root.commandIcon("prompt")));
        } else if (text.startsWith(root.commandPrefix + "save") || text.startsWith(root.commandPrefix + "load")) {
            const verb = text.startsWith(root.commandPrefix + "save") ? "save" : "load";
            root.suggestionQuery = text.split(" ")[1] ?? "";
            root.suggestionList = root.makeFinder(Ai.savedChats).find(root.suggestionQuery).map(r => {
                const chatName = FileUtils.trimFileExt(FileUtils.fileNameForPath(r.item)).trim();
                return root.makeSuggestionEntry(text, root.commandPrefix + verb + " " + chatName, chatName, I18n.tr("Load chat from %1", "AiChat toolbar").arg(r.item), root.commandIcon(verb));
            });
        } else if (text.startsWith(root.commandPrefix + "tool")) {
            root.suggestionQuery = text.split(" ")[1] ?? "";
            root.suggestionList = root.makeFinder(Ai.availableTools).find(root.suggestionQuery).map(r => root.makeSuggestionEntry(text, root.commandPrefix + "tool " + r.item, r.item, Ai.toolDescriptions[r.item], root.commandIcon("tool")));
        } else if (text.startsWith(root.commandPrefix)) {
            root.suggestionQuery = text;
            root.suggestionList = root.allCommands.filter(cmd => cmd.name.startsWith(text.substring(1))).slice(0, text === root.commandPrefix ? 5 : 10).map(cmd => ({
                "name": root.commandPrefix + cmd.name,
                "icon": cmd.icon,
                "description": `${cmd.description}`
            }));
        } else {
            root.suggestionQuery = "";
            root.suggestionList = [];
        }
    }

    function pasteClipboardText() {
        const text = Quickshell.clipboardText;
        if (text && text.length > 0)
            messageInputField.insert(messageInputField.cursorPosition, text);
        messageInputField.forceActiveFocus();
    }

    function tryPasteImage() {
        if (!root.cliphistAvailable) {
            root.pasteClipboardText();
            return;
        }
        listCliphistProc.running = true;
    }

    function handleClipboardEntry(entry) {
        if (!entry || entry.length === 0)
            return false;
        if (/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry)) {
            decodeImageAndAttachProc.handleEntry(entry);
            return true;
        }
        const cleanEntry = StringUtils.cleanCliphistEntry(entry);
        if (cleanEntry.startsWith("file://")) {
            Ai.attachFile(decodeURIComponent(cleanEntry));
            return true;
        }
        return false;
    }

    function handleInputKey(event) {
        if (event.key === Qt.Key_Tab) {
            suggestions.acceptSelectedWord();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up && suggestions.visible) {
            suggestions.selectedIndex = Math.max(0, suggestions.selectedIndex - 1);
            suggestions.ensureSelectedVisible();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down && suggestions.visible) {
            suggestions.selectedIndex = Math.min(root.suggestionList.length - 1, suggestions.selectedIndex + 1);
            suggestions.ensureSelectedVisible();
            event.accepted = true;
        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            if (event.modifiers & Qt.ShiftModifier) {
                messageInputField.insert(messageInputField.cursorPosition, "\n");
                event.accepted = true;
            } else {
                const inputText = messageInputField.text;
                messageInputField.clear();
                root.handleInput(inputText);
                event.accepted = true;
            }
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
            if (event.modifiers & Qt.ShiftModifier)
                root.pasteClipboardText();
            else
                root.tryPasteImage();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (Ai.pendingFilePath.length > 0) {
                Ai.attachFile("");
                event.accepted = true;
            }
        }
    }

    Process {
        id: cliphistProbeProc
        running: true
        command: ["sh", "-c", "command -v cliphist"]
        stdout: StdioCollector {
            onStreamFinished: root.cliphistAvailable = text.trim().length > 0
        }
    }

    Process {
        id: listCliphistProc
        command: [root.cliphistBinary, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const firstLine = text.split("\n")[0];
                if (!root.handleClipboardEntry(firstLine))
                    root.pasteClipboardText();
            }
        }
    }

    Process {
        id: decodeImageAndAttachProc
        property string imageDecodeFileName: "image"
        property string imageDecodeFilePath: root.cacheDir + "/" + imageDecodeFileName

        function handleEntry(entry) {
            imageDecodeFileName = parseInt(entry.match(/^(\d+)\t/)[1]);
            exec(["bash", "-c", `mkdir -p '${root.cacheDir}' && [ -f '${imageDecodeFilePath}' ] || echo '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode > '${imageDecodeFilePath}'`]);
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Ai.attachFile(imageDecodeFilePath);
            } else {
                console.error("[AiChat] Failed to decode image in clipboard content");
            }
        }
    }

    component StatusItem: Item {
        id: statusItem

        property string icon
        property string statusText
        property string description
        property bool hovered: false

        implicitHeight: statusItemRowLayout.implicitHeight
        implicitWidth: statusItemRowLayout.implicitWidth

        RowLayout {
            id: statusItemRowLayout
            anchors.centerIn: parent
            spacing: 0

            DankIcon {
                name: statusItem.icon
                size: Appearance.fontSize.huge
                color: Theme.surfaceVariantText
            }

            StyledText {
                font.pixelSize: Appearance.fontSize.small
                text: statusItem.statusText
                color: Theme.surfaceVariantText
            }
        }

        HoverHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: statusItem.hovered = hovered
        }

        DankHoverTooltip {
            target: statusItem
            text: statusItem.description
            side: "bottom"
            multiLine: true
            maxWidth: 420
        }
    }

    component StatusSeparator: Rectangle {
        implicitWidth: 4
        implicitHeight: 4
        radius: implicitWidth / 2
        color: Theme.outlineVariant
    }

    ColumnLayout {
        id: columnLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: root.padding

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: messageListView.width
                    height: messageListView.height
                    radius: Appearance.rounding.small
                }
            }

            ElevationShadow {
                id: statusShadow
                z: 1
                anchors.fill: statusBg
                level: Theme.elevationLevel2
                fallbackOffset: 4
                targetColor: statusBg.color
                targetRadius: Theme.cornerRadius
                sourceRect.antialiasing: true
                sourceRect.smooth: true
                shadowEnabled: Theme.elevationEnabled
                opacity: messageListView.atYBeginning ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.durations.quick
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            }

            Rectangle {
                id: statusBg
                z: 2
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: root.statusBarHidden ? -(implicitHeight + 16) : 4
                }
                implicitWidth: statusRowLayout.implicitWidth + 10 * 2
                implicitHeight: Math.max(statusRowLayout.implicitHeight, 38)
                radius: Theme.cornerRadius
                color: messageListView.atYBeginning ? Theme.surfaceContainerHigh : Theme.surfaceContainerHighest
                opacity: root.statusBarHidden ? 0 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.durations.quick
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.durations.quick
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }

                Behavior on anchors.topMargin {
                    NumberAnimation {
                        duration: Appearance.anim.durations.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }

                RowLayout {
                    id: statusRowLayout
                    anchors.centerIn: parent
                    spacing: 10

                    StatusItem {
                        icon: Ai.currentModelHasApiKey ? "key" : "key_off"
                        statusText: ""
                        description: Ai.currentModelHasApiKey ? I18n.tr("API key is set\nChange with /key YOUR_API_KEY", "Keyring") : I18n.tr("No API key\nSet it with /key YOUR_API_KEY", "Keyring")
                    }

                    StatusSeparator {}

                    StatusItem {
                        icon: "device_thermostat"
                        statusText: Ai.temperature.toFixed(1)
                        description: I18n.tr("Temperature\nChange with /temp VALUE", "AiChat toolbar")
                    }

                    StatusSeparator {
                        visible: Ai.tokenCount.total > 0
                    }

                    StatusItem {
                        visible: Ai.tokenCount.total > 0
                        icon: "token"
                        statusText: Ai.tokenCount.total
                        description: I18n.tr("Total token count\nInput: %1\nOutput: %2", "AiChat toolbar").arg(Ai.tokenCount.input).arg(Ai.tokenCount.output)
                    }
                }
            }

            DankListView {
                id: messageListView
                z: 0
                anchors.fill: parent
                stickToBottom: true
                model: root.visibleMessageIDs
                delegate: AiMessage {
                    required property var modelData
                    required property int index
                    messageIndex: index
                    messageData: Ai.messageByID[modelData]
                    messageInputField: root.inputField
                }
            }

            ToolPlaceholder {
                z: 2
                shown: Ai.messageIDs.length === 0
                icon: "neurology"
                title: I18n.tr("Large language models", "AiChat toolbar")
                description: I18n.tr("Type /key to get started with online models", "AiChat toolbar")
            }

            ScrollToBottomButton {
                z: 3
                target: messageListView
            }
        }

        DescriptionBox {
            text: root.suggestionList[suggestions.selectedIndex]?.description ?? ""
            showArrows: root.suggestionList.length > 1
        }

        Flickable {
            id: suggestions
            visible: root.suggestionList.length > 0 && messageInputField.text.length > 0
            property int selectedIndex: 0
            Layout.fillWidth: true
            Layout.preferredHeight: suggestionsRow.implicitHeight
            contentWidth: suggestionsRow.implicitWidth
            contentHeight: height
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Behavior on contentX {
                NumberAnimation {
                    duration: Appearance.anim.durations.quick
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }

            Row {
                id: suggestionsRow
                width: implicitWidth
                spacing: 5

                Repeater {
                    id: suggestionRepeater
                    model: {
                        suggestions.selectedIndex = 0;
                        return root.suggestionList.slice(0, 10);
                    }
                    delegate: SuggestionChip {
                        id: commandButton
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: suggestions.selectedIndex === index

                        toggled: commandButton.isSelected
                        iconName: modelData.icon ?? ""
                        text: modelData.displayName ?? modelData.name

                        onHoveredChanged: {
                            if (commandButton.hovered)
                                suggestions.selectedIndex = index;
                        }
                        onClicked: suggestions.acceptSuggestion(modelData.name)
                    }
                }
            }

            function acceptSuggestion(word) {
                const words = messageInputField.text.trim().split(/\s+/);
                if (words.length > 0) {
                    words[words.length - 1] = word;
                } else {
                    words.push(word);
                }
                messageInputField.text = words.join(" ") + " ";
                messageInputField.cursorPosition = messageInputField.text.length;
                messageInputField.forceActiveFocus();
            }

            function acceptSelectedWord() {
                if (suggestions.selectedIndex >= 0 && suggestions.selectedIndex < root.suggestionList.length) {
                    suggestions.acceptSuggestion(root.suggestionList[suggestions.selectedIndex].name);
                }
            }

            function ensureSelectedVisible() {
                const chip = suggestionRepeater.itemAt(suggestions.selectedIndex);
                if (!chip) return;
                const left = chip.x;
                const right = chip.x + chip.width;
                if (left < suggestions.contentX)
                    suggestions.contentX = left;
                else if (right > suggestions.contentX + suggestions.width)
                    suggestions.contentX = right - suggestions.width;
            }
        }

        Rectangle {
            id: inputWrapper
            property real spacing: 5
            Layout.fillWidth: true
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHighest
            implicitHeight: Math.max(inputFieldRowLayout.implicitHeight + inputFieldRowLayout.anchors.bottomMargin + commandButtonsRow.implicitHeight + commandButtonsRow.anchors.bottomMargin + spacing, 45) + (attachedFileIndicator.implicitHeight + spacing + attachedFileIndicator.anchors.margins)
            clip: true

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }

            AttachedFileIndicator {
                id: attachedFileIndicator
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: visible ? 5 : 0
                }
                filePath: Ai.pendingFilePath
                onRemove: Ai.attachFile("")
            }

            RowLayout {
                id: inputFieldRowLayout
                anchors {
                    bottom: commandButtonsRow.top
                    left: parent.left
                    right: parent.right
                    bottomMargin: 5
                }
                spacing: 0

                ScrollView {
                    id: inputScrollView
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(root.height * 3 / 5, messageInputField.height)
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    TextArea {
                        id: messageInputField
                        anchors.fill: parent
                        wrapMode: TextArea.Wrap
                        leftPadding: 10
                        topPadding: 10
                        color: activeFocus ? Theme.surfaceText : Theme.surfaceVariantText
                        placeholderText: I18n.tr("Message the model... \"%1\" for commands", "AiChat interface").arg(root.commandPrefix)
                        selectionColor: Theme.primaryContainer
                        selectedTextColor: Theme.primary
                        cursorDelegate: Rectangle {
                            id: messageCursor
                            width: 1.5
                            radius: 1
                            color: Theme.surfaceText
                            x: messageInputField.cursorRectangle.x
                            y: messageInputField.cursorRectangle.y
                            height: messageInputField.cursorRectangle.height

                            SequentialAnimation on opacity {
                                running: messageInputField.activeFocus
                                loops: Animation.Infinite
                                PropertyAnimation {
                                    from: 1.0
                                    to: 0.0
                                    duration: 650
                                    easing.type: Easing.InOutQuad
                                }
                                PropertyAnimation {
                                    from: 0.0
                                    to: 1.0
                                    duration: 650
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                        background: null

                        onTextChanged: root.updateSuggestions()

                        function accept() {
                            root.handleInput(text);
                            text = "";
                        }

                        Keys.onPressed: event => root.handleInputKey(event)
                    }
                }

                DankButton {
                    id: sendButton
                    Layout.alignment: Qt.AlignBottom
                    Layout.rightMargin: 5
                    width: 40
                    height: 40
                    minWidth: 0
                    horizontalPadding: 0
                    radius: Appearance.rounding.small
                    enabled: messageInputField.text.length > 0
                    toggled: enabled
                    backgroundColor: "transparent"
                    toggledBackgroundColor: Theme.primary
                    textColor: Theme.surfaceTextAlpha
                    toggledTextColor: Theme.primaryText
                    iconName: "send"
                    iconSize: 22

                    onClicked: {
                        const inputText = messageInputField.text;
                        root.handleInput(inputText);
                        messageInputField.clear();
                    }
                }
            }

            RowLayout {
                id: commandButtonsRow
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: 5
                    leftMargin: 10
                    rightMargin: 5
                }
                spacing: 4

                property var commandsShown: [{
                    "name": "",
                    "icon": "keyboard_command_key",
                    "sendDirectly": false,
                    "dontAddSpace": true
                }, {
                    "name": "clear",
                    "icon": "delete_sweep",
                    "sendDirectly": true
                }]

                ToolInputIndicator {
                    icon: "api"
                    text: Ai.getModel().name
                    tooltipText: I18n.tr("Current model: %1\nSet it with %2model MODEL", "AiChat toolbar").arg(Ai.getModel().name).arg(root.commandPrefix)
                }

                ToolInputIndicator {
                    icon: "service_toolbox"
                    text: Ai.currentTool.charAt(0).toUpperCase() + Ai.currentTool.slice(1)
                    tooltipText: I18n.tr("Current tool: %1\nSet it with %2tool TOOL", "AiChat toolbar").arg(Ai.currentTool).arg(root.commandPrefix)
                }

                Item {
                    Layout.fillWidth: true
                }

                ToolButtonGroup {
                    padding: 0

                    Repeater {
                        model: commandButtonsRow.commandsShown
                        delegate: DankButton {
                            required property var modelData
                            property string commandRepresentation: root.commandPrefix + modelData.name
                            text: commandRepresentation
                            iconName: modelData.icon ?? ""
                            buttonHeight: 30
                            expandOnPress: true
                            minWidth: 0
                            horizontalPadding: 8
                            vPadding: 6
                            radius: Appearance.rounding.small
                            backgroundColor: Theme.surfaceContainerHigh
                            textColor: Theme.surfaceText
                            textSize: Theme.fontSizeSmall

                            downAction: () => {
                                if (modelData.sendDirectly) {
                                    root.handleInput(commandRepresentation);
                                } else {
                                    messageInputField.text = commandRepresentation + (modelData.dontAddSpace ? "" : " ");
                                    messageInputField.cursorPosition = messageInputField.text.length;
                                    messageInputField.forceActiveFocus();
                                }
                                if (modelData.name === "clear")
                                    messageInputField.text = "";
                            }
                        }
                    }
                }
            }
        }
    }
}
