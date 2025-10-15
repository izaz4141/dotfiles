import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    property string mountPath: "/"
    property string instanceId: ""

    iconName: "storage"

    property var selectedMount: {
        if (!MoboService.storageMap || MoboService.storageMap.length === 0) {
            return null
        }

        const targetMount = MoboService.storageMap.find(storage => storage.mountPoint === mountPath)
        return targetMount || MoboService.storageMap.find(storage => storage.mountPoint === "/") || MoboService.storageMap[0]
    }

    property real usagePercent: {
        if (!selectedMount || !selectedMount.percent) {
            return 0
        }
        return parseFloat(selectedMount.percent * 100) || 0
    }

    isActive: MoboService.storagePerc && selectedMount !== null

    primaryText: {
        if (!MoboService.storagePerc) {
            return "Disk Usage"
        }
        if (!selectedMount) {
            return "No disk data"
        }
        return selectedMount.device
    }

    secondaryText: {
        if (!MoboService.storagePerc) {
            return "dgop not available"
        }
        if (!selectedMount) {
            return "No disk data available"
        }
        return `${MoboService.formatKib(selectedMount.used)} / ${MoboService.formatKib(selectedMount.total)} (${usagePercent.toFixed(0)}%)`
    }

    iconColor: {
        if (!MoboService.storagePerc || !selectedMount) {
            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
        }
        if (usagePercent > 90) {
            return Theme.error
        }
        if (usagePercent > 75) {
            return Theme.warning
        }
        return Theme.surfaceText
    }

    Component.onCompleted: {
        MoboService.refCount++
    }
    Component.onDestruction: {
        MoboService.refCount--
    }

    onToggled: {
        expandClicked()
    }
}