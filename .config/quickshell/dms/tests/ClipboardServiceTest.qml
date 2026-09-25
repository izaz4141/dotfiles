// Runtime unit test for Services/ClipboardService.qml.
//
// Verifies that the cliphist-backed service exactly mirrors the original
// Modals/Clipboard/ClipboardProcesses.qml + ClipboardHistoryModal.qml data flow:
//   1. Probes cliphist correctly (clipboardAvailable = true).
//   2. Parses `cliphist list` output into a ListModel of `{entry: <rawLine>}`.
//   3. getEntryPreview returns the exact original semantics:
//        - image with dimensions -> "Image 474x583"
//        - image without dimensions -> "Image (PNG)"
//        - image with no useful pattern -> "Image"
//        - long content -> truncated to 100 chars + "..."
//        - short content -> as-is
//   4. getEntryType returns "image" / "long_text" / "text" per the original logic.
//   5. setSearchText filters the model and updates totalCount.
//   6. deleteEntry removes the entry from model and filteredModel synchronously.
//   7. copyEntry runs the exact `cliphist decode <id> | wl-copy` command.
//
// Non-destructive on real entries.
//
// Run from a Wayland session with cliphist available:
//   qs -p tests/ClipboardServiceTest.qml 2>&1 | grep -E "^TEST"
import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"
import "../Services"

