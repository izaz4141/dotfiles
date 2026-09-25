pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    // ── Brightness properties ──
    property bool brightnessAvailable: devices.length > 0
    property var devices: []
    property var ddcDevices: []
    property var deviceBrightness: ({})
    property var ddcPendingInit: ({})
    property string currentDevice: ""
    property string lastIpcDevice: ""
    property bool ddcAvailable: false
    property var ddcInitQueue: []
    property bool skipDdcRead: false
    property int brightnessLevel: {
        const deviceToUse = lastIpcDevice === "" ? getDefaultDevice() : (lastIpcDevice || currentDevice)
        if (!deviceToUse) {
            return 50
        }
        return getDeviceBrightness(deviceToUse)
    }
    property int maxBrightness: 100
    property bool brightnessInitialized: false

    // ── Gamma / night mode properties ──
    property bool gammaControlAvailable: false
    property bool nightModeActive: nightModeEnabled
    property bool nightModeEnabled: false
    property int gammaCurrentTemp: 0
    property bool gammaIsDay: true
    property string gammaSunriseTime: ""
    property string gammaSunsetTime: ""
    property string gammaNextTransition: ""
    property bool automationAvailable: false
    property bool geoclueAvailable: false
    property bool geoclueAgentRunning: false
    property bool isAutomaticNightTime: false

    property int gradualFromTemp: 0
    property int gradualToTemp: 0
    property int gradualSteps: 0
    property int gradualStepIndex: 0
    property real gradualIntervalMs: 0

    signal brightnessChanged
    signal deviceSwitched

    // ── Sunrise / sunset calculation (NOAA algorithm) ──

    function toJulianDay(year, month, day) {
        if (month <= 2) {
            year -= 1
            month += 12
        }
        const A = Math.floor(year / 100)
        const B = 2 - A + Math.floor(A / 4)
        return Math.floor(365.25 * (year + 4716)) + Math.floor(30.6001 * (month + 1)) + day + B - 1524.5
    }

    function toCentury(jd) {
        return (jd - 2451545.0) / 36525.0
    }

    function sunMeanLongitude(T) {
        return (280.46646 + T * (36000.76983 + 0.0003032 * T)) % 360
    }

    function sunMeanAnomaly(T) {
        return 357.52911 + T * (35999.05029 - 0.0001537 * T)
    }

    function sunEquationOfCenter(T) {
        const M = sunMeanAnomaly(T)
        const Mrad = M * Math.PI / 180
        return Math.sin(Mrad) * (1.914602 - T * (0.004817 + 0.000014 * T)) + Math.sin(2 * Mrad) * (0.019993 - 0.000101 * T) + Math.sin(3 * Mrad) * 0.000289
    }

    function sunApparentLongitude(T) {
        const omega = 125.04 - 1934.136 * T
        return sunMeanLongitude(T) + sunEquationOfCenter(T) - 0.00569 - 0.00478 * Math.sin(omega * Math.PI / 180)
    }

    function meanObliquityOfEcliptic(T) {
        const seconds = 21.448 - T * (46.8150 + T * (0.00059 - T * 0.001813))
        return 23.0 + (26.0 + seconds / 60.0) / 60.0
    }

    function obliquityCorrection(T) {
        const omega = 125.04 - 1934.136 * T
        return meanObliquityOfEcliptic(T) + 0.00256 * Math.cos(omega * Math.PI / 180)
    }

    function sunDeclination(T) {
        const e = obliquityCorrection(T) * Math.PI / 180
        const lambda = sunApparentLongitude(T) * Math.PI / 180
        return Math.asin(Math.sin(e) * Math.sin(lambda)) * 180 / Math.PI
    }

    function equationOfTime(T) {
        const epsilon = obliquityCorrection(T) * Math.PI / 180
        const l0 = sunMeanLongitude(T) * Math.PI / 180
        const m = sunMeanAnomaly(T) * Math.PI / 180
        let y = Math.tan(epsilon / 2) * Math.tan(epsilon / 2)
        let Etime = y * Math.sin(2 * l0) - 2 * 0.01671 * Math.sin(m) + 4 * 0.01671 * y * Math.sin(m) * Math.cos(2 * l0) - 0.5 * y * y * Math.sin(4 * l0) - 1.25 * 0.01671 * 0.01671 * Math.sin(2 * m)
        return Etime * 180 / Math.PI * 4
    }

    function hourAngleSunrise(lat, declination) {
        const latRad = lat * Math.PI / 180
        const decRad = declination * Math.PI / 180
        const cosHA = -Math.tan(latRad) * Math.tan(decRad)
        if (cosHA < -1) return 180
        if (cosHA > 1) return 0
        return Math.acos(cosHA) * 180 / Math.PI
    }

    function calculateSunriseSunset(latitude, longitude) {
        const now = new Date()
        const year = now.getFullYear()
        const month = now.getMonth() + 1
        const day = now.getDate()

        const jd = toJulianDay(year, month, day)
        const T = toCentury(jd)

        const declination = sunDeclination(T)
        const eqTime = equationOfTime(T)
        const HA = hourAngleSunrise(latitude, declination)

        const noonUTC = 720 - 4 * longitude - eqTime
        const sunriseUTC = noonUTC - HA * 4
        const sunsetUTC = noonUTC + HA * 4

        const tzOffset = -now.getTimezoneOffset() / 60

        const sunriseDate = new Date((jd + sunriseUTC / 1440 - 0.5) * 86400000)
        sunriseDate.setHours(sunriseDate.getHours() + tzOffset)

        const sunsetDate = new Date((jd + sunsetUTC / 1440 - 0.5) * 86400000)
        sunsetDate.setHours(sunsetDate.getHours() + tzOffset)

        return {
            "sunrise": sunriseDate.toISOString(),
            "sunset": sunsetDate.toISOString()
        }
    }

    function computeIsDaytime(latitude, longitude) {
        if (!latitude && !longitude) return true

        const now = new Date()
        const year = now.getFullYear()
        const month = now.getMonth() + 1
        const day = now.getDate()

        const jd = toJulianDay(year, month, day)
        const T = toCentury(jd)
        const declination = sunDeclination(T)
        const eqTime = equationOfTime(T)

        const noonUTC = 720 - 4 * longitude - eqTime
        const HA = hourAngleSunrise(latitude, declination)

        const sunriseUTC = noonUTC - HA * 4
        const sunsetUTC = noonUTC + HA * 4

        const currentMinutes = now.getUTCHours() * 60 + now.getUTCMinutes()

        return currentMinutes >= sunriseUTC && currentMinutes < sunsetUTC
    }

    function computeNextTransition(latitude, longitude) {
        if (!latitude || !longitude) return ""

        const now = new Date()
        const times = calculateSunriseSunset(latitude, longitude)
        const sunrise = new Date(times.sunrise)
        const sunset = new Date(times.sunset)

        if (now < sunrise) {
            return sunrise.toISOString()
        } else if (now < sunset) {
            return sunset.toISOString()
        } else {
            const tomorrow = new Date(now)
            tomorrow.setDate(tomorrow.getDate() + 1)
            const tomorrowTimes = calculateSunriseSunset(latitude, longitude)
            return new Date(tomorrowTimes.sunrise).toISOString()
        }
    }

    // ── Gamma state update ──

    function updateGammaState() {
        if (!SessionData.nightModeEnabled || !SessionData.nightModeAutoEnabled) {
            gammaCurrentTemp = SessionData.nightModeEnabled ? SessionData.nightModeTemperature : 0
            gammaSunriseTime = ""
            gammaSunsetTime = ""
            gammaNextTransition = ""
            if (!SessionData.nightModeEnabled) {
                gammaIsDay = true
            }
            return
        }

        const mode = SessionData.nightModeAutoMode
        if (mode === "location") {
            const lat = SessionData.latitude
            const lon = SessionData.longitude
            if (lat !== 0.0 && lon !== 0.0) {
                const times = calculateSunriseSunset(lat, lon)
                gammaSunriseTime = times.sunrise
                gammaSunsetTime = times.sunset
                gammaIsDay = computeIsDaytime(lat, lon)
                gammaNextTransition = computeNextTransition(lat, lon)
            } else {
                gammaIsDay = true
                gammaSunriseTime = ""
                gammaSunsetTime = ""
                gammaNextTransition = ""
            }
        } else {
            const currentTime = systemClock.hours * 60 + systemClock.minutes
            const startMinutes = SessionData.nightModeStartHour * 60 + SessionData.nightModeStartMinute
            const endMinutes = SessionData.nightModeEndHour * 60 + SessionData.nightModeEndMinute

            let shouldBeNight = false
            if (startMinutes > endMinutes) {
                shouldBeNight = (currentTime >= startMinutes) || (currentTime < endMinutes)
            } else {
                shouldBeNight = (currentTime >= startMinutes) && (currentTime < endMinutes)
            }

            gammaIsDay = !shouldBeNight
            gammaSunriseTime = ""
            gammaSunsetTime = ""
            gammaNextTransition = ""

            const now = new Date()
            const startDate = new Date(now)
            startDate.setHours(SessionData.nightModeStartHour, SessionData.nightModeStartMinute, 0, 0)
            const endDate = new Date(now)
            endDate.setHours(SessionData.nightModeEndHour, SessionData.nightModeEndMinute, 0, 0)

            if (shouldBeNight) {
                gammaNextTransition = endDate < now ? new Date(endDate.getTime() + 86400000).toISOString() : endDate.toISOString()
            } else {
                gammaNextTransition = startDate < now ? new Date(startDate.getTime() + 86400000).toISOString() : startDate.toISOString()
            }
        }

        gammaCurrentTemp = SessionData.nightModeEnabled ? (gammaIsDay ? SessionData.nightModeHighTemperature : SessionData.nightModeTemperature) : 0
    }

    // ── Brightness functions ──

    function buildGammastepCommand(gammastepArgs) {
        const commandStr = "pkill gammastep; " + ["gammastep"].concat(gammastepArgs).join(" ")
        return ["sh", "-c", commandStr]
    }

    function killGammastep() {
        Quickshell.execDetached(["pkill", "-f", "gammastep"])
        Quickshell.execDetached(["killall", "gammastep"])
    }

    function setBrightnessInternal(percentage, device) {
        const clampedValue = Math.max(1, Math.min(100, percentage))
        const actualDevice = device === "" ? getDefaultDevice() : (device || currentDevice || getDefaultDevice())

        if (actualDevice) {
            const newBrightness = Object.assign({}, deviceBrightness)
            newBrightness[actualDevice] = clampedValue
            deviceBrightness = newBrightness
        }

        const deviceInfo = getCurrentDeviceInfoByName(actualDevice)

        if (deviceInfo && deviceInfo.class === "ddc") {
            ddcBrightnessSetProcess.command = ["ddcutil", "setvcp", "-d", String(deviceInfo.ddcDisplay), "10", String(clampedValue)]
            ddcBrightnessSetProcess.running = true
        } else {
            if (device) {
                brightnessSetProcess.command = ["brightnessctl", "-d", device, "set", `${clampedValue}%`]
            } else {
                brightnessSetProcess.command = ["brightnessctl", "set", `${clampedValue}%`]
            }
            brightnessSetProcess.running = true
        }
    }

    function setBrightness(percentage, device) {
        setBrightnessInternal(percentage, device)
        brightnessChanged()
    }

    function setCurrentDevice(deviceName, saveToSession = false) {
        if (currentDevice === deviceName) {
            return
        }

        currentDevice = deviceName
        lastIpcDevice = deviceName

        if (saveToSession) {
            SessionData.setLastBrightnessDevice(deviceName)
        }

        deviceSwitched()

        const deviceInfo = getCurrentDeviceInfoByName(deviceName)
        if (deviceInfo && deviceInfo.class === "ddc") {
            return
        } else {
            brightnessGetProcess.command = ["brightnessctl", "-m", "-d", deviceName, "get"]
            brightnessGetProcess.running = true
        }
    }

    function refreshDevices() {
        deviceListProcess.running = true
    }

    function refreshDevicesInternal() {
        const allDevices = [...devices, ...ddcDevices]

        allDevices.sort((a, b) => {
                            if (a.class === "backlight" && b.class !== "backlight") {
                                return -1
                            }
                            if (a.class !== "backlight" && b.class === "backlight") {
                                return 1
                            }

                            if (a.class === "ddc" && b.class !== "ddc" && b.class !== "backlight") {
                                return -1
                            }
                            if (a.class !== "ddc" && b.class === "ddc" && a.class !== "backlight") {
                                return 1
                            }

                            return a.name.localeCompare(b.name)
                        })

        devices = allDevices

        if (devices.length > 0 && !currentDevice) {
            const lastDevice = SessionData.lastBrightnessDevice || ""
            const deviceExists = devices.some(d => d.name === lastDevice)
            if (deviceExists) {
                setCurrentDevice(lastDevice, false)
            } else {
                const nonKbdDevice = devices.find(d => !d.name.includes("kbd")) || devices[0]
                setCurrentDevice(nonKbdDevice.name, false)
            }
        }
    }

    function getDeviceBrightness(deviceName) {
        if (!deviceName) {
            return 50
        }

        const deviceInfo = getCurrentDeviceInfoByName(deviceName)
        if (!deviceInfo) {
            return 50
        }

        if (deviceInfo.class === "ddc") {
            return deviceBrightness[deviceName] || 50
        }

        return deviceBrightness[deviceName] || deviceInfo.percentage || 50
    }

    function getDefaultDevice() {
        for (const device of devices) {
            if (device.class === "backlight") {
                return device.name
            }
        }
        return devices.length > 0 ? devices[0].name : ""
    }

    function getCurrentDeviceInfo() {
        const deviceToUse = lastIpcDevice === "" ? getDefaultDevice() : (lastIpcDevice || currentDevice)
        if (!deviceToUse) {
            return null
        }

        for (const device of devices) {
            if (device.name === deviceToUse) {
                return device
            }
        }
        return null
    }

    function isCurrentDeviceReady() {
        const deviceToUse = lastIpcDevice === "" ? getDefaultDevice() : (lastIpcDevice || currentDevice)
        if (!deviceToUse) {
            return false
        }

        if (ddcPendingInit[deviceToUse]) {
            return false
        }

        return true
    }

    function getCurrentDeviceInfoByName(deviceName) {
        if (!deviceName) {
            return null
        }

        for (const device of devices) {
            if (device.name === deviceName) {
                return device
            }
        }
        return null
    }

    function updateDeviceBrightnessDisplay(deviceName) {
        const deviceInfo = getCurrentDeviceInfoByName(deviceName)
        if (!deviceInfo) {
            return
        }

        if (deviceInfo.class === "ddc") {
            ddcBrightnessGetProcess.command = ["ddcutil", "getvcp", "-d", String(deviceInfo.ddcDisplay), "10", "--brief"]
            ddcBrightnessGetProcess.running = true
        } else {
            brightnessGetProcess.command = ["brightnessctl", "-m", "-d", deviceName, "get"]
            brightnessGetProcess.running = true
        }
    }

    function processNextDdcInit() {
        if (ddcInitQueue.length === 0 || ddcInitialBrightnessProcess.running) {
            return
        }

        const displayId = ddcInitQueue.shift()
        ddcInitialBrightnessProcess.command = ["ddcutil", "getvcp", "-d", String(displayId), "10", "--brief"]
        ddcInitialBrightnessProcess.running = true
    }

    // ── Night mode functions ──

    function enableNightMode() {
        if (!automationAvailable) {
            gammastepCheckProcess.running = true
            return
        }

        nightModeEnabled = true
        gammaControlAvailable = true
        SessionData.setNightModeEnabled(true)

        if (SessionData.nightModeAutoEnabled) {
            startAutomation()
        } else {
            applyNightModeDirectly()
        }

        updateGammaState()
    }

    function disableNightMode() {
        nightModeEnabled = false
        gammaCurrentTemp = 0
        SessionData.setNightModeEnabled(false)
        stopAutomation()
        killGammastep()
        gammaStepProcess.running = false
        automationProcess.running = false
        gammastepCheckProcess.running = false
        updateGammaState()
    }

    function toggleNightMode() {
        if (nightModeEnabled) {
            disableNightMode()
        } else {
            enableNightMode()
        }
    }

    function applyNightModeDirectly() {
        const temperature = SessionData.nightModeTemperature || 4500
        const dayTemp = SessionData.nightModeHighTemperature || 6500
        gammaStepProcess.command = buildGammastepCommand(["-m", "wayland", "-t", `${dayTemp}:${temperature}`])
        gammaStepProcess.running = true
    }

    function resetToNormalMode() {
        killGammastep()
    }

    function startAutomation() {
        if (!automationAvailable) {
            return
        }

        const mode = SessionData.nightModeAutoMode || "time"

        switch (mode) {
        case "time":
            startTimeBasedMode()
            break
        case "location":
            startLocationBasedMode()
            break
        }
    }

    function stopAutomation() {
        automationProcess.running = false
        gammaStepProcess.running = false
        gradualTransitionTimer.stop()
        isAutomaticNightTime = false
        killGammastep()
        killGeoclueAgent()
    }

    function startTimeBasedMode() {
        checkTimeBasedMode()
    }

    function startLocationBasedMode() {
        const temperature = SessionData.nightModeTemperature || 4500
        const dayTemp = SessionData.nightModeHighTemperature || 6500

        startGeoclueAgent()

        automationProcess.command = buildGammastepCommand(["-m", "wayland", "-t", `${dayTemp}:${temperature}`, "-v"])
        automationProcess.running = true
    }

    function checkTimeBasedMode() {
        if (!nightModeEnabled || !SessionData.nightModeAutoEnabled || SessionData.nightModeAutoMode !== "time") {
            return
        }

        const currentTime = systemClock.hours * 60 + systemClock.minutes

        const startMinutes = SessionData.nightModeStartHour * 60 + SessionData.nightModeStartMinute
        const endMinutes = SessionData.nightModeEndHour * 60 + SessionData.nightModeEndMinute

        let shouldBeNight = false

        if (startMinutes > endMinutes) {
            shouldBeNight = (currentTime >= startMinutes) || (currentTime < endMinutes)
        } else {
            shouldBeNight = (currentTime >= startMinutes) && (currentTime < endMinutes)
        }

        if (shouldBeNight !== isAutomaticNightTime) {
            isAutomaticNightTime = shouldBeNight
            const steps = SessionData.nightModeSteps || 1

            if (shouldBeNight) {
                const fromTemp = SessionData.nightModeHighTemperature || 6500
                const toTemp = SessionData.nightModeTemperature || 4500
                applyGradualTransition(fromTemp, toTemp, steps)
            } else {
                const fromTemp = SessionData.nightModeTemperature || 4500
                const toTemp = SessionData.nightModeHighTemperature || 6500
                applyGradualTransition(fromTemp, toTemp, steps)
            }
        }

        updateGammaState()
    }

    function applyGradualTransition(fromTemp, toTemp, steps) {
        gradualTransitionTimer.stop()

        if (steps <= 1) {
            gammaStepProcess.command = buildGammastepCommand(["-m", "wayland", "-t", `${SessionData.nightModeHighTemperature || 6500}:${toTemp}`])
            gammaStepProcess.running = true
            return
        }

        const startMinutes = SessionData.nightModeStartHour * 60 + SessionData.nightModeStartMinute
        const endMinutes = SessionData.nightModeEndHour * 60 + SessionData.nightModeEndMinute
        let periodMinutes
        if (startMinutes > endMinutes)
            periodMinutes = (24 * 60 - startMinutes) + endMinutes
        else
            periodMinutes = endMinutes - startMinutes
        const periodMs = Math.max(periodMinutes * 60 * 1000, 60000)
        const intervalMs = Math.floor(periodMs / steps)

        gradualFromTemp = fromTemp
        gradualToTemp = toTemp
        gradualSteps = steps
        gradualStepIndex = 0
        gradualIntervalMs = intervalMs

        applyTransitionStep()
    }

    function applyTransitionStep() {
        const t = gradualSteps > 1 ? gradualStepIndex / (gradualSteps - 1) : 1
        const temp = Math.round(gradualFromTemp + (gradualToTemp - gradualFromTemp) * t)

        gammaStepProcess.command = buildGammastepCommand(["-m", "wayland", "-t", `${SessionData.nightModeHighTemperature || 6500}:${temp}`])
        gammaStepProcess.running = true

        gradualStepIndex++

        if (gradualStepIndex < gradualSteps) {
            gradualTransitionTimer.interval = Math.max(1000, gradualIntervalMs)
            gradualTransitionTimer.start()
        }
    }

    function detectLocationProviders() {
        geoclueDetectionProcess.running = true
    }

    function setNightModeAutomationMode(mode) {
        SessionData.setNightModeAutoMode(mode)
    }

    function evaluateNightMode() {
        stopAutomation()

        if (!nightModeEnabled) {
            updateGammaState()
            return
        }

        if (SessionData.nightModeAutoEnabled) {
            restartTimer.nextAction = "automation"
            restartTimer.start()
        } else {
            restartTimer.nextAction = "direct"
            restartTimer.start()
        }
    }

    function checkNightModeAvailability() {
        gammastepCheckProcess.running = true
    }

    Timer {
        id: restartTimer
        property string nextAction: ""
        interval: 100
        repeat: false

        onTriggered: {
            if (nextAction === "automation") {
                startAutomation()
            } else if (nextAction === "direct") {
                applyNightModeDirectly()
            }
            nextAction = ""
            updateGammaState()
        }
    }

    Timer {
        id: gradualTransitionTimer
        repeat: false
        interval: 60000
        onTriggered: applyTransitionStep()
    }

    Component.onCompleted: {
        ddcDetectionProcess.running = true
        refreshDevices()
        checkNightModeAvailability()

        nightModeEnabled = SessionData.nightModeEnabled
        gammaControlAvailable = automationAvailable
    }

    Component.onDestruction: {
        gammaStepProcess.running = false
        automationProcess.running = false
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
        onDateChanged: {
            if (nightModeEnabled && SessionData.nightModeAutoEnabled && SessionData.nightModeAutoMode === "time") {
                checkTimeBasedMode()
            }
            if (SessionData.nightModeEnabled && SessionData.nightModeAutoEnabled) {
                updateGammaState()
            }
        }
    }

    // ── DDC detection ──

    Process {
        id: ddcDetectionProcess

        command: ["which", "ddcutil"]
        running: false

        onExited: function (exitCode) {
            ddcAvailable = (exitCode === 0)
            if (ddcAvailable) {
                ddcDisplayDetectionProcess.running = true
            } else {
                console.log("DisplayService: ddcutil not available")
            }
        }
    }

    Process {
        id: ddcDisplayDetectionProcess

        command: ["bash", "-c", "ddcutil detect --brief 2>/dev/null | grep '^Display [0-9]' | awk '{print \"{\\\"display\\\":\" $2 \",\\\"name\\\":\\\"ddc-\" $2 \"\\\",\\\"class\\\":\\\"ddc\\\"}\"}' | tr '\\n' ',' | sed 's/,$//' | sed 's/^/[/' | sed 's/$/]/' || echo '[]'"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) {
                    ddcDevices = []
                    return
                }

                try {
                    const parsedDevices = JSON.parse(text.trim())
                    const newDdcDevices = []

                    for (const device of parsedDevices) {
                        if (device.display && device.class === "ddc") {
                            newDdcDevices.push({
                                                   "name": device.name,
                                                   "class": "ddc",
                                                   "current": 50,
                                                   "percentage": 50,
                                                   "max": 100,
                                                   "ddcDisplay": device.display
                                               })
                        }
                    }

                    ddcDevices = newDdcDevices
                    console.log("DisplayService: Found", ddcDevices.length, "DDC displays")

                    ddcInitQueue = []
                    for (const device of ddcDevices) {
                        ddcInitQueue.push(device.ddcDisplay)
                        ddcPendingInit[device.name] = true
                    }

                    processNextDdcInit()
                    refreshDevicesInternal()

                    const lastDevice = SessionData.lastBrightnessDevice || ""
                    if (lastDevice) {
                        const deviceExists = devices.some(d => d.name === lastDevice)
                        if (deviceExists && (!currentDevice || currentDevice !== lastDevice)) {
                            setCurrentDevice(lastDevice, false)
                        }
                    }
                } catch (error) {
                    console.warn("DisplayService: Failed to parse DDC devices:", error)
                    ddcDevices = []
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to detect DDC displays:", exitCode)
                ddcDevices = []
            }
        }
    }

    // ── Brightnessctl device listing ──

    Process {
        id: deviceListProcess

        command: ["brightnessctl", "-m", "-l"]
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to list devices:", exitCode)
                brightnessAvailable = false
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) {
                    console.warn("DisplayService: No devices found")
                    return
                }
                const lines = text.trim().split("\n")
                const newDevices = []
                for (const line of lines) {
                    const parts = line.split(",")
                    if (parts.length >= 5) {
                        newDevices.push({
                                            "name": parts[0],
                                            "class": parts[1],
                                            "current": parseInt(parts[2]),
                                            "percentage": parseInt(parts[3]),
                                            "max": parseInt(parts[4])
                                        })
                    }
                }
                devices = newDevices
                refreshDevicesInternal()
            }
        }
    }

    // ── Brightness set/get processes ──

    Process {
        id: brightnessSetProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to set brightness:", exitCode)
            }
        }
    }

    Process {
        id: ddcBrightnessSetProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to set DDC brightness:", exitCode)
            }
        }
    }

    Process {
        id: ddcInitialBrightnessProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to get initial DDC brightness:", exitCode)
            }

            processNextDdcInit()
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                return

                const parts = text.trim().split(" ")
                if (parts.length >= 5) {
                    const current = parseInt(parts[3]) || 50
                    const max = parseInt(parts[4]) || 100
                    const brightness = Math.round((current / max) * 100)

                    const commandParts = ddcInitialBrightnessProcess.command
                    if (commandParts && commandParts.length >= 4) {
                        const displayId = commandParts[3]
                        const deviceName = "ddc-" + displayId

                        var newBrightness = Object.assign({}, deviceBrightness)
                        newBrightness[deviceName] = brightness
                        deviceBrightness = newBrightness

                        var newPending = Object.assign({}, ddcPendingInit)
                        delete newPending[deviceName]
                        ddcPendingInit = newPending

                        console.log("DisplayService: Initial DDC Device", deviceName, "brightness:", brightness + "%")
                    }
                }
            }
        }
    }

    Process {
        id: brightnessGetProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to get brightness:", exitCode)
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                return

                const parts = text.trim().split(",")
                if (parts.length >= 5) {
                    const current = parseInt(parts[2])
                    const max = parseInt(parts[4])
                    maxBrightness = max
                    const brightness = Math.round((current / max) * 100)

                    if (currentDevice) {
                        var newBrightness = Object.assign({}, deviceBrightness)
                        newBrightness[currentDevice] = brightness
                        deviceBrightness = newBrightness
                    }

                    brightnessInitialized = true
                    console.log("DisplayService: Device", currentDevice, "brightness:", brightness + "%")
                    brightnessChanged()
                }
            }
        }
    }

    Process {
        id: ddcBrightnessGetProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to get DDC brightness:", exitCode)
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                return

                const parts = text.trim().split(" ")
                if (parts.length >= 5) {
                    const current = parseInt(parts[3]) || 50
                    const max = parseInt(parts[4]) || 100
                    maxBrightness = max
                    const brightness = Math.round((current / max) * 100)

                    if (currentDevice) {
                        var newBrightness = Object.assign({}, deviceBrightness)
                        newBrightness[currentDevice] = brightness
                        deviceBrightness = newBrightness
                    }

                    brightnessInitialized = true
                    console.log("DisplayService: DDC Device", currentDevice, "brightness:", brightness + "%")
                    brightnessChanged()
                }
            }
        }
    }

    // ── Gammastep detection ──

    Process {
        id: gammastepCheckProcess
        command: ["which", "gammastep"]
        running: false

        onExited: function (exitCode) {
            automationAvailable = (exitCode === 0)
            gammaControlAvailable = automationAvailable
            if (automationAvailable) {
                detectLocationProviders()

                if (nightModeEnabled && SessionData.nightModeAutoEnabled) {
                    startAutomation()
                } else if (nightModeEnabled) {
                    applyNightModeDirectly()
                }
            } else {
                console.log("DisplayService: gammastep not available")
            }
            updateGammaState()
        }
    }

    Process {
        id: geoclueDetectionProcess
        command: ["sh", "-c", "busctl --system list | grep -qF org.freedesktop.GeoClue2"]
        running: false

        onExited: function (exitCode) {
            geoclueAvailable = (exitCode === 0)
        }
    }

    Process {
        id: geoclueAgentProcess
        command: ["/usr/lib/geoclue-2.0/demos/agent"]
        running: false

        onExited: function (exitCode) {
            geoclueAgentRunning = false
            console.log("DisplayService: geoclue-agent exited with code:", exitCode)
        }
    }

    function startGeoclueAgent() {
        if (geoclueAgentRunning)
            return
        geoclueAgentProcess.running = true
        geoclueAgentRunning = true
        console.log("DisplayService: Started geoclue-agent")
    }

    function killGeoclueAgent() {
        if (!geoclueAgentRunning)
            return
        Quickshell.execDetached(["pkill", "-f", "/usr/lib/geoclue-2.0/demos/agent"])
        geoclueAgentRunning = false
        console.log("DisplayService: Stopped geoclue-agent")
    }

    // ── Gamma execution processes ──

    Process {
        id: gammaStepProcess
        running: false

        onExited: function (exitCode) {
            if (nightModeEnabled && exitCode !== 0 && exitCode !== 15) {
                console.warn("DisplayService: Night mode process failed:", exitCode)
            }
            updateGammaState()
        }
    }

    Process {
        id: automationProcess
        running: false

        onExited: function (exitCode) {
            if (nightModeEnabled && SessionData.nightModeAutoEnabled && exitCode !== 0 && exitCode !== 15) {
                console.warn("DisplayService: Night mode automation failed:", exitCode)
            }
            updateGammaState()
        }
    }

    // ── Session data connections ──

    Connections {
        target: SessionData

        function onNightModeEnabledChanged() {
            nightModeEnabled = SessionData.nightModeEnabled
            evaluateNightMode()
        }

        function onNightModeAutoEnabledChanged() {
            evaluateNightMode()
        }
        function onNightModeAutoModeChanged() {
            evaluateNightMode()
        }
        function onNightModeStartHourChanged() {
            evaluateNightMode()
        }
        function onNightModeStartMinuteChanged() {
            evaluateNightMode()
        }
        function onNightModeEndHourChanged() {
            evaluateNightMode()
        }
        function onNightModeEndMinuteChanged() {
            evaluateNightMode()
        }
        function onNightModeStepsChanged() {
            evaluateNightMode()
        }
        function onNightModeTemperatureChanged() {
            updateGammaState()
            if (nightModeEnabled && !SessionData.nightModeAutoEnabled) {
                applyNightModeDirectly()
            }
        }
        function onNightModeHighTemperatureChanged() {
            updateGammaState()
        }
        function onLatitudeChanged() {
            evaluateNightMode()
        }
        function onLongitudeChanged() {
            evaluateNightMode()
        }
        function onNightModeLocationProviderChanged() {
            evaluateNightMode()
        }
    }

    // ── IPC handlers ──

    IpcHandler {
        function set(percentage: string, device: string): string {
            if (!root.brightnessAvailable) {
                return "Brightness control not available"
            }

            const value = parseInt(percentage)
            if (isNaN(value)) {
                return "Invalid brightness value: " + percentage
            }

            const clampedValue = Math.max(1, Math.min(100, value))
            const targetDevice = device || ""

            if (targetDevice && !root.devices.some(d => d.name === targetDevice)) {
                return "Device not found: " + targetDevice
            }

            root.lastIpcDevice = targetDevice
            if (targetDevice && targetDevice !== root.currentDevice) {
                root.setCurrentDevice(targetDevice, false)
            }
            root.setBrightness(clampedValue, targetDevice)

            if (targetDevice) {
                return "Brightness set to " + clampedValue + "% on " + targetDevice
            } else {
                return "Brightness set to " + clampedValue + "%"
            }
        }

        function increment(step: string, device: string): string {
            if (!root.brightnessAvailable) {
                return "Brightness control not available"
            }

            const targetDevice = device || ""
            const actualDevice = targetDevice === "" ? root.getDefaultDevice() : targetDevice

            if (actualDevice && !root.devices.some(d => d.name === actualDevice)) {
                return "Device not found: " + actualDevice
            }

            const currentLevel = actualDevice ? root.getDeviceBrightness(actualDevice) : root.brightnessLevel
            const stepValue = parseInt(step || "10")
            const newLevel = Math.max(1, Math.min(100, currentLevel + stepValue))

            root.lastIpcDevice = targetDevice
            if (targetDevice && targetDevice !== root.currentDevice) {
                root.setCurrentDevice(targetDevice, false)
            }
            root.setBrightness(newLevel, targetDevice)

            if (targetDevice) {
                return "Brightness increased to " + newLevel + "% on " + targetDevice
            } else {
                return "Brightness increased to " + newLevel + "%"
            }
        }

        function decrement(step: string, device: string): string {
            if (!root.brightnessAvailable) {
                return "Brightness control not available"
            }

            const targetDevice = device || ""
            const actualDevice = targetDevice === "" ? root.getDefaultDevice() : targetDevice

            if (actualDevice && !root.devices.some(d => d.name === actualDevice)) {
                return "Device not found: " + actualDevice
            }

            const currentLevel = actualDevice ? root.getDeviceBrightness(actualDevice) : root.brightnessLevel
            const stepValue = parseInt(step || "10")
            const newLevel = Math.max(1, Math.min(100, currentLevel - stepValue))

            root.lastIpcDevice = targetDevice
            if (targetDevice && targetDevice !== root.currentDevice) {
                root.setCurrentDevice(targetDevice, false)
            }
            root.setBrightness(newLevel, targetDevice)

            if (targetDevice) {
                return "Brightness decreased to " + newLevel + "% on " + targetDevice
            } else {
                return "Brightness decreased to " + newLevel + "%"
            }
        }

        function incrementDefault(step: string): string {
            if (!root.brightnessAvailable) {
                return "Brightness control not available"
            }

            const targetDevice = lastIpcDevice === "" ? getDefaultDevice() : (lastIpcDevice || currentDevice)
            const actualDevice = targetDevice === "" ? root.getDefaultDevice() : targetDevice

            if (actualDevice && !root.devices.some(d => d.name === actualDevice)) {
                return "Device not found: " + actualDevice
            }

            const currentLevel = actualDevice ? root.getDeviceBrightness(actualDevice) : root.brightnessLevel
            const stepValue = parseInt(step || "10")
            const newLevel = Math.max(1, Math.min(100, currentLevel + stepValue))

            root.lastIpcDevice = targetDevice
            if (targetDevice && targetDevice !== root.currentDevice) {
                root.setCurrentDevice(targetDevice, false)
            }
            root.setBrightness(newLevel, targetDevice)

            if (targetDevice) {
                return "Brightness increased to " + newLevel + "% on " + targetDevice
            } else {
                return "Brightness increased to " + newLevel + "%"
            }
        }

        function decrementDefault(step: string): string {
            if (!root.brightnessAvailable) {
                return "Brightness control not available"
            }

            const targetDevice = lastIpcDevice === "" ? getDefaultDevice() : (lastIpcDevice || currentDevice)
            const actualDevice = targetDevice === "" ? root.getDefaultDevice() : targetDevice

            if (actualDevice && !root.devices.some(d => d.name === actualDevice)) {
                return "Device not found: " + actualDevice
            }

            const currentLevel = actualDevice ? root.getDeviceBrightness(actualDevice) : root.brightnessLevel
            const stepValue = parseInt(step || "10")
            const newLevel = Math.max(1, Math.min(100, currentLevel - stepValue))

            root.lastIpcDevice = targetDevice
            if (targetDevice && targetDevice !== root.currentDevice) {
                root.setCurrentDevice(targetDevice, false)
            }
            root.setBrightness(newLevel, targetDevice)

            if (targetDevice) {
                return "Brightness decreased to " + newLevel + "% on " + targetDevice
            } else {
                return "Brightness decreased to " + newLevel + "%"
            }
        }

        function status(): string {
            if (!root.brightnessAvailable) {
                return "Brightness control not available"
            }

            return "Device: " + root.currentDevice + " - Brightness: " + root.brightnessLevel + "%"
        }

        function list(): string {
            if (!root.brightnessAvailable) {
                return "No brightness devices available"
            }

            let result = "Available devices:\\n"
            for (const device of root.devices) {
                result += device.name + " (" + device.class + ")\\n"
            }
            return result
        }

        target: "brightness"
    }

    IpcHandler {
        function toggle(): string {
            root.toggleNightMode()
            return root.nightModeEnabled ? "Night mode enabled" : "Night mode disabled"
        }

        function enable(): string {
            root.enableNightMode()
            return "Night mode enabled"
        }

        function disable(): string {
            root.disableNightMode()
            return "Night mode disabled"
        }

        function status(): string {
            return root.nightModeEnabled ? "Night mode is enabled" : "Night mode is disabled"
        }

        function temperature(value: string): string {
            if (!value) {
                return "Current temperature: " + SessionData.nightModeTemperature + "K"
            }

            const temp = parseInt(value)
            if (isNaN(temp)) {
                return "Invalid temperature. Use a value between 2500 and 6000 (in steps of 500)"
            }

            if (temp < 2500 || temp > 6000) {
                return "Temperature must be between 2500K and 6000K"
            }

            const rounded = Math.round(temp / 500) * 500

            SessionData.setNightModeTemperature(rounded)

            if (root.nightModeEnabled) {
                if (SessionData.nightModeAutoEnabled) {
                    root.startAutomation()
                } else {
                    root.applyNightModeDirectly()
                }
            }

            if (rounded !== temp) {
                return "Night mode temperature set to " + rounded + "K (rounded from " + temp + "K)"
            } else {
                return "Night mode temperature set to " + rounded + "K"
            }
        }

        target: "night"
    }
}
