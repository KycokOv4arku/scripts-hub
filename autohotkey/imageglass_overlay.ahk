#Requires AutoHotkey v2.0
#SingleInstance Force Force
#NoTrayIcon

; ImageGlass Fullscreen Overlay - Auto-shows filename at top when in fullscreen mode
; Toggle auto-mode: Shift+F11 | Auto-hides when windowed or inactive
; Needed params setup ImageGlass/Seetings/General/Image information tags
; Zoom; FileSize; Dimension; Path; ListCount

global overlayGui := ""
global overlayVisible := false
global lastTitle := ""
global textControl := ""
global autoMode := true

#HotIf WinActive("ahk_exe ImageGlass.exe") || WinActive("ahk_exe igcmd.exe")

+F11:: {
    ToggleOverlay()
}

#HotIf

; Auto-show in fullscreen, hide when not
SetTimer(CheckFullscreen, 500)

CheckFullscreen() {
    if (!autoMode) {
        return
    }

    if (!WinExist("ahk_exe ImageGlass.exe") && !WinExist("ahk_exe igcmd.exe")) {
        HideOverlay()
        return
    }

    if (!WinActive("ahk_exe ImageGlass.exe") && !WinActive("ahk_exe igcmd.exe")) {
        HideOverlay()
        return
    }

    ; Check if fullscreen (window matches screen size)
    if (WinActive("ahk_exe igcmd.exe")) {
        WinGetPos(&x, &y, &w, &h, "ahk_exe igcmd.exe")
    } else {
        WinGetPos(&x, &y, &w, &h, "ahk_exe ImageGlass.exe")
    }
    if (x <= 0 && y <= 0 && w >= A_ScreenWidth && h >= A_ScreenHeight) {
        ; Fullscreen detected
        currentTitle := WinActive("ahk_exe igcmd.exe") ? WinGetTitle("ahk_exe igcmd.exe") : WinGetTitle(
            "ahk_exe ImageGlass.exe")

        if (!overlayVisible) {
            ShowOverlay()
        } else if (currentTitle != lastTitle) {
            ; Title changed, update overlay text only
            UpdateOverlayText(currentTitle)
        }
    } else {
        ; Not fullscreen
        HideOverlay()
    }
}

ToggleOverlay() {
    global autoMode

    if (autoMode) {
        ; Turn off auto mode
        autoMode := false
        HideOverlay()
    } else {
        ; Turn auto mode back on
        autoMode := true
    }
}

ShowOverlay() {
    global overlayGui, overlayVisible, lastTitle, textControl

    ; Get ImageGlass window title
    title := WinGetTitle("ahk_exe ImageGlass.exe")

    if (!title) {
        return
    }

    lastTitle := title

    ; Create overlay
    overlayGui := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x20")
    overlayGui.BackColor := "444444"
    overlayGui.SetFont("s8 cdedede", "Segoe UI")

    textControl := overlayGui.Add("Text", "w1920 Background444444 cdedede", title)

    ; Position at top-left of ImageGlass window
    WinGetPos(&x, &y, &w, &h, "ahk_exe ImageGlass.exe")
    overlayGui.Show("x" . (x) . " y" . (y) . " NoActivate")

    ; Make semi-transparent
    WinSetTransparent(200, overlayGui)

    overlayVisible := true
}

UpdateOverlayText(newTitle) {
    global textControl, lastTitle

    if (textControl) {
        textControl.Text := newTitle
        lastTitle := newTitle
    }
}

HideOverlay() {
    global overlayGui, overlayVisible

    if (overlayGui) {
        overlayGui.Destroy()
        overlayGui := ""
    }
    overlayVisible := false
}
