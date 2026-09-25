import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Modals.Common
import qs.Modals.FileBrowser
import qs.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root
    visible: false
    layerNamespace: "dms:wifi-qrcode"

    property bool disablePopupTransparency: true
    property string wifiSSID: ""
    property string themedQrCodePath: ""
    property string normalQrCodePath: ""
    modalWidth: 420
    modalHeight: 480
    onBackgroundClicked: hide()
    onOpened: {
        Qt.callLater(() => {
            modalFocusScope.forceActiveFocus();
            contentLoader.item.wifiSSID = wifiSSID;
            contentLoader.item.themedQrCodePath = themedQrCodePath;
            contentLoader.item.saveBrowserLoader = saveBrowserLoader;
        });
    }

    readonly property var lowPriorityCmd: ["nice", "-n", "19", "ionice", "-c3"]
    readonly property string _tmpDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    property string _normalTmpPath: ""
    property bool qrencodeAvailable: false
    property bool qrencodeProbeDone: false
    property string _pendingShowSSID: ""

    function show(ssid) {
        wifiSSID = ssid
        if (qrencodeProbeDone) {
            fetchNetworkQRCode(ssid)
        } else {
            _pendingShowSSID = ssid
        }
    }

    function hide() {
        if (themedQrCodePath !== "") {
            deleteQRCodeFile(themedQrCodePath)
        }
        if (normalQrCodePath !== "") {
            deleteQRCodeFile(normalQrCodePath)
        }
        close()
    }

    function fetchNetworkQRCode(ssid) {
        if (!qrencodeAvailable) {
            ToastService.showError(I18n.tr("qrencode is not installed. Install it to generate WiFi QR codes."))
            return
        }

        _normalTmpPath = _tmpDir + "/dms-wifi-qr-" + Date.now() + ".png"

        wifiPasswordResolver.command = lowPriorityCmd.concat([
            "bash", "-c",
            `CONN=$(nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1 | while read name; do ` +
            `ss=$(nmcli -g 802-11-wireless.ssid connection show "$name" 2>/dev/null); ` +
            `if [ "$ss" = ${JSON.stringify(ssid)} ]; then echo "$name"; break; fi; done | head -1); ` +
            `if [ -n "$CONN" ]; then nmcli -s -g 802-11-wireless-security.psk,802-11-wireless-security.key-mgmt connection show "$CONN"; fi`
        ])
        wifiPasswordResolver.pendingSSID = ssid
        wifiPasswordResolver.running = true
    }

    function generateQrCode(ssid, psk, keyMgmt) {
        const escapedSsid = ssid.replace(/([\\";,:])/g, "\\$1")
        let wifiString = "WIFI:"
        let authType = "nopass"
        if (psk && psk.length > 0) {
            if (keyMgmt === "802-1x") {
                authType = "WPA"
            } else if (psk.length === 5 || psk.length === 13 || /^[0-9a-fA-F]+$/.test(psk)) {
                authType = "WEP"
            } else {
                authType = "WPA"
            }
        }
        if (authType === "nopass") {
            wifiString += `S:${escapedSsid};;`
        } else {
            const escapedPsk = psk.replace(/([\\";,:])/g, "\\$1")
            wifiString += `T:${authType};S:${escapedSsid};P:${escapedPsk};;`
        }

        qrencodeGenerator.command = lowPriorityCmd.concat([
            "qrencode", "-s", "10", "-m", "2", "-o", _normalTmpPath, wifiString
        ])
        qrencodeGenerator.running = true
    }

    function deleteQRCodeFile(path) {
        deleteProcess.command = ["rm", "-f", path]
        deleteProcess.running = true
    }

    Process {
        id: qrencodeProbe
        command: ["sh", "-c", "command -v qrencode"]
        running: false
        onExited: exitCode => {
            root.qrencodeAvailable = (exitCode === 0)
            root.qrencodeProbeDone = true
            const pending = root._pendingShowSSID
            root._pendingShowSSID = ""
            if (pending) {
                root.fetchNetworkQRCode(pending)
            }
        }
    }

    Process {
        id: wifiPasswordResolver
        running: false
        property string pendingSSID: ""

        stdout: StdioCollector {
            id: wifiPasswordStdout
        }

        onExited: exitCode => {
            let psk = ""
            let keyMgmt = ""
            if (exitCode === 0) {
                const raw = (wifiPasswordStdout.text || "").trim()
                if (raw) {
                    const lines = raw.split('\n')
                    for (const line of lines) {
                        const idx = line.indexOf(':')
                        if (idx < 0) continue
                        const key = line.substring(0, idx).trim()
                        const val = line.substring(idx + 1).trim()
                        if (key === "802-11-wireless-security.psk") psk = val
                        else if (key === "802-11-wireless-security.key-mgmt") keyMgmt = val
                    }
                }
            }
            root.generateQrCode(wifiPasswordResolver.pendingSSID, psk, keyMgmt)
        }
    }

    Process {
        id: qrencodeGenerator
        running: false

        onExited: exitCode => {
            if (exitCode !== 0) {
                ToastService.showError(I18n.tr("Failed to generate QR code"))
                return
            }
            root.themedQrCodePath = root._normalTmpPath
            root.normalQrCodePath = root._normalTmpPath
            root.open()
        }
    }

    Process {
        id: deleteProcess
        running: false
    }

    Component.onCompleted: qrencodeProbe.running = true

    LazyLoader {
        id: saveBrowserLoader
        active: false

        FileBrowserSurfaceModal {
            id: saveBrowser

            browserTitle: I18n.tr("Save QR Code")
            browserIcon: "qr_code"
            browserType: "default"
            fileExtensions: ["*.png"]
            allowStacking: true
            saveMode: true
            defaultFileName: `${root.wifiSSID ?? "wifi-qrcode"}.png`
            onFileSelected: path => {
                const cleanPath = decodeURI(path.toString().replace(/^file:\/\//, ''));
                const fileName = cleanPath.split('/').pop();
                const fileUrl = "file://" + cleanPath;

                copyQrCodeProcess.exec(["cp", root.normalQrCodePath, cleanPath, "-f"])
            }

            Process {
                id: copyQrCodeProcess
                stdout: StdioCollector {
                    onStreamFinished: {
                        saveBrowser.close();
                    }
                }
            }
        }
    }

    content: Component {
        Item {
            id: theItem
            property alias themedQrCodePath: qrCodeImg.source
            property var saveBrowserLoader: null
            property string wifiSSID: ""
            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingL

                RowLayout {
                    id: modalTitle
                    width: parent.width

                    StyledText {
                        text: I18n.tr("WiFi QR code for ") + theItem.wifiSSID
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignLeft
                    }

                    DankActionButton {
                        iconName: "save"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: {
                            saveBrowserLoader.active = true;
                            if (saveBrowserLoader.item) {
                                saveBrowserLoader.item.open();
                            }
                        }
                        Layout.alignment: Qt.AlignRight
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: root.hide()
                        Layout.alignment: Qt.AlignRight
                    }
                }

                Image {
                    id: qrCodeImg
                    height: parent.height - parent.spacing - modalTitle.height
                    width: height
                    anchors.horizontalCenter: parent.horizontalCenter

                    MultiEffect {
                        source: qrCodeImg
                        anchors.fill: source
                        colorization: 1.0
                        colorizationColor: Theme.primary
                    }
                }
            }
        }
    }
}
