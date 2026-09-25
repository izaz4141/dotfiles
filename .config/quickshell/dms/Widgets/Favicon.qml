import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common

IconImage {
    id: root
    property string url
    property string displayText

    property real size: 32
    readonly property string downloadUserAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
    property string faviconDownloadPath: Paths.strip(Paths.favicons)
    property string domainName: url.includes("vertexaisearch") ? displayText : StringUtils.getDomain(url)
    property string faviconUrl: `https://www.google.com/s2/favicons?domain=${domainName}&sz=32`
    property string fileName: `${domainName}.ico`
    property string faviconFilePath: `${faviconDownloadPath}/${fileName}`
    property string urlToLoad

    Process {
        id: faviconDownloadProcess
        running: root.url && root.domainName
        command: ["bash", "-c", `[ -f ${root.faviconFilePath} ] || (mkdir -p '${root.faviconDownloadPath}' && curl -s '${root.faviconUrl}' -o '${root.faviconFilePath}' -L -H 'User-Agent: ${root.downloadUserAgent}')`]
        onExited: (exitCode, exitStatus) => {
            root.urlToLoad = root.faviconFilePath
        }
    }

    source: root.urlToLoad
    implicitSize: root.size

    layer.enabled: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: Rectangle {
            width: root.implicitSize
            height: root.implicitSize
            radius: Theme.cornerRadius
        }
    }
}