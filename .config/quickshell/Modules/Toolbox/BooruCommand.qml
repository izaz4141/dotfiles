pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property string commandPrefix: "/"

    readonly property var commands: [{
        "name": "mode",
        "icon": "api",
        "description": I18n.tr("Set the current API provider", "Booru"),
        "execute": args => Booru.setProvider(args[0] || Booru.providerList[0])
    }, {
        "name": "clear",
        "icon": "delete_sweep",
        "description": I18n.tr("Clear the current list of images", "Booru"),
        "execute": () => Booru.clearResponses()
    }, {
        "name": "next",
        "icon": "arrow_forward",
        "description": I18n.tr("Get the next page of results", "Booru"),
        "execute": () => Booru.nextPage()
    }, {
        "name": "safe",
        "icon": "no_adult_content",
        "description": I18n.tr("Disable NSFW content", "Booru"),
        "execute": () => SettingsData.set("toolboxBooruAllowNsfw", false)
    }, {
        "name": "lewd",
        "icon": "visibility",
        "description": I18n.tr("Allow NSFW content", "Booru"),
        "execute": () => SettingsData.set("toolboxBooruAllowNsfw", true)
    }]

    function commandIcon(name) {
        return root.commands.find(cmd => cmd.name === name)?.icon ?? "";
    }
}
