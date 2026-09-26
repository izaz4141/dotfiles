import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    readonly property var modelIds: Ai.modelList
    readonly property var modelOptions: modelIds.map(modelId => Ai.models[modelId]?.name ?? modelId)
    readonly property var toolIds: Ai.availableTools
    readonly property var toolOptions: toolIds.map(tool => root.toolLabel(tool))
    readonly property var providerIds: Booru.providerList
    readonly property var providerOptions: providerIds.map(providerId => Booru.providers[providerId]?.name ?? providerId)
    readonly property string currentToolId: toolIds.includes(SettingsData.toolboxAiTool) ? SettingsData.toolboxAiTool : (toolIds[0] ?? "none")
    readonly property string excludedSitesValue: (Array.isArray(SettingsData.toolboxAiSearchExcludedSites) ? SettingsData.toolboxAiSearchExcludedSites : []).join(", ")
    readonly property bool hasActivePrompt: Ai.activePromptFileName !== ""
    readonly property bool canManageActivePrompt: root.hasActivePrompt && Ai.promptFileNames.some(fileName => fileName.toLowerCase() === Ai.activePromptFileName.toLowerCase())
    property string searchUrlDraft: SettingsData.toolboxAiSearchEngineBaseUrl
    property string excludedSitesDraft: root.excludedSitesValue
    property string promptDraft: Ai.activePromptText
    property bool searchUrlDirty: false
    property bool excludedSitesDirty: false
    property bool showNewPromptRow: false
    property string newPromptFileName: ""
    property bool showRenamePromptRow: false
    property string renamePromptFileName: ""
    property bool confirmingPromptDelete: false
    property bool confirmingPromptSwitch: false
    property string pendingPromptFileName: ""
    property string pendingPromptAction: ""

    function toolLabel(tool) {
        if (tool === "functions")
            return I18n.tr("Functions", "AI tool option");
        if (tool === "search")
            return I18n.tr("Search", "AI tool option");
        if (tool === "none")
            return I18n.tr("None", "AI tool option");
        return tool;
    }

    function modelIdForLabel(label) {
        const index = root.modelOptions.indexOf(label);
        return index >= 0 ? root.modelIds[index] : label;
    }

    function toolIdForLabel(label) {
        const index = root.toolOptions.indexOf(label);
        return index >= 0 ? root.toolIds[index] : label;
    }

    function providerIdForLabel(label) {
        const index = root.providerOptions.indexOf(label);
        return index >= 0 ? root.providerIds[index] : label;
    }

    function modelLabel(modelId) {
        return Ai.models[modelId]?.name ?? modelId;
    }

    function providerLabel(providerId) {
        return Booru.providers[providerId]?.name ?? providerId;
    }

    function promptDraftDirty() {
        return root.promptDraft !== Ai.activePromptText;
    }

    function requestPromptAction(action, fileName) {
        if (root.promptDraftDirty()) {
            root.pendingPromptAction = action;
            root.pendingPromptFileName = fileName;
            root.confirmingPromptSwitch = true;
            root.confirmingPromptDelete = false;
            if (action === "switch")
                root.syncPromptFileDropdown();
            return false;
        }
        return true;
    }

    function runPendingPromptAction() {
        const action = root.pendingPromptAction;
        const fileName = root.pendingPromptFileName;
        root.cancelPendingPromptAction();
        if (action === "switch")
            Ai.selectPromptFile(fileName);
        else if (action === "delete")
            Ai.deletePrompt(fileName);
        else if (action === "rename")
            Ai.renamePrompt(Ai.activePromptFileName, fileName);
    }

    function cancelPendingPromptAction() {
        root.pendingPromptAction = "";
        root.pendingPromptFileName = "";
        root.confirmingPromptSwitch = false;
    }

    function selectPrompt(fileName) {
        if (!fileName || fileName === Ai.activePromptFileName) {
            root.syncPromptFileDropdown();
            return;
        }
        if (!root.requestPromptAction("switch", fileName))
            return;
        root.cancelPendingPromptAction();
        Ai.selectPromptFile(fileName);
        root.syncPromptFileDropdown();
    }

    function keepEditingPrompt() {
        root.cancelPendingPromptAction();
        root.syncPromptFileDropdown();
        Qt.callLater(() => promptEditor.forceActiveFocus());
    }

    function syncPromptFileDropdown() {
        Qt.callLater(() => promptFileDropdown.currentValue = Ai.activePromptFileName);
    }

    function syncPromptEditor() {
        root.promptDraft = Ai.activePromptText;
        if (promptEditor.text !== root.promptDraft)
            promptEditor.text = root.promptDraft;
    }

    function beginCreatePrompt() {
        root.newPromptFileName = "";
        root.showNewPromptRow = true;
        root.showRenamePromptRow = false;
        root.confirmingPromptDelete = false;
        root.cancelPendingPromptAction();
        Qt.callLater(() => newPromptNameInput.forceActiveFocus());
    }

    function createPrompt() {
        if (Ai.createPrompt(root.newPromptFileName, "")) {
            root.showNewPromptRow = false;
            root.newPromptFileName = "";
        }
    }

    function beginRenamePrompt() {
        if (!root.canManageActivePrompt)
            return;
        root.renamePromptFileName = Ai.activePromptFileName;
        root.showRenamePromptRow = true;
        root.showNewPromptRow = false;
        root.confirmingPromptDelete = false;
        root.cancelPendingPromptAction();
        Qt.callLater(() => renamePromptNameInput.selectAll());
    }

    function renamePrompt() {
        if (root.renamePromptFileName === Ai.activePromptFileName) {
            root.showRenamePromptRow = false;
            return;
        }
        if (!root.requestPromptAction("rename", root.renamePromptFileName)) {
            root.showRenamePromptRow = false;
            return;
        }
        if (Ai.renamePrompt(Ai.activePromptFileName, root.renamePromptFileName))
            root.showRenamePromptRow = false;
    }

    function requestDeletePrompt() {
        if (!root.canManageActivePrompt)
            return;
        if (!root.confirmingPromptDelete) {
            root.confirmingPromptDelete = true;
            return;
        }
        root.confirmingPromptDelete = false;
        if (!root.requestPromptAction("delete", Ai.activePromptFileName))
            return;
        Ai.deletePrompt(Ai.activePromptFileName);
    }

    function savePrompt() {
        if (root.hasActivePrompt)
            Ai.savePrompt(Ai.activePromptFileName, root.promptDraft);
    }

    function setModel(label) {
        const modelId = root.modelIdForLabel(label);
        if (modelId === Ai.currentModelId)
            return;
        SettingsData.set("toolboxAiModel", modelId);
        Qt.callLater(root.ensureValidTool);
    }

    function ensureValidTool() {
        const selectedTool = SettingsData.toolboxAiTool;
        if (root.toolIds.includes(selectedTool))
            return;
        const fallback = root.toolIds.includes("functions") ? "functions" : root.toolIds[0];
        if (!fallback)
            return;
        SettingsData.set("toolboxAiTool", fallback);
    }

    function setTool(label) {
        SettingsData.set("toolboxAiTool", root.toolIdForLabel(label));
    }

    function setTemperature(percent) {
        SettingsData.set("toolboxAiTemperature", Math.max(0, Math.min(2, percent / 100)));
    }

    function setBooruProvider(label) {
        SettingsData.set("toolboxBooruProvider", root.providerIdForLabel(label));
    }

    function commitSearchUrl() {
        if (!root.searchUrlDirty)
            return;
        const value = root.searchUrlDraft.trim();
        root.searchUrlDraft = value;
        root.searchUrlDirty = false;
        if (value === SettingsData.toolboxAiSearchEngineBaseUrl)
            return;
        SettingsData.set("toolboxAiSearchEngineBaseUrl", value);
    }

    function commitExcludedSites() {
        if (!root.excludedSitesDirty)
            return;
        const sites = [];
        const values = root.excludedSitesDraft.split(/[,\n]/);
        for (let i = 0; i < values.length; i++) {
            const site = values[i].trim();
            if (site && !sites.includes(site))
                sites.push(site);
        }
        const joined = sites.join(", ");
        root.excludedSitesDraft = joined;
        root.excludedSitesDirty = false;
        if (joined === root.excludedSitesValue)
            return;
        SettingsData.set("toolboxAiSearchExcludedSites", sites);
    }

    Component.onCompleted: {
        root.searchUrlDraft = SettingsData.toolboxAiSearchEngineBaseUrl;
        root.excludedSitesDraft = root.excludedSitesValue;
        root.syncPromptEditor();
    }

    Component.onDestruction: {
        root.commitSearchUrl();
        root.commitExcludedSites();
    }

    Connections {
        target: SettingsData

        function onToolboxAiSearchEngineBaseUrlChanged() {
            if (!searchUrlInput.getActiveFocus()) {
                root.searchUrlDraft = SettingsData.toolboxAiSearchEngineBaseUrl;
                root.searchUrlDirty = false;
            }
        }

        function onToolboxAiSearchExcludedSitesChanged() {
            if (!excludedSitesInput.getActiveFocus()) {
                root.excludedSitesDraft = root.excludedSitesValue;
                root.excludedSitesDirty = false;
            }
        }
    }

    Connections {
        target: Ai

        function onActivePromptFileNameChanged() {
            root.showNewPromptRow = false;
            root.showRenamePromptRow = false;
            root.confirmingPromptDelete = false;
            root.cancelPendingPromptAction();
            root.syncPromptFileDropdown();
            Qt.callLater(root.syncPromptEditor);
        }

        function onActivePromptTextChanged() {
            if (!promptEditor.activeFocus)
                root.syncPromptEditor();
        }
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "view_sidebar"
                title: I18n.tr("Toolbox Layout")
                settingKey: "toolboxLayout"
                tab: "toolbox"
                tags: ["toolbox", "layout", "width", "size"]

                SettingsSliderRow {
                    text: I18n.tr("Toolbox Width")
                    description: I18n.tr("Width of the Toolbox slideout")
                    settingKey: "toolboxWidth"
                    tab: "toolbox"
                    tags: ["toolbox", "width", "size", "slideout"]
                    minimum: 320
                    maximum: 1200
                    step: 10
                    value: Math.round(SettingsData.toolboxWidth)
                    defaultValue: 460
                    unit: "px"
                    onSliderValueChanged: value => SettingsData.set("toolboxWidth", value)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "neurology"
                title: I18n.tr("AI Assistant")
                settingKey: "toolboxAi"
                tab: "toolbox"
                tags: ["toolbox", "ai", "assistant"]

                SettingsDropdownRow {
                    id: modelDropdown
                    text: I18n.tr("Model")
                    description: I18n.tr("Model used by the Toolbox assistant")
                    settingKey: "toolboxAiModel"
                    tab: "toolbox"
                    tags: ["toolbox", "ai", "model", "assistant"]
                    options: root.modelOptions
                    currentValue: root.modelLabel(Ai.currentModelId)
                    dropdownWidth: 220
                    enableFuzzySearch: true
                    emptyText: I18n.tr("No models available")
                    onValueChanged: label => root.setModel(label)

                    Connections {
                        target: Ai
                        function onCurrentModelIdChanged() { Qt.callLater(() => modelDropdown.currentValue = root.modelLabel(Ai.currentModelId)); }
                        function onModelsChanged() { Qt.callLater(() => modelDropdown.currentValue = root.modelLabel(Ai.currentModelId)); }
                    }
                }

                SettingsDropdownRow {
                    id: toolDropdown
                    text: I18n.tr("Tool")
                    description: Ai.toolDescriptions[root.currentToolId] ?? I18n.tr("Tools available to the selected model")
                    settingKey: "toolboxAiTool"
                    tab: "toolbox"
                    tags: ["toolbox", "ai", "tool", "functions", "search"]
                    options: root.toolOptions
                    currentValue: root.toolLabel(root.currentToolId)
                    dropdownWidth: 180
                    onValueChanged: label => root.setTool(label)

                    Connections {
                        target: root
                        function onCurrentToolIdChanged() { Qt.callLater(() => toolDropdown.currentValue = root.toolLabel(root.currentToolId)); }
                    }
                }

                SettingsSliderRow {
                    text: I18n.tr("Temperature")
                    description: I18n.tr("Controls response randomness on a 0–200% scale")
                    settingKey: "toolboxAiTemperature"
                    tab: "toolbox"
                    tags: ["toolbox", "ai", "temperature", "randomness"]
                    minimum: 0
                    maximum: 200
                    step: 1
                    value: Math.round((SettingsData.toolboxAiTemperature ?? 0.5) * 100)
                    defaultValue: 50
                    unit: "%"
                    onSliderValueChanged: percent => root.setTemperature(percent)
                }

                SettingsToggleRow {
                    text: I18n.tr("Fade In Text")
                    description: I18n.tr("Animate AI response text as it appears")
                    settingKey: "toolboxAiTextFadeIn"
                    tab: "toolbox"
                    tags: ["toolbox", "ai", "text", "fade", "animation"]
                    checked: SettingsData.toolboxAiTextFadeIn
                    onToggled: checked => SettingsData.set("toolboxAiTextFadeIn", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "description"
                title: I18n.tr("System Prompt File")
                settingKey: "toolboxSystemPrompt"
                tab: "toolbox"
                tags: ["toolbox", "ai", "system", "prompt", "schema", "instructions"]

                SettingsDropdownRow {
                    id: promptFileDropdown
                    text: I18n.tr("Prompt File")
                    description: I18n.tr("System prompt template used by the AI assistant")
                    settingKey: "toolboxAiSystemPromptFile"
                    tab: "toolbox"
                    tags: ["toolbox", "ai", "prompt", "system", "template"]
                    options: Ai.promptFileNames
                    currentValue: Ai.activePromptFileName
                    dropdownWidth: 280
                    enableFuzzySearch: true
                    emptyText: I18n.tr("No prompt files found")
                    onValueChanged: fileName => root.selectPrompt(fileName)

                    Connections {
                        target: Ai
                        function onActivePromptFileNameChanged() { Qt.callLater(() => promptFileDropdown.currentValue = Ai.activePromptFileName); }
                        function onPromptFileNamesChanged() { Qt.callLater(() => promptFileDropdown.currentValue = Ai.activePromptFileName); }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankButton {
                        text: I18n.tr("Add", "Toolbox prompt settings")
                        iconName: "add"
                        onClicked: root.beginCreatePrompt()
                    }

                    DankButton {
                        text: I18n.tr("Rename", "Toolbox prompt settings")
                        iconName: "edit"
                        enabled: root.canManageActivePrompt
                        onClicked: root.beginRenamePrompt()
                    }

                    DankButton {
                        text: I18n.tr("Delete", "Toolbox prompt settings")
                        iconName: "delete"
                        backgroundColor: Theme.error
                        textColor: Theme.primaryText
                        enabled: root.canManageActivePrompt
                        onClicked: root.requestDeletePrompt()
                    }
                }

                StyledText {
                    width: parent.width
                    text: root.hasActivePrompt
                        ? I18n.tr("Editing %1", "Toolbox prompt settings").arg(Ai.activePromptFileName)
                        : I18n.tr("Select a prompt file to edit", "Toolbox prompt settings")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }

                TextArea {
                    id: promptEditor
                    width: parent.width
                    height: 220
                    enabled: root.hasActivePrompt
                    readOnly: !root.hasActivePrompt
                    color: Theme.surfaceText
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.primary
                    font.pixelSize: Theme.fontSizeMedium
                    wrapMode: TextArea.Wrap
                    textFormat: TextEdit.PlainText
                    selectByMouse: true
                    selectByKeyboard: true
                    activeFocusOnTab: true
                    persistentSelection: true
                    leftPadding: Theme.spacingM
                    rightPadding: Theme.spacingM
                    topPadding: Theme.spacingM
                    bottomPadding: Theme.spacingM
                    TextArea.flickable: TextArea {}
                    cursorDelegate: Rectangle {
                        width: 1.5
                        radius: 1
                        color: Theme.surfaceText
                        x: promptEditor.cursorRectangle.x
                        y: promptEditor.cursorRectangle.y
                        height: promptEditor.cursorRectangle.height

                        SequentialAnimation on opacity {
                            running: promptEditor.activeFocus
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
                    onTextChanged: root.promptDraft = text

                    background: Rectangle {
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest
                        border.color: promptEditor.activeFocus ? Theme.primary : Theme.outlineMedium
                        border.width: promptEditor.activeFocus ? 2 : 1
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.hasActivePrompt

                    DankButton {
                        id: savePromptButton
                        text: I18n.tr("Save")
                        iconName: "save"
                        enabled: root.promptDraft !== Ai.activePromptText
                        onClicked: root.savePrompt()
                    }

                    StyledText {
                        width: parent.width - savePromptButton.width - Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Changes are saved to %1", "Toolbox prompt settings").arg(Ai.activePromptFileName)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("Markdown and text prompt files are supported", "Toolbox prompt settings")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: root.showNewPromptRow ? newPromptRow.height + Theme.spacingM * 2 : 0
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer
                    visible: root.showNewPromptRow

                    Row {
                        id: newPromptRow
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingM * 2
                        spacing: Theme.spacingS

                        DankTextField {
                            id: newPromptNameInput
                            width: parent.width - createPromptButton.width - cancelPromptButton.width - Theme.spacingS * 2
                            placeholderText: I18n.tr("Prompt filename")
                            text: root.newPromptFileName
                            onTextEdited: root.newPromptFileName = text
                            onAccepted: root.createPrompt()
                        }

                        DankButton {
                            id: createPromptButton
                            text: I18n.tr("Create")
                            enabled: root.newPromptFileName.trim().length > 0
                            onClicked: root.createPrompt()
                        }

                        DankButton {
                            id: cancelPromptButton
                            text: I18n.tr("Cancel")
                            backgroundColor: "transparent"
                            textColor: Theme.surfaceText
                            onClicked: root.showNewPromptRow = false
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: root.showRenamePromptRow ? renamePromptRow.height + Theme.spacingM * 2 : 0
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer
                    visible: root.showRenamePromptRow

                    Row {
                        id: renamePromptRow
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingM * 2
                        spacing: Theme.spacingS

                        DankTextField {
                            id: renamePromptNameInput
                            width: parent.width - renamePromptButton.width - cancelRenamePromptButton.width - Theme.spacingS * 2
                            placeholderText: I18n.tr("Prompt filename")
                            text: root.renamePromptFileName
                            onTextEdited: root.renamePromptFileName = text
                            onAccepted: root.renamePrompt()
                        }

                        DankButton {
                            id: renamePromptButton
                            text: I18n.tr("Rename")
                            enabled: root.renamePromptFileName.trim().length > 0
                            onClicked: root.renamePrompt()
                        }

                        DankButton {
                            id: cancelRenamePromptButton
                            text: I18n.tr("Cancel")
                            backgroundColor: "transparent"
                            textColor: Theme.surfaceText
                            onClicked: root.showRenamePromptRow = false
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: root.confirmingPromptSwitch ? promptSwitchRow.height + Theme.spacingM * 2 : 0
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer
                    visible: root.confirmingPromptSwitch

                    Row {
                        id: promptSwitchRow
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingM * 2
                        spacing: Theme.spacingS

                        StyledText {
                            width: parent.width - discardPromptButton.width - keepEditingPromptButton.width - Theme.spacingS * 2
                            text: I18n.tr("Discard unsaved changes to \"%1\"?", "Toolbox prompt settings").arg(Ai.activePromptFileName)
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            wrapMode: Text.WordWrap
                            verticalAlignment: Text.AlignVCenter
                        }

                        DankButton {
                            id: discardPromptButton
                            text: I18n.tr("Discard", "Toolbox prompt settings")
                            backgroundColor: Theme.error
                            textColor: Theme.primaryText
                            onClicked: root.runPendingPromptAction()
                        }

                        DankButton {
                            id: keepEditingPromptButton
                            text: I18n.tr("Keep Editing", "Toolbox prompt settings")
                            backgroundColor: "transparent"
                            textColor: Theme.surfaceText
                            onClicked: root.keepEditingPrompt()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: root.confirmingPromptDelete ? deletePromptRow.height + Theme.spacingM * 2 : 0
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer
                    visible: root.confirmingPromptDelete

                    Row {
                        id: deletePromptRow
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingM * 2
                        spacing: Theme.spacingS

                        StyledText {
                            width: parent.width - confirmDeletePromptButton.width - cancelDeletePromptButton.width - Theme.spacingS * 2
                            text: I18n.tr("Delete prompt \"%1\"? This can't be undone.", "Toolbox prompt settings").arg(Ai.activePromptFileName)
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            wrapMode: Text.WordWrap
                            verticalAlignment: Text.AlignVCenter
                        }

                        DankButton {
                            id: confirmDeletePromptButton
                            text: I18n.tr("Delete")
                            backgroundColor: Theme.error
                            textColor: Theme.primaryText
                            onClicked: root.requestDeletePrompt()
                        }

                        DankButton {
                            id: cancelDeletePromptButton
                            text: I18n.tr("Cancel")
                            backgroundColor: "transparent"
                            textColor: Theme.surfaceText
                            onClicked: root.confirmingPromptDelete = false
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "search"
                title: I18n.tr("AI Search")
                settingKey: "toolboxAiSearchEngineBaseUrl"
                tab: "toolbox"
                tags: ["toolbox", "ai", "search", "engine", "url"]

                FocusScope {
                    width: parent.width - Theme.spacingM * 2
                    height: searchUrlColumn.implicitHeight
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM

                    Column {
                        id: searchUrlColumn
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            width: parent.width
                            text: I18n.tr("Search Engine URL")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignLeft
                        }

                        DankTextField {
                            id: searchUrlInput
                            width: parent.width
                            text: root.searchUrlDraft
                            placeholderText: "https://www.google.com/search?q="
                            leftIconName: "link"
                            showClearButton: true
                            onTextEdited: {
                                root.searchUrlDraft = text;
                                root.searchUrlDirty = true;
                            }
                            onEditingFinished: () => root.commitSearchUrl()
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "block"
                title: I18n.tr("Search Exclusions")
                settingKey: "toolboxAiSearchExcludedSites"
                tab: "toolbox"
                tags: ["toolbox", "ai", "search", "exclude", "sites", "domains"]

                FocusScope {
                    width: parent.width - Theme.spacingM * 2
                    height: excludedSitesColumn.implicitHeight
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM

                    Column {
                        id: excludedSitesColumn
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            width: parent.width
                            text: I18n.tr("Excluded Sites")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignLeft
                        }

                        DankTextField {
                            id: excludedSitesInput
                            width: parent.width
                            text: root.excludedSitesDraft
                            placeholderText: I18n.tr("quora.com, facebook.com", "example excluded search domains")
                            leftIconName: "domain_disabled"
                            showClearButton: true
                            onTextEdited: {
                                root.excludedSitesDraft = text;
                                root.excludedSitesDirty = true;
                            }
                            onEditingFinished: () => root.commitExcludedSites()
                        }

                        StyledText {
                            width: parent.width
                            text: I18n.tr("Separate domains with commas")
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignLeft
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "manga"
                title: I18n.tr("Booru Settings")
                settingKey: "toolboxBooru"
                tab: "toolbox"
                tags: ["toolbox", "booru", "image"]

                SettingsDropdownRow {
                    id: providerDropdown
                    text: I18n.tr("Provider")
                    description: Booru.providers[SettingsData.toolboxBooruProvider]?.description ?? I18n.tr("Image provider used by the Toolbox")
                    settingKey: "toolboxBooruProvider"
                    tab: "toolbox"
                    tags: ["toolbox", "booru", "image", "provider"]
                    options: root.providerOptions
                    currentValue: root.providerLabel(SettingsData.toolboxBooruProvider)
                    dropdownWidth: 180
                    enableFuzzySearch: true
                    onValueChanged: label => root.setBooruProvider(label)

                    Connections {
                        target: Booru
                        function onProvidersChanged() { Qt.callLater(() => providerDropdown.currentValue = root.providerLabel(SettingsData.toolboxBooruProvider)); }
                    }

                    Connections {
                        target: SettingsData
                        function onToolboxBooruProviderChanged() { Qt.callLater(() => providerDropdown.currentValue = root.providerLabel(SettingsData.toolboxBooruProvider)); }
                    }
                }

                SettingsSliderRow {
                    text: I18n.tr("Results per Page")
                    description: I18n.tr("Maximum number of images requested per page")
                    settingKey: "toolboxBooruLimit"
                    tab: "toolbox"
                    tags: ["toolbox", "booru", "results", "limit", "page"]
                    minimum: 1
                    maximum: 200
                    step: 1
                    value: SettingsData.toolboxBooruLimit
                    defaultValue: 20
                    unit: ""
                    onSliderValueChanged: value => SettingsData.set("toolboxBooruLimit", value)
                }

                SettingsToggleRow {
                    text: I18n.tr("Allow NSFW Results")
                    description: SettingsData.toolboxBooruProvider === "zerochan" ? I18n.tr("Zerochan only provides safe results") : I18n.tr("Include adult results when supported by the provider")
                    settingKey: "toolboxBooruAllowNsfw"
                    tab: "toolbox"
                    tags: ["toolbox", "booru", "nsfw", "adult", "safe"]
                    checked: SettingsData.toolboxBooruAllowNsfw
                    enabled: SettingsData.toolboxBooruProvider !== "zerochan"
                    onToggled: checked => SettingsData.set("toolboxBooruAllowNsfw", checked)
                }
            }
        }
    }
}
