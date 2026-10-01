import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property int currentTab: 0
    property var tabs: [
        { text: I18n.tr("Timer"), icon: "timer" },
        { text: I18n.tr("Stopwatch"), icon: "av_timer" },
        { text: I18n.tr("Alarm"), icon: "alarm" }
    ]

    focus: true
    activeFocusOnTab: true

    Keys.onPressed: event => {
        if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
            if (event.key === Qt.Key_PageDown)
                tabBar.currentIndex = Math.min(tabBar.currentIndex + 1, tabs.length - 1);
            else
                tabBar.currentIndex = Math.max(tabBar.currentIndex - 1, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_S) {
            if (currentTab === 0) ClockService.toggleTimer();
            else if (currentTab === 1) ClockService.toggleStopwatch();
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            if (currentTab === 0) ClockService.resetTimer();
            else if (currentTab === 1) ClockService.resetStopwatch();
            event.accepted = true;
        } else if (event.key === Qt.Key_L) {
            if (currentTab === 1) ClockService.recordLap();
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        DankTabBar {
            id: tabBar
            Layout.fillWidth: true
            currentIndex: root.currentTab
            model: root.tabs
            showIcons: true
            equalWidthTabs: true
            onTabClicked: index => root.currentTab = index
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Loader {
                anchors.fill: parent
                active: root.currentTab === 0
                sourceComponent: TimerTab {}
            }

            Loader {
                anchors.fill: parent
                active: root.currentTab === 1
                sourceComponent: StopwatchTab {}
            }

            Loader {
                anchors.fill: parent
                active: root.currentTab === 2
                sourceComponent: AlarmTab {}
            }
        }
    }
}
