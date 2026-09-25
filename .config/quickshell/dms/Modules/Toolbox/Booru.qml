pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Toolbox
import qs.Modules.Toolbox.booru
import "../../Common/fzf.js" as Fzf

Item {
    id: root

    property real padding: 4

    property var inputField: tagInputField
    readonly property var responses: Booru.responses
    property string previewDownloadPath: FileUtils.trimFileProtocol(Paths.cache) + "/media/boorus"
    property string downloadPath: FileUtils.trimFileProtocol(Paths.pictures) + "/homework"
    property string nsfwPath: FileUtils.trimFileProtocol(Paths.pictures) + "/homework/nsfw"
    property string commandPrefix: "/"
    property int tagSuggestionDelay: 210
    property var suggestionQuery: ""
    property var suggestionList: []

property bool pullLoading: false
        property int pullLoadingGap: 80

    Connections {
        target: Booru
        function onTagSuggestion(query, suggestions) {
            root.suggestionQuery = query;
            root.suggestionList = suggestions;
        }
        function onRunningRequestsChanged() {
            if (Booru.runningRequests === 0)
                root.pullLoading = false;
        }
    }

    property var allCommands: [{
        "name": "mode",
        "description": I18n.tr("Set the current API provider", "Booru"),
        "execute": args => Booru.setProvider(args[0] || Booru.providerList[0])
    }, {
        "name": "clear",
        "description": I18n.tr("Clear the current list of images", "Booru"),
        "execute": () => Booru.clearResponses()
    }, {
        "name": "next",
        "description": I18n.tr("Get the next page of results", "Booru"),
        "execute": () => Booru.nextPage()
    }, {
        "name": "safe",
        "description": I18n.tr("Disable NSFW content", "Booru"),
        "execute": () => SettingsData.set("toolboxBooruAllowNsfw", false)
    }, {
        "name": "lewd",
        "description": I18n.tr("Allow NSFW content", "Booru"),
        "execute": () => SettingsData.set("toolboxBooruAllowNsfw", true)
    }]

    function makeFinder(items) {
        return new Fzf.Finder(items, {
            "selector": item => item,
            "limit": 20,
            "casing": "case-insensitive"
        });
    }

    function handleInput(inputText) {
        if (inputText.startsWith(root.commandPrefix)) {
            const command = inputText.split(" ")[0].substring(1);
            const args = inputText.split(" ").slice(1);
            const commandObj = root.allCommands.find(cmd => cmd.name === `${command}`);
            if (commandObj) {
                commandObj.execute(args);
            } else {
                Booru.addSystemMessage(I18n.tr("Unknown command: ", "Booru") + command);
            }
        } else if (inputText.trim() == "+") {
            root.handleInput(`${root.commandPrefix}next`);
        } else {
            const tagList = inputText.split(/\s+/).filter(tag => tag.length > 0);
            let pageIndex = 1;
            for (let i = 0; i < tagList.length; ++i) {
                if (/^\d+$/.test(tagList[i])) {
                    pageIndex = parseInt(tagList[i], 10);
                    tagList.splice(i, 1);
                    break;
                }
            }
            Booru.makeRequest(tagList, SettingsData.toolboxBooruAllowNsfw, SettingsData.toolboxBooruLimit, pageIndex);
        }
    }

    onFocusChanged: focus => {
        if (focus)
            tagInputField.forceActiveFocus();
    }

    property real pageKeyScrollAmount: booruResponseListView.height / 2
    Keys.onPressed: event => {
        tagInputField.forceActiveFocus();
        if (event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageUp) {
                if (booruResponseListView.atYBeginning) return;
                booruResponseListView.contentY = Math.max(0, booruResponseListView.contentY - root.pageKeyScrollAmount);
                event.accepted = true;
            } else if (event.key === Qt.Key_PageDown) {
                if (booruResponseListView.atYEnd) return;
                booruResponseListView.contentY = Math.min(booruResponseListView.contentHeight, booruResponseListView.contentY + root.pageKeyScrollAmount);
                event.accepted = true;
            }
        }
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_O)
            Booru.clearResponses();
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
                    width: booruResponseListView.width
                    height: booruResponseListView.height
                    radius: Appearance.rounding.small
                }
            }

            DankListView {
                id: booruResponseListView
                z: 0
                anchors.fill: parent
                stickToBottom: true

                property int lastResponseLength: 0
                Connections {
                    target: root
                    function onResponsesChanged() {
                        if (root.responses.length > booruResponseListView.lastResponseLength) {
                            if (booruResponseListView.lastResponseLength > 0 && root.responses[booruResponseListView.lastResponseLength].provider != "system")
                                booruResponseListView.followContent();
                            booruResponseListView.lastResponseLength = root.responses.length;
                        }
                    }
                }

                model: root.responses
                delegate: BooruResponse {
                    required property var modelData
                    responseData: modelData
                    tagInputField: root.inputField
                    previewDownloadPath: root.previewDownloadPath
                    downloadPath: root.downloadPath
                    nsfwPath: root.nsfwPath
                }

                onDragEnded: {
                    const gap = booruResponseListView.verticalOvershoot;
                    if (gap > root.pullLoadingGap) {
                        root.pullLoading = true;
                        root.handleInput(`${root.commandPrefix}next`);
                    }
                }
            }

            ToolPlaceholder {
                z: 2
                shown: root.responses.length === 0
                icon: "manga"
                title: I18n.tr("Image Boards", "Booru")
                description: ""
            }

            ScrollToBottomButton {
                z: 3
                target: booruResponseListView
            }
        }

        DescriptionBox {
            text: root.suggestionList[tagSuggestions.selectedIndex]?.description ?? ""
            showArrows: root.suggestionList.length > 1
        }

        Flickable {
            id: tagSuggestions
            visible: root.suggestionList.length > 0 && tagInputField.text.length > 0
            property int selectedIndex: 0
            Layout.fillWidth: true
            Layout.preferredHeight: tagSuggestionsRow.implicitHeight
            contentWidth: tagSuggestionsRow.implicitWidth
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
                id: tagSuggestionsRow
                width: implicitWidth
                spacing: 5

                Repeater {
                    id: tagSuggestionRepeater
                    model: {
                        tagSuggestions.selectedIndex = 0;
                        return root.suggestionList.slice(0, 10);
                    }
                    delegate: SuggestionChip {
                        id: tagButton
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: tagSuggestions.selectedIndex === index

                        toggled: tagButton.isSelected
                        text: (tagButton.modelData.displayName ?? tagButton.modelData.name) + "  " + (tagButton.modelData.count ?? "")

                        onHoveredChanged: {
                            if (tagButton.hovered)
                                tagSuggestions.selectedIndex = index;
                        }
                        onClicked: tagSuggestions.acceptTag(modelData.name)
                    }
                }

            }

            function acceptTag(tag) {
                const words = tagInputField.text.trim().split(/\s+/);
                if (words.length > 0) {
                    words[words.length - 1] = tag;
                } else {
                    words.push(tag);
                }
                const updatedText = words.join(" ") + " ";
                tagInputField.text = updatedText;
                tagInputField.cursorPosition = tagInputField.text.length;
                tagInputField.forceActiveFocus();
            }

            function acceptSelectedTag() {
                if (tagSuggestions.selectedIndex >= 0 && tagSuggestions.selectedIndex < tagSuggestionRepeater.count) {
                    const tag = root.suggestionList[tagSuggestions.selectedIndex].name;
                    tagSuggestions.acceptTag(tag);
                }
            }

            function ensureSelectedVisible() {
                const chip = tagSuggestionRepeater.itemAt(tagSuggestions.selectedIndex);
                if (!chip) return;
                const left = chip.x;
                const right = chip.x + chip.width;
                if (left < tagSuggestions.contentX)
                    tagSuggestions.contentX = left;
                else if (right > tagSuggestions.contentX + tagSuggestions.width)
                    tagSuggestions.contentX = right - tagSuggestions.width;
            }
        }

        Rectangle {
            id: tagInputContainer
            property real columnSpacing: 5
            Layout.fillWidth: true
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHighest
            implicitHeight: Math.max(inputFieldRowLayout.implicitHeight + inputFieldRowLayout.anchors.topMargin + commandButtonsRow.implicitHeight + commandButtonsRow.anchors.bottomMargin + columnSpacing, 45)
            clip: true

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }

            RowLayout {
                id: inputFieldRowLayout
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 5
                spacing: 0

                ScrollView {
                    id: tagInputScrollView
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(root.height * 3 / 5, tagInputField.height)
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    TextArea {
                        id: tagInputField
                        anchors.fill: parent
                        wrapMode: TextArea.Wrap
                        leftPadding: 10
                        topPadding: 10
                        color: activeFocus ? Theme.surfaceText : Theme.surfaceVariantText
                        placeholderText: I18n.tr('Enter tags, or "%1" for commands', "Booru").arg(root.commandPrefix)
                        selectionColor: Theme.primaryContainer
                        selectedTextColor: Theme.primary
                        cursorDelegate: Rectangle {
                            id: tagCursor
                            width: 1.5
                            radius: 1
                            color: Theme.surfaceText
                            x: tagInputField.cursorRectangle.x
                            y: tagInputField.cursorRectangle.y
                            height: tagInputField.cursorRectangle.height

                            SequentialAnimation on opacity {
                                running: tagInputField.activeFocus
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

                        property Timer searchTimer: Timer {
                            interval: root.tagSuggestionDelay
                            repeat: false
                            onTriggered: {
                                const inputText = tagInputField.text;
                                const words = inputText.trim().split(/\s+/);
                                if (words.length > 0)
                                    Booru.triggerTagSearch(words[words.length - 1]);
                            }
                        }

                        onTextChanged: {
                            if (tagInputField.text.length === 0) {
                                root.suggestionQuery = "";
                                root.suggestionList = [];
                                searchTimer.stop();
                                return;
                            }
                            if (tagInputField.text.startsWith(`${root.commandPrefix}mode`)) {
                                root.suggestionQuery = tagInputField.text.split(" ")[1] ?? "";
                                const leadingToken = tagInputField.text.trim().split(/\s+/).length == 1;
                                root.suggestionList = root.makeFinder(Booru.providerList).find(root.suggestionQuery).map(item => {
                                    const provider = item.item;
                                    return {
                                        "name": `${leadingToken ? root.commandPrefix + "mode " : ""}${provider}`,
                                        "displayName": `${Booru.providers[provider].name}`,
                                        "description": `${Booru.providers[provider].description}`,
                                    };
                                });
                                searchTimer.stop();
                                return;
                            }
                            if (tagInputField.text.startsWith(root.commandPrefix)) {
                                root.suggestionQuery = tagInputField.text;
                                root.suggestionList = root.allCommands.filter(cmd => cmd.name.startsWith(tagInputField.text.substring(1))).map(cmd => {
                                    return {
                                        "name": `${root.commandPrefix}${cmd.name}`,
                                        "description": `${cmd.description}`,
                                    };
                                });
                                searchTimer.stop();
                                return;
                            }
                            searchTimer.restart();
                        }

                        function accept() {
                            root.handleInput(text);
                            text = "";
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Tab) {
                                tagSuggestions.acceptSelectedTag();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up && tagSuggestions.visible) {
                                tagSuggestions.selectedIndex = Math.max(0, tagSuggestions.selectedIndex - 1);
                                tagSuggestions.ensureSelectedVisible();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down && tagSuggestions.visible) {
                                tagSuggestions.selectedIndex = Math.min(root.suggestionList.length - 1, tagSuggestions.selectedIndex + 1);
                                tagSuggestions.ensureSelectedVisible();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    tagInputField.insert(tagInputField.cursorPosition, "\n");
                                    event.accepted = true;
                                } else {
                                    const inputText = tagInputField.text;
                                    root.handleInput(inputText);
                                    tagInputField.clear();
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }

                DankButton {
                    id: sendButton
                    Layout.alignment: Qt.AlignTop
                    Layout.rightMargin: 5
                    width: 40
                    height: 40
                    minWidth: 0
                    horizontalPadding: 0
                    radius: Appearance.rounding.small
                    enabled: tagInputField.text.length > 0
                    toggled: enabled
                    backgroundColor: "transparent"
                    toggledBackgroundColor: Theme.primary
                    textColor: Theme.surfaceTextAlpha
                    toggledTextColor: Theme.primaryText
                    iconName: "send"
                    iconSize: 22

                    onClicked: {
                        const inputText = tagInputField.text;
                        root.handleInput(inputText);
                        tagInputField.clear();
                    }
                }
            }

            RowLayout {
                id: commandButtonsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                spacing: 5

                property var commandsShown: [{
                    "name": "mode",
                    "sendDirectly": false
                }, {
                    "name": "clear",
                    "sendDirectly": true
                }]

                ToolInputIndicator {
                    icon: "api"
                    text: Booru.providers[Booru.currentProvider].name
                    tooltipText: I18n.tr("Current API endpoint: %1\nSet it with %2mode PROVIDER", "Booru")
                        .arg(Booru.providers[Booru.currentProvider].url)
                        .arg(root.commandPrefix)
                }

                StyledText {
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    text: "•"
                }

                MouseArea {
                    enabled: Booru.currentProvider !== "zerochan"
                    implicitWidth: nsfwRow.implicitWidth
                    implicitHeight: nsfwRow.implicitHeight
                    Layout.alignment: Qt.AlignVCenter
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onClicked: SettingsData.set("toolboxBooruAllowNsfw", !nsfwToggle.checked)

                    RowLayout {
                        id: nsfwRow
                        anchors.centerIn: parent
                        spacing: 4

                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            font.pixelSize: Theme.fontSizeSmall
                            color: SettingsData.toolboxBooruAllowNsfw && Booru.currentProvider !== "zerochan" ? Theme.surfaceText : Theme.surfaceVariantText
                            text: I18n.tr("Allow NSFW", "Booru")
                        }

                        DankToggle {
                            id: nsfwToggle
                            enabled: false
                            scale: 0.6
                            checked: SettingsData.toolboxBooruAllowNsfw && Booru.currentProvider !== "zerochan"
                        }
                    }
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
                            property string commandRepresentation: `${root.commandPrefix}${modelData.name}`
                            text: commandRepresentation
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
                                    tagInputField.text = commandRepresentation + " ";
                                    tagInputField.cursorPosition = tagInputField.text.length;
                                    tagInputField.forceActiveFocus();
                                }
                                if (modelData.name === "clear")
                                    tagInputField.text = "";
                            }
                        }
                    }
                }
            }
        }
    }
}
