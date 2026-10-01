import QtQuick
import qs.Common
import qs.Services

QtObject {
    id: keyboardController

    required property var modal

    function reset() {
        ClipboardService.selectedIndex = 0
        ClipboardService.keyboardNavigationActive = false
        modal.showKeyboardHints = false
    }

    function selectNext() {
        if (!ClipboardService.filteredModel || ClipboardService.filteredModel.count === 0) {
            return
        }
        ClipboardService.keyboardNavigationActive = true
        ClipboardService.selectedIndex = Math.min(ClipboardService.selectedIndex + 1, ClipboardService.filteredModel.count - 1)
    }

    function selectPrevious() {
        if (!ClipboardService.filteredModel || ClipboardService.filteredModel.count === 0) {
            return
        }
        ClipboardService.keyboardNavigationActive = true
        ClipboardService.selectedIndex = Math.max(ClipboardService.selectedIndex - 1, 0)
    }

    function copySelected() {
        if (!ClipboardService.filteredModel || ClipboardService.filteredModel.count === 0 || ClipboardService.selectedIndex < 0 || ClipboardService.selectedIndex >= ClipboardService.filteredModel.count) {
            return
        }
        const selectedEntry = ClipboardService.filteredModel.get(ClipboardService.selectedIndex).entry
        modal.copyEntry(selectedEntry)
    }

    function deleteSelected() {
        if (!ClipboardService.filteredModel || ClipboardService.filteredModel.count === 0 || ClipboardService.selectedIndex < 0 || ClipboardService.selectedIndex >= ClipboardService.filteredModel.count) {
            return
        }
        const selectedEntry = ClipboardService.filteredModel.get(ClipboardService.selectedIndex).entry
        modal.deleteEntry(selectedEntry)
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (ClipboardService.keyboardNavigationActive) {
                ClipboardService.keyboardNavigationActive = false
                event.accepted = true
            } else {
                modal.hide()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
            if (!ClipboardService.keyboardNavigationActive) {
                ClipboardService.keyboardNavigationActive = true
                ClipboardService.selectedIndex = 0
                event.accepted = true
            } else {
                selectNext()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
            if (!ClipboardService.keyboardNavigationActive) {
                ClipboardService.keyboardNavigationActive = true
                ClipboardService.selectedIndex = 0
                event.accepted = true
            } else if (ClipboardService.selectedIndex === 0) {
                ClipboardService.keyboardNavigationActive = false
                event.accepted = true
            } else {
                selectPrevious()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier) {
            if (!ClipboardService.keyboardNavigationActive) {
                ClipboardService.keyboardNavigationActive = true
                ClipboardService.selectedIndex = 0
            } else {
                selectNext()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier) {
            if (!ClipboardService.keyboardNavigationActive) {
                ClipboardService.keyboardNavigationActive = true
                ClipboardService.selectedIndex = 0
            } else if (ClipboardService.selectedIndex === 0) {
                ClipboardService.keyboardNavigationActive = false
            } else {
                selectPrevious()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier) {
            if (!ClipboardService.keyboardNavigationActive) {
                ClipboardService.keyboardNavigationActive = true
                ClipboardService.selectedIndex = 0
            } else {
                selectNext()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier) {
            if (!ClipboardService.keyboardNavigationActive) {
                ClipboardService.keyboardNavigationActive = true
                ClipboardService.selectedIndex = 0
            } else if (ClipboardService.selectedIndex === 0) {
                ClipboardService.keyboardNavigationActive = false
            } else {
                selectPrevious()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
            modal.clearAll()
            modal.hide()
            event.accepted = true
        } else if (ClipboardService.keyboardNavigationActive) {
            if ((event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                copySelected()
                event.accepted = true
            } else if (event.key === Qt.Key_Delete) {
                deleteSelected()
                event.accepted = true
            }
        }
        if (event.key === Qt.Key_F10) {
            modal.showKeyboardHints = !modal.showKeyboardHints
            event.accepted = true
        }
    }
}
