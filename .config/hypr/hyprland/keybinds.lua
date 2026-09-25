local vars = require("variables")
local fn   = require("utils.functions")
local dms = "~/.config/quickshell/dms"


-- Flags
local locked           = { locked = true }
local mouse            = { mouse = true }
local release          = { release = true }
local repeating        = { repeating = true }
local locked_repeating = { locked = true, repeating = true }

local function normalise_keybind(key)
    return key:gsub("%s+", ""):lower()
end

local function sf(str, ...) return string.format(str, ...) end

local function valid_keybind(key)
    return type(key) == "string" and key:match("%S") ~= nil
end

local function repeating_unless_mouse(key)
    return not normalise_keybind(key):find("mouse", 1, true) and repeating or nil
end

local function flatten_keybinds(keybinds, keys)
    keys = keys or {}

    if type(keybinds) == "table" then
        for _, keybind in pairs(keybinds) do
            flatten_keybinds(keybind, keys)
        end
    elseif valid_keybind(keybinds) then
        keys[#keys + 1] = keybinds
    end

    return keys
end

local function merge_flags(flags, desc)
    local merged = {}
    if type(flags) == "table" then
        for k, v in pairs(flags) do
            merged[k] = v
        end
    end
    if desc then
        merged.description = desc
    end
    return next(merged) and merged or nil
end

local function create_bind(keybinds, action, desc, flags)
    if type(desc) == "function" or type(desc) == "table" then
        flags = desc
        desc  = nil
    end

    local get_flags = type(flags) == "function" and flags or function()
        return flags
    end

    for _, key in ipairs(flatten_keybinds(keybinds)) do
        hl.bind(key, action, merge_flags(get_flags(key), desc))
    end
end

local function extend_keybind(base, suffix)
    return valid_keybind(base) and base .. " + " .. suffix or nil
end

------------------
---- KEYBINDS ----
------------------

-- Launcher
local launcher_default = normalise_keybind("SUPER + SUPER_L")
create_bind(
    vars.kbLauncher,
    hl.dsp.exec_cmd(sf("qs -p %s ipc call spotlight toggle", dms)),
    "Launch spotlight",
    function(key)
        return normalise_keybind(key) == launcher_default and release or nil
    end
)

-- Misc
create_bind(vars.kbSession, hl.dsp.global("caelestia:session"), "Open session menu")
create_bind(vars.kbClearNotifs, hl.dsp.exec_cmd(sf("qs -p %s ipc call notifications clearAll", dms)), "Clear notifications", locked)
create_bind(vars.kbLock, hl.dsp.exec_cmd("loginctl lock-session $XDG_SESSION_ID"), "Lock the screen", locked)
create_bind(vars.kbRandomWallpaper, hl.dsp.exec_cmd(sf("qs -p %s ipc call wallpaper random", dms)), "Choose random wallpaper")

create_bind(
    vars.kbPowerMenu,
    hl.dsp.exec_cmd(sf("qs -p %s ipc call powermenu toggle", dms)),
    "Toggle power menu"
)

-- Widgets
create_bind(vars.kbClipboard, hl.dsp.exec_cmd(sf("qs -p %s ipc call clipboard toggle", dms)), "Open clipboard")
create_bind(vars.kbClipboardDel, hl.dsp.exec_cmd("cliphist wipe"), "Delete clipboard history")
create_bind(
    vars.kbEmoji,
    hl.dsp.exec_cmd("pkill fuzzel || caelestia emoji -p"),
    "Open emoji picker"
)
create_bind(
    vars.kbClipboardPasteLatest,
    hl.dsp.exec_cmd('sleep 0.5s && ydotool type -d 1 "$(cliphist list | head -1 | cliphist decode)"'),
    "Paste latest clipboard entry",
    locked
)
create_bind(vars.kbNotif, hl.dsp.exec_cmd(sf("qs -p %s ipc call notifications toggle", dms)), "Open Notification Center")
create_bind(vars.kbControlCenter, hl.dsp.exec_cmd(sf("qs -p %s ipc call control-center toggle", dms)), "Open Control Center")
create_bind(vars.kbShowSidebar, hl.dsp.global("caelestia:sidebar"), "Toggle sidebar")
create_bind(vars.kbChooseWallpaper, hl.dsp.exec_cmd(sf("qs -p %s ipc call dankdash wallpaper", dms)), "Open Wallpaper Picker")
create_bind(vars.kbCheatsheet, hl.dsp.exec_cmd(sf("qs -p %s ipc call cheatsheet toggle", dms)), "Open keybinds cheatsheet")

create_bind(
    vars.kbOpenClock,
    hl.dsp.exec_cmd(sf("qs -p %s ipc call clock toggle", dms)),
    "Open clock"
)

create_bind(
    vars.kbToolbox,
    hl.dsp.exec_cmd(sf("qs -p %s ipc call toolbox toggle", dms)),
    "Toggle toolbox"
)

create_bind(
    vars.kbNotepad,
    hl.dsp.exec_cmd(sf("qs -p %s ipc call notepad toggle", dms)),
    "Toggle notepad"
)

create_bind(
    vars.kbProcessMonitor,
    hl.dsp.exec_cmd(sf("qs -p %s ipc call processlist toggle", dms)),
    "Toggle process monitor"
)

-- Restore lock
create_bind(vars.kbRestoreLock, function()
    hl.dispatch(hl.dsp.exec_cmd("caelestia shell -d"))
    hl.dispatch(hl.dsp.global("caelestia:lock"))
end, "Restore & lock screen")

-- Kill/restart
create_bind(
    vars.kbRestartQS,
    hl.dsp.exec_cmd(sf("qs -p %s kill; sleep 1; qs -p %s -n -d", dms, dms)),
    "Restart quickshell",
    release
)

-- Workspace Movement 1-0
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    create_bind(extend_keybind(vars.kbGoToWs, key), fn.wsaction("focus", "", i), "Go to workspace " .. key)
    create_bind(extend_keybind(vars.kbMoveWinToWs, key), fn.wsaction("move", "", i), "Move window to workspace " .. key)
    create_bind(extend_keybind(vars.kbGoToWsGroup, key), fn.wsaction("focus", "group", i), "Go to workspace group " .. key)
    create_bind(extend_keybind(vars.kbMoveWinToWsGroup, key), fn.wsaction("move", "group", i), "Move window to workspace group " .. key)
end

-- Go to workspace -1/+1
create_bind(vars.kbPrevWs, hl.dsp.focus({ workspace = "-1" }), "Go to previous workspace", repeating_unless_mouse)
create_bind(vars.kbNextWs, hl.dsp.focus({ workspace = "+1" }), "Go to next workspace", repeating_unless_mouse)

-- Go to workspace group -1/+1
create_bind(vars.kbPrevWsGroup, hl.dsp.focus({ workspace = "-10" }), "Go to previous workspace group", repeating_unless_mouse)
create_bind(vars.kbNextWsGroup, hl.dsp.focus({ workspace = "+10" }), "Go to next workspace group", repeating_unless_mouse)

-- Move window to workspace -1/+1
create_bind(vars.kbMoveWinToWsNext, hl.dsp.window.move({ workspace = "+1" }), "Move window to next workspace", repeating_unless_mouse)
create_bind(vars.kbMoveWinToWsPrev, hl.dsp.window.move({ workspace = "-1" }), "Move window to previous workspace", repeating_unless_mouse)

-- Move window to/from special workspace
create_bind(vars.kbMoveWinToWsSpecial, hl.dsp.window.move({ workspace = "special:special" }), "Move window to special workspace")
create_bind(vars.kbMoveWinFromWsSpecial, hl.dsp.window.move({ workspace = "e+0" }), "Move window from special workspace")

-- Window groups
create_bind(vars.kbWindowCycleNext, hl.dsp.window.cycle_next(), "Cycle to next window", repeating)
create_bind(vars.kbWindowCyclePrev, hl.dsp.window.cycle_next({ next = false }), "Cycle to previous window", repeating)
create_bind(vars.kbWindowGroupCycleNext, hl.dsp.group.next(), "Next window group", repeating)
create_bind(vars.kbWindowGroupCyclePrev, hl.dsp.group.prev(), "Previous window group", repeating)
create_bind(vars.kbToggleGroup, hl.dsp.group.toggle(), "Toggle window group")
create_bind(vars.kbUngroup, hl.dsp.window.move({ out_of_group = true }), "Ungroup window")
create_bind(vars.kbGroupLockActive, hl.dsp.group.lock_active(), "Lock active group")

-- Window actions
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    create_bind("SUPER + " .. dir, hl.dsp.focus({ direction = dir }), "Focus " .. dir)
    create_bind("SUPER + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir, group_aware = true }), "Move window " .. dir)
end

create_bind(vars.kbWindowDecreaseWidth, fn.resize_active_window(-10, 0), "Decrease window width", repeating)
create_bind(vars.kbWindowIncreaseWidth, fn.resize_active_window(10, 0), "Increase window width", repeating)
create_bind(vars.kbWindowDecreaseHeight, fn.resize_active_window(0, -10), "Decrease window height", repeating)
create_bind(vars.kbWindowIncreaseHeight, fn.resize_active_window(0, 10), "Increase window height", repeating)

create_bind({ vars.kbMoveWindow, "SUPER + mouse:272" }, hl.dsp.window.drag(), "Drag move window", mouse)
create_bind({ vars.kbResizeWindow, "SUPER + mouse:273" }, hl.dsp.window.resize(), "Drag resize window", mouse)
create_bind(vars.kbCenterWindow, hl.dsp.window.center(), "Center window")
create_bind(vars.kbNormalizeWindow, function()
    hl.dispatch(hl.dsp.window.resize(fn.resize_by_screen(55, 70)))
    hl.dispatch(hl.dsp.window.center())
end, "Normalize window")
create_bind(vars.kbWindowPip, function()
    local a = hl.get_active_window()
    if a then
        local pip = fn.move_actions(a) or {}
        if not a.floating then table.insert(pip, 1, hl.dsp.window.float()) end
        table.insert(pip, hl.dsp.window.pin({ action = "on", window = "address:" .. a.address }))

        for _, x in ipairs(pip) do
            hl.dispatch(x)
        end
    end
end, "Toggle picture-in-picture")
create_bind(vars.kbPinWindow, hl.dsp.window.pin(), "Pin window")
create_bind(vars.kbWindowFullscreen, hl.dsp.window.fullscreen({ mode = "fullscreen" }), "Toggle fullscreen")
create_bind(vars.kbWindowBorderedFullscreen, hl.dsp.window.fullscreen({ mode = "maximized" }), "Toggle bordered fullscreen")
create_bind(vars.kbToggleWindowFloating, hl.dsp.window.float(), "Toggle floating")
create_bind(vars.kbCloseWindow, hl.dsp.window.close(), "Close window")
create_bind(
    vars.kbQuitActiveWindow,
    hl.dsp.exec_cmd("hyprctl activewindow | grep pid | tr -d 'pid:' | xargs kill"),
    "Quit all instance of active window"
)

create_bind(
    vars.kbQuitSelectedWindow,
    hl.dsp.exec_cmd("hyprctl kill"),
    "Quit all instances of selected window"
)
create_bind(
    vars.kbOpenOverview,
    hl.dsp.exec_cmd(sf("qs -p %s ipc call hypr toggleOverview", dms)),
    "Open overview"
)

-- Special workspace toggles
create_bind(vars.kbSpecialWs, fn.toggle("specialws"), "Toggle special workspace")
create_bind(vars.kbSystemMonitorWs, fn.toggle("sysmon"), "Toggle system monitor")
create_bind(vars.kbMusicWs, fn.toggle("music"), "Toggle music workspace")
create_bind(
    vars.kbCommunicationWs,
    fn.toggle("communication"),
    "Toggle communication workspace"
)
create_bind(vars.kbTodoWs, fn.toggle("todo"), "Toggle todo workspace")

-- Apps
create_bind(vars.kbTerminal, hl.dsp.exec_cmd(vars.terminal), "Open terminal")
create_bind(vars.kbBrowser, hl.dsp.exec_cmd(vars.browser), "Open browser")
create_bind(vars.kbEditor, hl.dsp.exec_cmd(vars.editor), "Open editor")
create_bind(vars.kbFileExplorer, hl.dsp.exec_cmd(vars.fileExplorer), "Open file explorer")
create_bind(vars.kbAudioSettings, hl.dsp.exec_cmd(vars.audioSettings), "Open audio settings")

-- Utilities
create_bind(
    vars.kbScreenshot,
    hl.dsp.exec_cmd(sf("qs -p %s ipc call screenshot all clipboard", dms)),
    "Take screenshot",
    locked
)
create_bind(
    vars.kbScreenshotFreeze,
    hl.dsp.exec_cmd(sf("qs -p %s ipc call screenshot region clipboard", dms)),
    "Screenshot a region to clipboard"
)
create_bind(
    vars.kbControlledScreenshot,
    hl.dsp.exec_cmd(sf("qs -p %s ipc call screenshot controls", dms)),
    "Controlled screenshot"
)
create_bind(vars.kbRecord, hl.dsp.exec_cmd("caelestia record"), "Record screen")
create_bind(vars.kbRecordSound, hl.dsp.exec_cmd("caelestia record -s"), "Record screen with sound")
create_bind(vars.kbRecordRegion, hl.dsp.exec_cmd("caelestia record -r"), "Record region")
create_bind(vars.kbColorPicker, hl.dsp.exec_cmd("hyprpicker -a"), "Pick color")






-- Brightness
create_bind("XF86MonBrightnessUp", hl.dsp.global("caelestia:brightnessUp"), "Increase brightness", locked)
create_bind("XF86MonBrightnessDown", hl.dsp.global("caelestia:brightnessDown"), "Decrease brightness", locked)

-- Media
create_bind({ vars.kbMediaToggle, "XF86AudioPlay", "XF86AudioPause" }, hl.dsp.global("playerctl play-pause"), "Toggle media play/pause", locked)
create_bind({ vars.kbMediaNext, "XF86AudioNext" }, hl.dsp.global("playerctl next"), "Next media track", locked)
create_bind({ vars.kbMediaPrev, "XF86AudioPrev" }, hl.dsp.global("playerctl prev"), "Previous media track", locked)
create_bind({ vars.kbMediaStop, "XF86AudioStop" }, hl.dsp.global("playerctl stop"), "Stop media", locked)

-- Volume
create_bind({ vars.kbVolumeMute, "XF86AudioMute" }, hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), "Toggle mute", locked)
create_bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), "Toggle mic mute", locked)
create_bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd(
        "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l " ..
        (vars.volumeMax / 100) .. " @DEFAULT_AUDIO_SINK@ " .. vars.volumeStep .. "%+"
    ),
    "Raise volume",
    locked_repeating
)
create_bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd(
        "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ " .. vars.volumeStep .. "%-"
    ),
    "Lower volume",
    locked_repeating
)

-- Sleep
create_bind(vars.kbSleep, hl.dsp.exec_cmd(vars.sleepGestureCmd), "Sleep", locked)

-- Testing
create_bind(
    "SUPER + ALT + F12",
    hl.dsp.exec_cmd(
        "notify-send -u low -i dialog-information-symbolic 'Test notification' " ..
        [["Here's a really long message to test truncation and wrapping\nYou can middle click or flick this notification to dismiss it!"]] ..
        " -a 'Shell' -A 'Test1=I got it!' -A 'Test2=Another action'"
    ),
    "Send test notification"
)
