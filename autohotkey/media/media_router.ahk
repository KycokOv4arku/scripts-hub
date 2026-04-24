#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
#Include audio.ahk
#NoTrayIcon

;------------------------------------------------------------------------------
; Script: media_router.ahk
; Purpose: Universal media play/pause router via Core Audio API
;          Detects loudest audio session → routes to app-specific handler
;
; Strategies:
;   global_media_key      — Send {Media_Play_Pause}, no window manipulation
;   stealth_then_activate — ControlSend first, activate fallback
;   activate_only         — activate → send → restore (Electron apps)
;------------------------------------------------------------------------------

DEBUG_MODE := false
if DEBUG_MODE
    try TraySetIcon("D:\YandexDisk\images\Icons\autohotkey-red.ico")

; ==============================================================================
; APP CONFIGURATION
; ==============================================================================

APP_CONFIGS := Map()

APP_CONFIGS["chrome"] := Map(
    "exe", "chrome.exe",
    "strategy", "global_media_key",
    "key", "{Media_Play_Pause}",
    "displayName", "Chrome"
)

APP_CONFIGS["aimp"] := Map(
    "exe", "AIMP.exe",
    "strategy", "stealth_then_activate",
    "key", "{Space}",
    "windowClass", "TAIMPMainForm",
    "activateDelay", 50,
    "postSendDelay", 50,
    "displayName", "AIMP"
)

APP_CONFIGS["vlc"] := Map(
    "exe", "vlc.exe",
    "strategy", "stealth_then_activate",
    "key", "{Space}",
    "windowClass", "",
    "activateDelay", 50,
    "postSendDelay", 50,
    "displayName", "VLC"
)

APP_CONFIGS["yandex_music"] := Map(
    "exe", "Яндекс Музыка.exe",
    "strategy", "activate_only",
    "key", "{vk4B}",
    "windowClass", "Chrome_WidgetWin_1",
    "activateDelay", 150,
    "postSendDelay", 150,
    "displayName", "Yandex Music"
)

; Build reverse lookup: process name → config key
EXE_TO_CONFIG := Map()
for key, cfg in APP_CONFIGS
    EXE_TO_CONFIG[cfg["exe"]] := key

; Games where Pause key should pass through untouched
GAME_BLOCKLIST := ["overwatch.exe"]

IsBlockedApp() {
    for exe in GAME_BLOCKLIST
        if WinActive("ahk_exe " exe)
            return true
    return false
}

; ==============================================================================
; NOTIFICATION SYSTEM (dual-monitor, from jbs_view.ahk)
; ==============================================================================

g_notifLeft := 0
g_notifRight := 0
g_notifTimer := 0

LeftMonitorCenter(&cx, &cy) {
    leftL := 99999
    loop MonitorGetCount() {
        MonitorGet(A_Index, &L, &T, &R, &B)
        if L < leftL {
            leftL := L
            cx := (L + R) // 2
            cy := (T + B) // 2
        }
    }
}

DismissNotification() {
    global g_notifLeft, g_notifRight, g_notifTimer
    if g_notifTimer
        SetTimer(g_notifTimer, 0)
    if g_notifLeft
        g_notifLeft.Destroy()
    if g_notifRight
        g_notifRight.Destroy()
    g_notifLeft := g_notifRight := g_notifTimer := 0
}

