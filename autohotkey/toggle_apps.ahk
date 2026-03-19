#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
#NoTrayIcon

;------------------------------------------------------------------------------
; Script: toggle_apps.ahk
; Purpose: Hide/show single and multi-window applications with hotkeys
; Features:
;   - Toggle single-window apps (Telegram, AIMP, Yandex Music, Obsidian, qBittorrent)
;   - Toggle multi-window apps (VS Code, Windows Terminal)
;   - Preserve window states and Z-order
;   - Show dual-screen notifications
; Hotkeys: Win+Q, Win+S, Ctrl+Win+S, Win+A, Win+T, Win+C, Ctrl+Win+C
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Globals for single-window apps
;------------------------------------------------------------------------------
global hiddenTelegram := 0
global hiddenAIMP := 0
global hiddenYandexMusic := 0
global hiddenObsidian := []
global activeObsidian := 0
global stateObsidian := []
global hiddenqBittorrent := 0

;------------------------------------------------------------------------------
; Globals for multi-window apps
;------------------------------------------------------------------------------
global hiddenVSCode := []
global activeVSCode := 0
global stateVSCode := []
global hiddenWindowsTerminal := []
global activeWindowsTerminal := 0
global stateWindowsTerminal := []

;------------------------------------------------------------------------------
; Reusable toggle function for single-window apps
;------------------------------------------------------------------------------
ToggleSingleApp(exeName, exePath, handleName) {
    global

    ; Get the actual variable by name
    hiddenHandle := %handleName%

    ; Check if hidden
    if (hiddenHandle && WinExist(hiddenHandle)) {
        ShowDualNotifications(exeName " active")
        WinShow hiddenHandle
        WinActivate hiddenHandle
        %handleName% := 0
    }
    ; Check if visible
    else if WinExist("ahk_exe " exeName ".exe") {
        if WinActive("ahk_exe " exeName ".exe") {
            ShowDualNotifications(exeName " hidden")
            %handleName% := WinExist("A")
            WinHide %handleName%
        }
        else {
            ShowDualNotifications(exeName " active")
            if WinGetMinMax("ahk_exe " exeName ".exe") = -1
                WinRestore "ahk_exe " exeName ".exe"
            WinActivate "ahk_exe " exeName ".exe"
        }
    }
    ; Launch
    else {
        ShowDualNotifications(exeName " launching")
        Run exePath
        if WinWait("ahk_exe " exeName ".exe", , 3)
            WinActivate "ahk_exe " exeName ".exe"
                %handleName% := 0
    }
}

;------------------------------------------------------------------------------
; Reusable toggle function for multi-window apps
;------------------------------------------------------------------------------
ToggleMultiApp(exeName, exePath, handleName, activeName, stateName) {
    global
    hiddenHandles := %handleName%
    activeHandle := %activeName%
    windowStates := %stateName%

    ; 1. Restore hidden windows
    if (hiddenHandles.Length > 0) {
        ShowDualNotifications(exeName " active")

        ; Restore in REVERSE order to preserve Z-order (bottom to top)
        ; WinGetList returns windows in Z-order (top to bottom)
        ; Restoring bottom-first keeps the original stacking order
        loop hiddenHandles.Length {
            index := hiddenHandles.Length - A_Index + 1
            hwnd := hiddenHandles[index]

            if WinExist(hwnd) {
                WinShow hwnd

                ; Restore original state (skip minimized to preserve Z-order)
                state := windowStates[index]
                if (state = 1)  ; Was maximized
                    WinMaximize hwnd
                else if (state = -1)  ; Was minimized - restore to normal instead
                    WinRestore hwnd
                else  ; Was normal
                    WinRestore hwnd

                WinSetTransparent(240, hwnd)
            }
        }
        Sleep 10

        ; Activate the originally active window and ensure it's on top
        if (activeHandle && WinExist(activeHandle)) {
            WinActivate activeHandle
            Sleep 10
            WinMoveTop activeHandle

            %handleName% := []
            %activeName% := 0
            %stateName% := []
            return
        }
    }

    ; 2. Hide and store states
    DetectHiddenWindows(false)
    visible := WinGetList("ahk_exe " exeName ".exe")

    if (visible.Length > 0) {
        isAnyActive := false
        activeHwnd := 0
        for hwnd in visible {
            if WinActive(hwnd) {
                isAnyActive := true
                activeHwnd := hwnd
                break
            }
        }

        if (!isAnyActive) {
            ShowDualNotifications(exeName " active")
            for hwnd in visible {
                if WinGetMinMax(hwnd) = -1
                    WinRestore hwnd
            }
            WinActivate visible[1]
            return
        }

        ShowDualNotifications(exeName " hidden")
        %activeName% := activeHwnd
        %handleName% := []
        %stateName% := []

        for hwnd in visible {
            state := WinGetMinMax(hwnd)  ; Get current state
            WinHide hwnd
            WinSetTransparent(240, hwnd)
            %handleName%.Push(hwnd)
            %stateName%.Push(state)  ; Store state
        }
        return
    }

    ; 3. Launch
    ShowDualNotifications(exeName " launching")
    Run '"' exePath '"'
    if WinWait("ahk_exe " exeName ".exe", , 3)
        WinActivate "ahk_exe " exeName ".exe"
}

;------------------------------------------------------------------------------
; Hotkey setup
;------------------------------------------------------------------------------
; Telegram -> Win + Q
#q:: ToggleSingleApp("Telegram", "D:\Programs\Telegram_portable\Telegram.exe", "hiddenTelegram")
; AIMP -> Win + S
#s:: ToggleSingleApp("AIMP", "D:\Programs\AIMP_portable\AIMP.exe", "hiddenAIMP")
; Yandex Music -> Ctrl + Win + S
^#s:: ToggleSingleApp("Яндекс Музыка", "C:\Users\kycok\AppData\Local\Programs\YandexMusic\Яндекс Музыка.exe",
    "hiddenYandexMusic")
; Obsidian -> Win + A
#a:: ToggleMultiApp("Obsidian", "C:\Users\kycok\AppData\local\Programs\Obsidian\Obsidian.exe",
    "hiddenObsidian", "activeObsidian", "stateObsidian")
; qBittorrent -> Win + T
#t:: ToggleSingleApp("qBittorrent", "C:\Program Files\qBittorrent\qbittorrent.exe", "hiddenqBittorrent")
; VSCode -> Win + C
#c:: ToggleMultiApp("Code", "C:\Users\kycok\AppData\Local\Programs\Microsoft VS Code\Code.exe",
    "hiddenVSCode", "activeVSCode", "stateVSCode")
; Windows Terminal -> Ctrl + Win + C
^#c:: ToggleMultiApp("WindowsTerminal", "wt.exe",
    "hiddenWindowsTerminal", "activeWindowsTerminal", "stateWindowsTerminal")

;------------------------------------------------------------------------------
; UI popup msg settings
;------------------------------------------------------------------------------
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

ShowDualNotifications(msg, duration := 1000) {
    global g_notifLeft, g_notifRight, g_notifTimer
    DismissNotification()
    LeftGui := Gui(, "Left"), RightGui := Gui(, "Right")
    for _, g in [LeftGui, RightGui] {
        g.Opt("+AlwaysOnTop -Caption +ToolWindow")
        g.SetFont("s18 w600", "Segoe UI")
        g.BackColor := "2c2c2c"
        g.Add("Text", "cdedede", msg)
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
