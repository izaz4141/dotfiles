import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

DankButton {
    id: root

    property string query
    property string engineBaseUrl: typeof SettingsData !== "undefined" ? SettingsData.toolboxAiSearchEngineBaseUrl : "https://www.google.com/search?q="
    property var excludedSites: typeof SettingsData !== "undefined" ? SettingsData.toolboxAiSearchExcludedSites : []

    height: 30
    minWidth: 0
    horizontalPadding: 8
    radius: Math.max(4, Appearance.rounding.small - 4)
    backgroundColor: Theme.surfaceContainerHighest
    textColor: Theme.surfaceText

    onClicked: {
        let url = root.engineBaseUrl + root.query;
        for (const site of root.excludedSites)
            url += ` -site:${site}`;
        Qt.openUrlExternally(url);
    }

    contentItem: Item {
        anchors.centerIn: parent
        implicitWidth: rowLayout.implicitWidth
        implicitHeight: rowLayout.implicitHeight

        RowLayout {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 5

            DankIcon {
                name: "search"
                size: 20
                color: Theme.surfaceText
            }

            StyledText {
                horizontalAlignment: Text.AlignHCenter
                text: root.query
                color: Theme.surfaceText
            }
        }
    }
}