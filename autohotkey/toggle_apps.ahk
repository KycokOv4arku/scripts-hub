#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
;------------------------------------------------------------------------------
; Globals for single-window apps
;------------------------------------------------------------------------------
global hiddenTelegram := 0
global hiddenAIMP := 0
global hiddenYandexMusic := 0
global hiddenObsidian := 0
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
        ShowDualNotifications(exeName " active", exeName " active", 2000)
        WinShow hiddenHandle
        WinActivate hiddenHandle
        %handleName% := 0
    }
    ; Check if visible
    else if WinExist("ahk_exe " exeName ".exe") {
        if WinActive("ahk_exe " exeName ".exe") {
            ShowDualNotifications(exeName " hidden", exeName " hidden", 2000)
            %handleName% := WinExist("A")
            WinHide %handleName%
        }
        else {
            ShowDualNotifications(exeName " active", exeName " active", 2000)
            if WinGetMinMax("ahk_exe " exeName ".exe") = -1
                WinRestore "ahk_exe " exeName ".exe"
            WinActivate "ahk_exe " exeName ".exe"
        }
    }
    ; Launch
    else {
        ShowDualNotifications(exeName " launching", exeName " launching", 2000)
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
        ShowDualNotifications(exeName " active", exeName " active", 2000)

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
            ShowDualNotifications(exeName " active", exeName " active", 2000)
            WinActivate visible[1]
            return
        }

        ShowDualNotifications(exeName " hidden", exeName " hidden", 2000)
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
    ShowDualNotifications(exeName " launching", exeName " launching", 2000)
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
^#s:: ToggleSingleApp("YandexMusic", "C:\Users\kycok\AppData\Local\Programs\YandexMusic\YandexMusic.exe",
    "hiddenYandexMusic")
; Obsidian -> Win + A
#a:: ToggleSingleApp("Obsidian", "C:\Users\kycok\AppData\local\Programs\Obsidian\Obsidian.exe", "hiddenObsidian")
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
ShowDualNotifications(leftMsg, rightMsg, duration := 2000) {
    LeftGui := Gui(, "Left"), RightGui := Gui(, "Right")
    for _, g in [LeftGui, RightGui] {
        g.Opt("+AlwaysOnTop -Caption +ToolWindow")
        g.SetFont("s18 w600", "Segoe UI")
        g.BackColor := "161616"
        g.Add("Text", "cdedede w200 Center", (g = LeftGui) ? leftMsg : rightMsg)
    }
    LeftGui.Show("x-700 y522 NoActivate"), RightGui.Show("xCenter yCenter NoActivate")
    SetTimer () => (LeftGui.Destroy(), RightGui.Destroy()), -duration
}
