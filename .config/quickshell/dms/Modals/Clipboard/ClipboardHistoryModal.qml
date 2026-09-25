pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Services

DankModal {
    id: clipboardHistoryModal

    layerNamespace: "dms:clipboard"

    HyprlandFocusGrab {
        windows: [clipboardHistoryModal.contentWindow, clipboardHistoryModal.backgroundWindow]
        active: clipboardHistoryModal.useHyprlandFocusGrab && clipboardHistoryModal.shouldHaveFocus
    }

    property int activeImageLoads: 0
    readonly property int maxConcurrentLoads: 3
    property bool showKeyboardHints: false
    property Component clipboardContent

    function toggle() {
        if (shouldBeVisible) {
            hide()
        } else {
            show()
        }
    }

    function show() {
        open()
        ClipboardService.setSearchText("")
        clipboardHistoryModal.activeImageLoads = 0
        clipboardHistoryModal.shouldHaveFocus = true
        ClipboardService.refresh()
        keyboardController.reset()

        Qt.callLater(function () {
            if (contentLoader.item && contentLoader.item.searchField) {
                contentLoader.item.searchField.text = ""
                contentLoader.item.searchField.forceActiveFocus()
            }
        })
    }

    function hide() {
        close()
        ClipboardService.setSearchText("")
        clipboardHistoryModal.activeImageLoads = 0
        keyboardController.reset()
        cleanupTempFiles()
    }

    function cleanupTempFiles() {
        Quickshell.execDetached(["sh", "-c", "rm -f /tmp/clipboard_*.png"])
    }

    function copyEntry(entry) {
        ClipboardService.copyEntry(entry)
        ToastService.showInfo(I18n.tr("Copied to clipboard"))
        hide()
    }

    function deleteEntry(entry) {
        ClipboardService.deleteEntry(entry)
    }

    function clearAll() {
        ClipboardService.clearAll()
    }

    visible: false
    modalWidth: ClipboardConstants.modalWidth
    modalHeight: ClipboardConstants.modalHeight
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    cornerRadius: Theme.cornerRadius
    borderColor: Theme.outlineMedium
    borderWidth: 1
    enableShadow: true
    onBackgroundClicked: hide()
    modalFocusScope.Keys.onPressed: function (event) {
        keyboardController.handleKey(event)
    }
    content: clipboardContent

    ClipboardKeyboardController {
        id: keyboardController
        modal: clipboardHistoryModal
    }

    ConfirmModal {
        id: clearConfirmDialog
        confirmButtonText: I18n.tr("Clear All")
        confirmButtonColor: Theme.primary
        onVisibleChanged: {
            if (visible) {
                clipboardHistoryModal.shouldHaveFocus = false
            } else if (clipboardHistoryModal.shouldBeVisible) {
                clipboardHistoryModal.shouldHaveFocus = true
                clipboardHistoryModal.modalFocusScope.forceActiveFocus()
                if (clipboardHistoryModal.contentLoader.item && clipboardHistoryModal.contentLoader.item.searchField) {
                    clipboardHistoryModal.contentLoader.item.searchField.forceActiveFocus()
                }
            }
        }
    }

    property var confirmDialog: clearConfirmDialog

    IpcHandler {
        function open(): string {
            clipboardHistoryModal.show()
            return "CLIPBOARD_OPEN_SUCCESS"
        }

        function close(): string {
            clipboardHistoryModal.hide()
            return "CLIPBOARD_CLOSE_SUCCESS"
        }

        function toggle(): string {
            clipboardHistoryModal.toggle()
            return "CLIPBOARD_TOGGLE_SUCCESS"
        }

        target: "clipboard"
    }

    clipboardContent: Component {
        ClipboardContent {
            modal: clipboardHistoryModal
            filteredModel: ClipboardService.filteredModel
            clearConfirmDialog: clipboardHistoryModal.confirmDialog
        }
    }
}