ShowDualNotifications(msg, duration := 1000, textColor := "dedede") {
    global g_notifLeft, g_notifRight, g_notifTimer
    DismissNotification()
    LeftGui := Gui(, "Left"), RightGui := Gui(, "Right")
    for _, g in [LeftGui, RightGui] {
        g.Opt("+AlwaysOnTop -Caption +ToolWindow")
        g.SetFont("s18 w600", "Segoe UI")
        g.BackColor := "2c2c2c"
        g.Add("Text", "c" textColor, msg)
    }
    LeftMonitorCenter(&lx, &ly)
    LeftGui.Show("x-99999 y-99999 NoActivate")
    LeftGui.GetPos(, , &gw, &gh)
    LeftGui.Move(lx - gw // 2, ly - gh // 2 - 100)
    RightGui.Show("xCenter y" (A_ScreenHeight // 2 - gh // 2 - 100) " NoActivate")
    g_notifLeft := LeftGui
    g_notifRight := RightGui
    SetTimer(g_notifTimer := () => DismissNotification(), -duration)
}

; ==============================================================================
; AUDIO DETECTION
; ==============================================================================

GetLoudestApp() {
    try {
        enumerator := IMMDeviceEnumerator()
        device := enumerator.GetDefaultAudioEndpoint(0, 0)
        sessionMgr := device.Activate(IAudioSessionManager2)
        sessionEnum := sessionMgr.GetSessionEnumerator()

        maxPeak := 0
        loudestApp := ""

        loop sessionEnum.GetCount() {
            session := sessionEnum.GetSession(A_Index - 1)
            control := session.QueryInterface(IAudioSessionControl2)
            meter := session.QueryInterface(IAudioMeterInformation)
            peak := meter.GetPeakValue()

            if (peak > 0.00001 && peak > maxPeak) {
                pid := control.GetProcessId()
                try processName := ProcessGetName(pid)
                catch
                    continue

                maxPeak := peak
                if EXE_TO_CONFIG.Has(processName)
                    loudestApp := EXE_TO_CONFIG[processName]
                else
                    loudestApp := "unknown:" processName
            }
        }
        return loudestApp
    } catch {
        return ""
    }
}

; ==============================================================================
; CONFIG HELPERS
; ==============================================================================

ResolveConfig(appKey) {
    if APP_CONFIGS.Has(appKey)
        return APP_CONFIGS[appKey]

    ; Unknown app — build dynamic config
    processName := SubStr(appKey, 9)  ; strip "unknown:"
    return Map(
        "exe", processName,
        "strategy", "global_media_key",
        "key", "{Media_Play_Pause}",
        "activateDelay", 100,
        "postSendDelay", 100,
        "displayName", StrReplace(processName, ".exe", "")
    )
}

ResolveDisplayName(appKey) {
    return ResolveConfig(appKey)["displayName"]
}

; ==============================================================================
; WINDOW UTILITIES
; ==============================================================================

FindAppWindow(cfg) {
    DetectHiddenWindows true
    try idList := WinGetList("ahk_exe " cfg["exe"])
    catch
        return 0

    ; Match by window class if configured
    if cfg.Has("windowClass") && cfg["windowClass"] != "" {
        for id in idList {
            if (WinGetClass(id) != cfg["windowClass"])
                continue
            ; Yandex Music: require non-empty title to skip helper windows
            if (cfg["strategy"] = "activate_only" && WinGetTitle(id) = "")
                continue
            return id
        }
        return 0
    }

    return idList.Length > 0 ? idList[1] : 0
}

SaveFocus() {
    try return WinGetID("A")
    catch
        return 0
}

RestoreFocus(prevHwnd) {
    if (prevHwnd && WinExist(prevHwnd))
        WinActivate prevHwnd
}

; ==============================================================================
; SEND STRATEGIES
; ==============================================================================

TryStealthSend(hwnd, cfg) {
    try {
        ControlSend cfg["key"], , hwnd
        return true
    } catch
        return false
}

ActivateSendRestore(hwnd, cfg) {
    SetWinDelay 0
    SetKeyDelay 20, 20
    prevHwnd := SaveFocus()

    ; Save window state
    WS_VISIBLE := 0x10000000
    style := WinGetStyle(hwnd)
    wasMinimized := (WinGetMinMax(hwnd) = -1)
    wasHidden := !(style & WS_VISIBLE)

    ; Make window invisible during activate cycle
    try WinSetTransparent(0, hwnd)

    if wasHidden {
        WinShow hwnd
        Sleep 50
    }
    if wasMinimized {
        WinRestore hwnd
        Sleep cfg.Has("activateDelay") ? cfg["activateDelay"] : 50
    }

    WinActivate hwnd
    if !WinWaitActive(hwnd, , 1) {
        ; Bail — never send to wrong window
        ShowDualNotifications("Failed: " cfg["displayName"], 1500, "f38ba8")
        if wasMinimized
            WinMinimize hwnd
        else if wasHidden
            WinHide hwnd
        try WinSetTransparent("Off", hwnd)
        RestoreFocus(prevHwnd)
        return false
    }

    SendEvent cfg["key"]
    Sleep cfg.Has("postSendDelay") ? cfg["postSendDelay"] : 50

    ; Restore original state
    if wasMinimized
        WinMinimize hwnd
    else if wasHidden
        WinHide hwnd
    try WinSetTransparent("Off", hwnd)
    RestoreFocus(prevHwnd)
    return true
}

; ==============================================================================
; DISPATCHER
; ==============================================================================

SendToApp(appKey, fromMemory := false) {
    cfg := ResolveConfig(appKey)
    strategy := cfg["strategy"]
    displayName := cfg["displayName"]
    notifColor := fromMemory ? "a6e3a1" : "f9e2af"
    ; Audio playing → we're pausing; silence (memory) → we're resuming
    prefix := fromMemory ? "▶️ Play " : "⏸️ Pause "

    ; Strategy 1: global_media_key
    if (strategy = "global_media_key") {
        Send "{Media_Play_Pause}"
        ShowDualNotifications(prefix displayName, 1000, notifColor)
        return true
    }

    hwnd := FindAppWindow(cfg)
    if !hwnd {
        ShowDualNotifications("Not found: " displayName, 1500, "f38ba8")
        return false
    }

    ; Strategy 2: stealth_then_activate
    if (strategy = "stealth_then_activate") {
        if TryStealthSend(hwnd, cfg) {
            ShowDualNotifications(prefix displayName, 1000, notifColor)
            return true
        }
        if ActivateSendRestore(hwnd, cfg) {
            ShowDualNotifications(prefix displayName, 1000, notifColor)
            return true
        }
        return false
    }

    ; Strategy 3: activate_only
    if (strategy = "activate_only") {
        if ActivateSendRestore(hwnd, cfg) {
            ShowDualNotifications(prefix displayName, 1000, notifColor)
            return true
        }
        return false
    }

    return false
}

; ==============================================================================
; MAIN HOTKEY
; ==============================================================================

g_lastApp := ""

HandleMediaToggle() {
    if IsBlockedApp() {
        ShowDualNotifications("Media key blocked (game)", 1000, "f38ba8")
        return
    }
    global g_lastApp
    currentApp := GetLoudestApp()

    if (currentApp) {
        g_lastApp := currentApp
        SendToApp(currentApp)
    } else if (g_lastApp != "") {
        SendToApp(g_lastApp, true)
    } else {
        ShowDualNotifications("No audio detected", 1500, "f38ba8")
    }
}

$Media_Play_Pause:: HandleMediaToggle()

; ==============================================================================
; PAUSE KEY (secondary media trigger with game blocklist)
; ==============================================================================

#HotIf !IsBlockedApp()
Pause:: HandleMediaToggle()

#HotIf IsBlockedApp()
~Pause:: ShowDualNotifications("Pause key blocked (game)", 1000, "f38ba8")

#HotIf

; ==============================================================================
; DEBUG
; ==============================================================================

#HotIf DEBUG_MODE
F4:: {
    app := GetLoudestApp()
    if app
        ShowDualNotifications("Detected: " ResolveDisplayName(app), 2000, "a6e3a1")
    else
        ShowDualNotifications("Silence", 2000, "f9e2af")
}
#HotIf