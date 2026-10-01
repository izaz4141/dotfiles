// Test that ClipboardService.getEntryPreview returns the right thing.
import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"
import "../Services"

Item {
    Component.onCompleted: {
        const lines = [
            "462\t<text>hello world</text>",
            "461\t" + "a".repeat(150),
            "458\t[[ binary data 512 KiB png 474x583 ]]",
            "459\t<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\"><img class=\"image-thumb\" src=\"htt",
            "462\t"
        ]
        for (let i = 0; i < lines.length; i++) {
            const r = ClipboardService.getEntryPreview(lines[i])
            console.warn("PROBE entry[" + i + "] preview=[" + r + "]")
        }
        Quickshell.quit()
    }
}