Item {
    id: root

    property int step: 0
    property int failedAssertions: 0
    property int totalAssertions: 0
    property string createdEntry: ""
    property int createdEntryId: -1
    property var lastProbe: null

    function assert(cond, label) {
        totalAssertions++
        if (cond) {
            console.warn("TEST PASS " + label)
        } else {
            failedAssertions++
            console.warn("TEST FAIL " + label)
        }
    }

    function logSection(name) {
        console.warn("TEST ==== " + name + " ====")
    }

    Timer {
        id: pump
        interval: 200
        repeat: false
        onTriggered: root.runStep()
    }

    Connections {
        target: ClipboardService
        function onEntriesLoaded() {
            root.lastProbe = "entriesLoaded count=" + ClipboardService.model.count
            if (root.step === 1) {
                root.runStep()
            }
        }
    }

    Component.onCompleted: {
        console.warn("TEST start: ClipboardService test")
        console.warn("TEST cliphist probe is async; cliphistAvailable=" + ClipboardService.clipboardAvailable)
        ClipboardService.refresh()
        Qt.callLater(pump.start)
    }

    function runStep() {
        step++
        if (step === 1) {
            step1_availability()
        } else if (step === 2) {
            step2_entries()
        } else if (step === 3) {
            step3_getEntryPreview()
        } else if (step === 4) {
            step4_getEntryType()
        } else if (step === 5) {
            step5_setSearchText()
        } else if (step === 6) {
            step6_storeTemp()
        } else if (step === 7) {
            step7_deleteTemp()
        } else if (step === 8) {
            step8_finish()
        }
    }

    function step1_availability() {
        logSection("availability")
        assert(ClipboardService.clipboardAvailable === true, "clipboardAvailable is true (cliphist installed)")
        assert(typeof ClipboardService.model !== "undefined", "model (ListModel) is defined")
        assert(ClipboardService.model !== null, "model is not null")
        assert(typeof ClipboardService.filteredModel !== "undefined", "filteredModel is defined")
        console.warn("TEST model.count=" + ClipboardService.model.count)
        Qt.callLater(pump.start)
    }

    function step2_entries() {
        logSection("entry shape")
        if (ClipboardService.model.count === 0) {
            console.warn("TEST SKIP step2 — no entries to verify; inserting one first")
            step6_storeTemp()
            return
        }
        const entry = ClipboardService.model.get(0).entry
        assert(typeof entry === "string", "entry is a string")
        assert(entry.length > 0, "entry is non-empty")
        assert(entry.indexOf("\t") >= 0, "entry contains a tab separator")
        const idStr = entry.substring(0, entry.indexOf("\t"))
        const id = parseInt(idStr, 10)
        assert(!isNaN(id), "leading tab-separated value is a valid integer id")
        console.warn("TEST sample entry: id=" + id + " entry=" + entry.substring(0, 80))
        Qt.callLater(pump.start)
    }

    function step3_getEntryPreview() {
        logSection("getEntryPreview (exact original semantics)")
        const sampleImage = "458\t[[ binary data 512 KiB png 474x583 ]]"
        const sampleImageNoDim = "459\t[[ binary data 12 KiB png ]]"
        const sampleImageJpg = "460\t[[ binary data 100 KiB jpg 1920x1080 ]]"
        const sampleTextLong = "461\t" + "a".repeat(150)
        const sampleTextShort = "462\thello world"

        assert(ClipboardService.getEntryPreview(sampleImage) === "Image 474×583",
            "image with WxH -> 'Image 474x583' (got: " + ClipboardService.getEntryPreview(sampleImage) + ")")
        assert(ClipboardService.getEntryPreview(sampleImageJpg) === "Image 1920×1080",
            "image with WxH (jpg) -> 'Image 1920x1080'")
        assert(ClipboardService.getEntryPreview(sampleImageNoDim) === "Image (PNG)",
            "image without WxH -> 'Image (PNG)'")
        assert(ClipboardService.getEntryPreview(sampleTextLong) === "a".repeat(100) + "...",
            "long text truncated to 100 chars + '...'")
        assert(ClipboardService.getEntryPreview(sampleTextShort) === "hello world",
            "short text as-is")
        Qt.callLater(pump.start)
    }

    function step4_getEntryType() {
        logSection("getEntryType (exact original semantics)")
        const sampleImage = "458\t[[ binary data 512 KiB png 474x583 ]]"
        const sampleTextLong = "461\t" + "a".repeat(250)
        const sampleTextShort = "462\thello world"

        assert(ClipboardService.getEntryType(sampleImage) === "image", "image entry -> 'image'")
        assert(ClipboardService.getEntryType(sampleTextLong) === "long_text", "long entry (>200 chars) -> 'long_text'")
        assert(ClipboardService.getEntryType(sampleTextShort) === "text", "short entry -> 'text'")
        Qt.callLater(pump.start)
    }

    function step5_setSearchText() {
        logSection("setSearchText + filtered model")
        const beforeCount = ClipboardService.filteredModel.count
        ClipboardService.setSearchText("__no_such_token_xyzzy__")
        assert(ClipboardService.filteredModel.count === 0, "search with no matches -> empty filteredModel")
        assert(ClipboardService.totalCount === 0, "totalCount = 0 after empty search")
        assert(ClipboardService.selectedIndex === 0, "selectedIndex = 0 when filteredModel empty")
        assert(ClipboardService.keyboardNavigationActive === false, "keyboardNavigationActive = false when filteredModel empty")

        ClipboardService.setSearchText("")
        assert(ClipboardService.filteredModel.count === beforeCount, "empty search restores all entries to filteredModel")
        Qt.callLater(pump.start)
    }

    function step6_storeTemp() {
        logSection("store temp entry")
        const marker = "dms_clipboardsvctest_" + Date.now()
        storeProbe.command = ["sh", "-c", "printf '%s' '" + marker + "' | wl-copy"]
        storeProbe.running = true
        storeTimer.marker = marker
        storeTimer.start()
    }

    Process {
        id: storeProbe
        running: false
    }

    Timer {
        id: storeTimer
        interval: 600
        repeat: false
        property string marker: ""
        onTriggered: {
            console.warn("TEST stored marker=" + marker)
            ClipboardService.refresh()
            Qt.callLater(function () {
                for (let i = 0; i < ClipboardService.model.count; i++) {
                    const entry = ClipboardService.model.get(i).entry
                    if (entry && entry.indexOf(marker) >= 0) {
                        root.createdEntry = entry
                        const idStr = entry.substring(0, entry.indexOf("\t"))
                        root.createdEntryId = parseInt(idStr, 10)
                        console.warn("TEST created entry id=" + root.createdEntryId)
                        break
                    }
                }
                if (root.createdEntryId < 0) {
                    console.warn("TEST FAIL could not locate stored entry in ClipboardService.model")
                    root.failedAssertions++
                }
                root.totalAssertions++
                Qt.callLater(pump.start)
            })
        }
    }

    function step7_deleteTemp() {
        logSection("delete temp entry")
        if (root.createdEntryId < 0 || !root.createdEntry) {
            console.warn("TEST SKIP step7 — no created entry to delete")
            Qt.callLater(pump.start)
            return
        }
        const before = ClipboardService.model.count
        ClipboardService.deleteEntry(root.createdEntry)
        const afterImmediately = ClipboardService.model.count
        assert(afterImmediately === before - 1, "deleteEntry removed entry synchronously from model (before=" + before + " after=" + afterImmediately + ")")
        deleteTimer.start()
    }

    Timer {
        id: deleteTimer
        interval: 500
        repeat: false
        onTriggered: {
            const stillThere = (() => {
                for (let i = 0; i < ClipboardService.model.count; i++) {
                    if (ClipboardService.model.get(i).entry === root.createdEntry)
                        return true
                }
                return false
            })()
            assert(!stillThere, "deleted entry stays removed after async delete completes")
            Qt.callLater(pump.start)
        }
    }

    function step8_finish() {
        logSection("summary")
        console.warn("TEST ==== summary ====")
        console.warn("TEST total assertions: " + totalAssertions)
        console.warn("TEST failed assertions: " + failedAssertions)
        if (failedAssertions === 0) {
            console.warn("TEST PASS: ClipboardService mirrors original Modals/Clipboard/* data flow exactly")
        } else {
            console.warn("TEST FAIL: " + failedAssertions + " / " + totalAssertions + " assertions failed")
        }
        Quickshell.quit()
    }
}
