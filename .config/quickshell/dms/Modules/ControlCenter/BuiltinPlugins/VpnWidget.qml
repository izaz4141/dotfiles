import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    Ref {
        service: NetworkService
    }

    ccWidgetIcon: NetworkService.isBusy ? "sync" : (NetworkService.connected ? "vpn_lock" : "vpn_key_off")
    ccWidgetPrimaryText: I18n.tr("VPN")
    ccWidgetSecondaryText: {
        if (!NetworkService.connected)
            return I18n.tr("Disconnected");
        const names = NetworkService.activeNames || [];
        if (names.length <= 1)
            return names[0] || I18n.tr("Connected");
        return names[0] + " +" + (names.length - 1);
    }
    ccWidgetIsActive: NetworkService.connected

    onCcWidgetToggled: NetworkService.toggleVpn()

    ccDetailContent: Component {
        VpnDetailContent {
            listHeight: 260
        }
    }
}
