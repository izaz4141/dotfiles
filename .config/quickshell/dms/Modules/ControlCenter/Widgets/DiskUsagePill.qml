import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    property string mountPath: "/"
    property string instanceId: ""

    iconName: "storage"

    property var selectedMount: {
        if (!SysMonitorService.diskMounts || SysMonitorService.diskMounts.length === 0) {
            return null;
        }

        const targetMount = SysMonitorService.diskMounts.find(mount => mount.mount === mountPath);
        return targetMount || SysMonitorService.diskMounts.find(mount => mount.mount === "/") || SysMonitorService.diskMounts[0];
    }

    property real usagePercent: {
        if (!selectedMount || !selectedMount.percent) {
            return 0;
        }
        const percentStr = selectedMount.percent.replace("%", "");
        return parseFloat(percentStr) || 0;
    }

    isActive: SysMonitorService.monitorAvailable && selectedMount !== null

    primaryText: {
        if (!SysMonitorService.monitorAvailable) {
            return I18n.tr("Disk Usage");
        }
        if (!selectedMount) {
            return I18n.tr("No disk data");
        }
        return selectedMount.mount;
    }

    secondaryText: {
        if (!SysMonitorService.monitorAvailable) {
            return I18n.tr("dgop not available");
        }
        if (!selectedMount) {
            return I18n.tr("No disk data available");
        }
        return `${selectedMount.used} / ${selectedMount.size} (${usagePercent.toFixed(0)}%)`;
    }

    iconColor: {
        if (!SysMonitorService.monitorAvailable || !selectedMount) {
            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5);
        }
        if (usagePercent > 90) {
            return Theme.error;
        }
        if (usagePercent > 75) {
            return Theme.warning;
        }
        return Theme.surfaceText;
    }

    Component.onCompleted: {
        SysMonitorService.addRef(["diskmounts"]);
    }
    Component.onDestruction: {
        SysMonitorService.removeRef(["diskmounts"]);
    }

    onToggled: {
        expandClicked();
    }
}
