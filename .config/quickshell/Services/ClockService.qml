pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property var timerPresets: [
        { label: "1m", seconds: 60 },
        { label: "5m", seconds: 300 },
        { label: "10m", seconds: 600 },
        { label: "15m", seconds: 900 },
        { label: "30m", seconds: 1800 },
        { label: "1h", seconds: 3600 }
    ]

    // --- Timer ---
    property int timerDuration: 0
    property int timerRemaining: 600
    property bool timerRunning: false
    property bool timerPaused: false
    property bool timerRinging: false
    property int _timerStartEpoch: 0
    property var _timerLive: null
    property var _timerFinished: null
    signal timerFinished

    function getSeconds() {
        return Math.floor(Date.now() / 1000);
    }

    function setTimerDuration(seconds) {
        if (timerRunning) return;
        timerDuration = Math.max(1, seconds);
        timerRemaining = timerDuration;
        timerPaused = false;
        timerRinging = false;
    }

    function _formatRemaining(sec) {
        const hh = Math.floor(sec / 3600).toString().padStart(2, "0");
        const mm = Math.floor(sec / 60) % 60;
        const ss = sec % 60;
        return `${hh}:${mm.toString().padStart(2, "0")}:${ss.toString().padStart(2, "0")}`;
    }

    function _timerProgress() {
        if (timerDuration <= 0) return 100;
        return Math.max(0, Math.min(100, Math.round((timerRemaining / timerDuration) * 100)));
    }

    function _startTimerNotif() {
        root._dismissTimerNotifs();
        root._timerLive = NotificationService.sendNotification({
            appName: "Clock",
            appIcon: "material:timer",
            summary: I18n.tr("Timer"),
            body: _formatRemaining(timerDuration),
            urgency: NotificationUrgency.Critical,
            isClockLive: true,
            liveProgress: root._timerProgress(),
            dismissable: false,
            actions: [{ identifier: "silence", text: I18n.tr("Silence"), invoke: () => root.resetTimer() }]
        });
    }

    function _dismissTimerLive() {
        if (root._timerLive) {
            NotificationService.dismissSentNotification(root._timerLive);
            root._timerLive = null;
        }
    }

    function _dismissTimerFinished() {
        if (root._timerFinished) {
            NotificationService.dismissSentNotification(root._timerFinished);
            root._timerFinished = null;
        }
    }

    function _dismissTimerNotifs() {
        root._dismissTimerLive();
        root._dismissTimerFinished();
    }

    function silenceTimer() {
        AudioService.stopTimerFinished();
        timerRinging = false;
        root._dismissTimerNotifs();
    }

    function startTimer() {
        if (timerRunning) return;
        if (timerRinging) return;
        if (timerRemaining <= 0)
            timerRemaining = timerDuration;
        _timerStartEpoch = getSeconds() - (timerDuration - timerRemaining);
        timerRunning = true;
        timerPaused = false;
        root._startTimerNotif();
    }

    function pauseTimer() {
        if (!timerRunning) return;
        timerRemaining = Math.max(0, timerDuration - (getSeconds() - _timerStartEpoch));
        timerRunning = false;
        timerPaused = true;
    }

    function toggleTimer() {
        if (timerRunning) pauseTimer();
        else startTimer();
    }

    function resetTimer() {
        if (timerRinging)
            AudioService.stopTimerFinished();
        timerRinging = false;
        root._dismissTimerNotifs();
        timerRunning = false;
        timerPaused = false;
        timerRemaining = timerDuration;
    }

    function refreshTimer() {
        if (!timerRunning) return;
        timerRemaining = Math.max(0, timerDuration - (getSeconds() - _timerStartEpoch));
        if (timerRemaining <= 0) {
            timerRunning = false;
            timerPaused = false;
            timerRinging = true;
            if (SettingsData.soundsEnabled)
                AudioService.playTimerFinished();
            root._dismissTimerLive();
            root._timerFinished = NotificationService.sendNotification({
                appName: "Clock",
                appIcon: "material:timer",
                summary: I18n.tr("Timer finished"),
                body: I18n.tr("Timer completed") + " (" + _formatRemaining(timerDuration) + ")",
                urgency: NotificationUrgency.Critical,
                isClockLive: false,
                actions: [{ identifier: "silence", text: I18n.tr("Silence"), invoke: () => root.silenceTimer() }]
            });
            timerFinished();
        }
    }

    Timer {
        id: timerTick
        interval: 200
        running: root.timerRunning
        repeat: true
        onTriggered: root.refreshTimer()
    }

    Timer {
        id: timerNotifTick
        interval: 1000
        running: root.timerRunning && !root.timerRinging && root._timerLive
        repeat: true
        onTriggered: {
            NotificationService.updateSentNotification(root._timerLive, {
                liveProgress: root._timerProgress(),
                body: _formatRemaining(root.timerRemaining)
            });
        }
    }

    // --- Stopwatch ---
    property bool stopwatchRunning: false
    property real stopwatchTime: 0
    property real _stopwatchStart: 0
    property var stopwatchLaps: []

    function toggleStopwatch() {
        if (stopwatchRunning) pauseStopwatch();
        else resumeStopwatch();
    }

    function resumeStopwatch() {
        if (stopwatchTime === 0) stopwatchLaps = [];
        _stopwatchStart = Date.now() - stopwatchTime;
        stopwatchRunning = true;
    }

    function pauseStopwatch() {
        if (!stopwatchRunning) return;
        stopwatchTime = Date.now() - _stopwatchStart;
        stopwatchRunning = false;
    }

    function resetStopwatch() {
        stopwatchRunning = false;
        stopwatchTime = 0;
        stopwatchLaps = [];
    }

    function recordLap() {
        if (!stopwatchRunning) return;
        const cum = Date.now() - _stopwatchStart;
        stopwatchLaps = stopwatchLaps.concat([cum]);
    }

    function refreshStopwatch() {
        if (stopwatchRunning) stopwatchTime = Date.now() - _stopwatchStart;
    }

    Timer {
        id: stopwatchTick
        interval: 50
        running: root.stopwatchRunning
        repeat: true
        onTriggered: root.refreshStopwatch()
    }

    // --- Alarm ---
    property var alarms: []
    property var _lastFires: ({})

    function _syncAlarms() {
        root.alarms = (SettingsData.alarms || []).slice();
    }
    property var _snoozedAlarmId: ""
    property int ringingAlarmIndex: -1
    property var ringingAlarm: null
    property var _alarmNotif: null

    signal alarmTriggered(int index)

    function _sendAlarmNotif(a) {
        root._dismissAlarmNotif();
        root._alarmNotif = NotificationService.sendNotification({
            appName: "Clock",
            appIcon: "material:alarm",
            summary: I18n.tr("Alarm"),
            body: a.label || I18n.tr("Alarm ringing"),
            urgency: NotificationUrgency.Critical,
            isClockLive: false,
            actions: [{ identifier: "silence", text: I18n.tr("Silence"), invoke: () => root.dismissRingingAlarm() }]
        });
    }

    function _dismissAlarmNotif() {
        if (root._alarmNotif) {
            NotificationService.dismissSentNotification(root._alarmNotif);
            root._alarmNotif = null;
        }
    }

    Timer {
        id: alarmSnoozeTimer
        interval: 300000
        repeat: false
        onTriggered: {
            const id = root._snoozedAlarmId;
            root._snoozedAlarmId = "";
            const idx = root.alarms.findIndex(a => a.id === id);
            if (idx < 0) return;
            const a = root.alarms[idx];
            if (!a.enabled) return;
            root._lastFires[id] = Math.floor(Date.now() / 60000);
            root.ringingAlarmIndex = idx;
            root.ringingAlarm = a;
            if (SettingsData.soundsEnabled)
                AudioService.playAlarmRing();
            root._sendAlarmNotif(a);
            root.alarmTriggered(idx);
        }
    }

    function addAlarm(hour, minute, label, days) {
        const list = alarms.slice();
        list.push({
            id: Date.now().toString(36) + Math.floor(Math.random() * 1000),
            hour: hour,
            minute: minute,
            label: label || "",
            days: days || [],
            enabled: true
        });
        SettingsData.set("alarms", list);
    }

    function removeAlarm(id) {
        SettingsData.set("alarms", alarms.filter(a => a.id !== id));
    }

    function updateAlarm(id, props) {
        SettingsData.set("alarms", alarms.map(a => {
            if (a.id !== id) return a;
            const copy = {};
            for (const k in a) copy[k] = a[k];
            for (const k in props) copy[k] = props[k];
            return copy;
        }));
    }

    function toggleAlarmEnabled(id) {
        const a = alarms.find(x => x.id === id);
        if (a) updateAlarm(id, { enabled: !a.enabled });
    }

    function getNextAlarmTime(alarm) {
        const now = new Date();
        const nowMs = now.getTime();
        if (!alarm.days || alarm.days.length === 0) {
            const next = new Date(now.getFullYear(), now.getMonth(), now.getDate(), alarm.hour, alarm.minute, 0, 0);
            if (next.getTime() <= nowMs)
                next.setDate(next.getDate() + 1);
            return next;
        }
        for (let i = 0; i < 8; i++) {
            const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + i, alarm.hour, alarm.minute, 0, 0);
            const weekday = (d.getDay() + 6) % 7;
            if (alarm.days.includes(weekday) && d.getTime() > nowMs)
                return d;
        }
        return null;
    }

    function checkAlarms() {
        if (ringingAlarmIndex >= 0) return;
        const list = alarms || [];
        const nowMs = Date.now();
        const nowMinute = Math.floor(nowMs / 60000);
        for (let i = 0; i < list.length; i++) {
            const a = list[i];
            if (!a.enabled) continue;
            if (_lastFires[a.id] === nowMinute) continue;
            const next = getNextAlarmTime(a);
            if (!next) continue;
            const diff = next.getTime() - nowMs;
            if (diff >= 0 && diff <= 1500) {
                _lastFires[a.id] = nowMinute;
                ringingAlarmIndex = i;
                ringingAlarm = a;
                if (SettingsData.soundsEnabled)
                    AudioService.playAlarmRing();
                root._sendAlarmNotif(a);
                alarmTriggered(i);
                break;
            }
        }
    }

    function dismissRingingAlarm() {
        if (ringingAlarmIndex < 0) return;
        const a = alarms[ringingAlarmIndex];
        AudioService.stopAlarmRing();
        if (a && (!a.days || a.days.length === 0))
            root.updateAlarm(a.id, { enabled: false });
        ringingAlarmIndex = -1;
        ringingAlarm = null;
        root._dismissAlarmNotif();
    }

    function snoozeAlarm() {
        if (ringingAlarmIndex < 0) return;
        const a = alarms[ringingAlarmIndex];
        AudioService.stopAlarmRing();
        _snoozedAlarmId = a ? a.id : "";
        ringingAlarmIndex = -1;
        ringingAlarm = null;
        root._dismissAlarmNotif();
        alarmSnoozeTimer.restart();
    }

    Timer {
        id: alarmTick
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.checkAlarms()
    }

    Component.onCompleted: root._syncAlarms()

    Connections {
        target: SettingsData
        function onAlarmsChanged() { root._syncAlarms() }
    }

    Connections {
        target: NotificationService
        function onAllWrappersChanged() {
            if (root._timerFinished && NotificationService.allWrappers.indexOf(root._timerFinished) < 0 && root.timerRinging) {
                root._timerFinished = null;
                root.silenceTimer();
            }
            if (root._timerLive && NotificationService.allWrappers.indexOf(root._timerLive) < 0) {
                root._timerLive = null;
            }
            if (root._alarmNotif && NotificationService.allWrappers.indexOf(root._alarmNotif) < 0 && root.ringingAlarmIndex >= 0) {
                root._alarmNotif = null;
                root.dismissRingingAlarm();
            }
        }
    }
}
