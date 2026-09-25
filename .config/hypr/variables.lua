local scheme = require("scheme.current")

return {
    ------------------
    ---- HYPRLAND ----
    ------------------

    -- Apps
    terminal                   = "foot",
    browser                    = "zen-browser",
    editor                     = "zed-editor",
    fileExplorer               = "thunar",
    audioSettings              = "pavucontrol",

    -- Touchpad
    touchpadDisableTyping      = true,
    touchpadScrollFactor       = 0.3,
    gestureFingers             = 3,
    workspaceSwipeFingers      = 4,
    gestureFingersMore         = 4,

    -- Blur
    blurEnabled                = true,
    blurSpecialWs              = false,
    blurPopups                 = true,
    blurInputMethods           = true,
    blurSize                   = 8,
    blurPasses                 = 2,
    blurXray                   = false,

    -- Shadow
    shadowEnabled              = true,
    shadowRange                = 15,
    shadowRenderPower          = 4,
    shadowColour               = "rgba(" .. scheme.inversePrimary .. "10)",

    -- Gaps
    workspaceGaps              = 10,
    singleWindowGapsOut        = 5,
    windowGapsIn = 4,
    windowGapsOut = 4,

    -- Window styling
    windowOpacity              = 0.95,
    activeWindowBorderColour   = "rgba(" .. scheme.primary .. "e6)",
    inactiveWindowBorderColour = "rgba(" .. scheme.onSurfaceVariant .. "11)",
    windowBorderSize = 2,
    windowRounding = 12,
    resizeOnBorder = false,

    -- Misc
    volumeStep                 = 5,
    volumeMax                  = 100,
    inputSens                  = -0.4,
    cursorTheme                = "sweet-cursors",
    cursorSize                 = 24,
    sleepGestureCmd            = "systemctl suspend-then-hibernate",

    ------------------
    ---- KEYBINDS ----
    ------------------

    -- Modifier only, the actual binds will be mod + 0-9. These should be strings and not arrays.
    -- Workspace Movement 1-0
    kbGoToWs                   = "SUPER",
    kbGoToWsGroup              = "CTRL + SUPER",
    kbMoveWinToWs              = "SUPER + ALT",
    kbMoveWinToWsGroup         = "CTRL + SUPER + ALT",

    -- All the following binds can be either an array of binds to bind multiple keys, or a single string.

    -- Go to workspace -1/+1
    kbNextWs                   = { "SUPER + mouse_down", "CTRL + SUPER + Right", "SUPER + Page_Down" },
    kbPrevWs                   = { "SUPER + mouse_up", "CTRL + SUPER + Left", "SUPER + Page_Up" },

    -- Go to workspace group -1/+1
    kbNextWsGroup              = "CTRL + SUPER + mouse_down",
    kbPrevWsGroup              = "CTRL + SUPER + mouse_up",

    -- Move window to workspace -1/+1
    kbMoveWinToWsNext          = { "SUPER + ALT + mouse_down", "SUPER + ALT + Page_Down", "CTRL + SUPER + SHIFT + Right" },
    kbMoveWinToWsPrev          = { "SUPER + ALT + mouse_up", "SUPER + ALT + Page_Up", "CTRL + SUPER + SHIFT + Left" },

    -- Move window to/from special workspace
    kbMoveWinFromWsSpecial     = "CTRL + SUPER + SHIFT + Down",
    kbMoveWinToWsSpecial       = { "SUPER + ALT + S", "CTRL + SUPER + SHIFT + Up" },

    -- Window groups
    kbWindowCycleNext          = "ALT + TAB",
    kbWindowCyclePrev          = "SHIFT + ALT + TAB",
    kbWindowGroupCycleNext     = "SUPER + D",
    kbWindowGroupCyclePrev     = "SUPER + A",
    kbUngroup                  = "SUPER + U",
    kbToggleGroup              = "SUPER + Comma",
    kbGroupLockActive          = "CTRL + SUPER + Comma",

    -- Window actions
    kbWindowDecreaseWidth      = { "SUPER + Minus", "SUPER + ALT + Left" },
    kbWindowIncreaseWidth      = { "SUPER + Equal", "SUPER + ALT + Right" },
    kbWindowDecreaseHeight     = { "SUPER + SHIFT + Minus", "SUPER + ALT + Up" },
    kbWindowIncreaseHeight     = { "SUPER + SHIFT + Equal", "SUPER + ALT + Down" },

    kbMoveWindow               = "SUPER + Z",
    kbResizeWindow             = "SUPER + X",
    kbCenterWindow             = "CTRL + SUPER + Backslash",
    kbNormalizeWindow          = "CTRL + SUPER + ALT + Backslash",
    kbWindowPip                = "SUPER + ALT + Backslash",
    kbPinWindow                = "SUPER + P",
    kbWindowFullscreen         = "SUPER + F",
    kbWindowBorderedFullscreen = "SUPER + ALT + F",
    kbToggleWindowFloating     = "SUPER + ALT + Space",
    kbCloseWindow              = "SUPER + Q",
    kbQuitActiveWindow         = "SUPER + SHIFT + Q",
    kbQuitSelectedWindow = "SUPER + CTRL + Q",
    kbOpenOverview = "SUPER + Tab",

    -- Special workspace toggles
    kbSpecialWs                = "SUPER + S",
    kbSystemMonitorWs          = "CTRL + SHIFT + Escape",
    kbMusicWs                  = "SUPER + M",
    kbTodoWs                   = "SUPER + T",
    kbCommunicationWs = "SUPER + C",

    -- Apps
    kbTerminal                 = "SUPER + RETURN",
    kbBrowser                  = "SUPER + W",
    kbEditor                   = "SUPER + Semicolon",
    kbFileExplorer             = "SUPER + E",
    kbAudioSettings            = "CTRL + ALT + V",

    -- Utilities
    kbScreenshot               = "Print",
    kbScreenshotFreeze         = "SUPER + SHIFT + S",
    kbRecord                   = "CTRL + ALT + R",
    kbRecordSound              = "SUPER + ALT + R",
    kbRecordRegion             = "SUPER + SHIFT + ALT + R",
    kbColorPicker              = "SUPER + SHIFT + C",
    kbControlledScreenshot = "SUPER + Print",

    -- Launcher
    kbLauncher                 = "SUPER + Space",

    -- Restore lock
    kbRestoreLock              = "SUPER + ALT + L",

    -- Kill/restart
    kbRestartQS                = "CTRL + SUPER + ALT + R",

    -- Media
    kbMediaToggle              = "CTRL + SUPER + Space",
    kbMediaNext                = "CTRL + SUPER + Equal",
    kbMediaPrev                = "CTRL + SUPER + Minus",
    kbMediaStop                = "CTRL + SUPER + Backspace",
    kbVolumeMute               = "SUPER + SHIFT + M",

    -- Sleep
    kbSleep                    = "SUPER + SHIFT + L",

    -- Misc
    kbSession                  = "CTRL + ALT + Delete",
    kbClearNotifs              = "CTRL + ALT + C",
    kbLock                     = "CTRL + SUPER + L",
    kbClipboardDel             = "SUPER + ALT + V",
    kbClipboardPasteLatest     = "CTRL + SHIFT + ALT + V",
    kbRandomWallpaper          = "SUPER + SHIFT + W",
    kbPowerMenu = "XF86PowerOff",

    -- Widgets
    kbClipboard                = "CTRL + SUPER + V",
    kbNotif                    = "CTRL + SUPER + X",
    kbControlCenter            = "CTRL + SUPER + C",
    kbShowSidebar              = "CTRL + SUPER + A",
    kbChooseWallpaper          = "CTRL + SUPER + W",
    kbCheatsheet               = "CTRL + SUPER + K",
    kbEmoji = "SUPER + CTRL + E",
    kbOpenClock = "SUPER + CTRL + T",
    kbToolbox = "SUPER + CTRL + Z",
    kbNotepad = "SUPER + CTRL + N",
    kbProcessMonitor = "SUPER + CTRL + P",
}
