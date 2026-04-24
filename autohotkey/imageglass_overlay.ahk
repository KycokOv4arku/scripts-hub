#Requires AutoHotkey v2.0
#SingleInstance Force

; ImageGlass Fullscreen Overlay - Auto-shows filename at top when in fullscreen mode
; Toggle auto-mode: Shift+F11 | Auto-hides when windowed or inactive
; Needed params setup ImageGlass/Seetings/General/Image information tags
; Zoom; FileSize; Dimension; Path; ListCount

DEBUG_MODE := false
if DEBUG_MODE {
    try TraySetIcon("D:\YandexDisk\images\Icons\autohotkey-red.ico")
    try FileDelete(A_ScriptDir "\debug.log")
} else
    A_IconHidden := true
A_IconTip := "ImageGlass overlay — fullscreen filename display"

global overlayVisible := false
global lastTitle := ""
global lastMonL := ""
global autoMode := true
global lastPassState := ""
global lastMonW := 0

#HotIf WinActive("ahk_exe ImageGlass.exe") || WinActive("ahk_exe igcmd.exe")

+F11:: {
    ToggleOverlay()
}

#HotIf

; Kill all overlay windows left over from a previous instance before starting
DetectHiddenWindows(true)
while WinExist("IG_Overlay ahk_class AutoHotkeyGUI")
    WinKill("IG_Overlay ahk_class AutoHotkeyGUI")
try WinWaitClose("IG_Overlay ahk_class AutoHotkeyGUI", , 2)
DetectHiddenWindows(false)

global overlayGui := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x20", "IG_Overlay")
overlayGui.MarginX := 0
overlayGui.MarginY := 0
overlayGui.BackColor := "444444"
overlayGui.SetFont("s9 cdedede", "Segoe UI")
global textControl := overlayGui.Add("Text", "w1920 Background444444 cdedede", "")
WinSetTransparent(200, overlayGui)

SetTimer(CheckFullscreen, 500)

DebugLog(msg) {
    global DEBUG_MODE
    if !DEBUG_MODE
        return
    try FileAppend(FormatTime(, "HH:mm:ss") " " msg "`n", A_ScriptDir "\debug.log")
}

CheckFullscreen() {
    global lastMonL, lastPassState

    if (!autoMode)
        return

    if (!WinExist("ahk_exe ImageGlass.exe") && !WinExist("ahk_exe igcmd.exe")) {
        HideOverlay()
        return
    }

    if (!WinActive("ahk_exe ImageGlass.exe") && !WinActive("ahk_exe igcmd.exe")) {
        HideOverlay()
        return
    }

    exe := WinActive("ahk_exe igcmd.exe") ? "ahk_exe igcmd.exe" : "ahk_exe ImageGlass.exe"
    WinGetPos(&x, &y, &w, &h, exe)

    cx := x + w // 2
    cy := y + h // 2
    monL := 0, monT := 0, monW := A_ScreenWidth, monH := A_ScreenHeight
    loop MonitorGetCount() {
        MonitorGet(A_Index, &mL, &mT, &mR, &mB)
        if (cx >= mL && cx < mR && cy >= mT && cy < mB) {
            monL := mL, monT := mT
            monW := mR - mL, monH := mB - mT
            break
        }
    }

    ; WS_CAPTION = 0xC00000 — present on normal/maximized windows, absent on true fullscreen borderless
    isBorderless := !(WinGetStyle(exe) & 0xC00000)
    passState := exe "|" isBorderless "|" x "|" y "|" w "|" h "|" monL "|" monT "|" monW "|" monH
    if (passState != lastPassState) {
        lastPassState := passState
        DebugLog("exe=" exe " win:" x "," y " " w "x" h " | mon:" monL "," monT " " monW "x" monH " | borderless:" isBorderless " | pass:" (isBorderless && x <= monL && y <= monT && w >= monW && h >= monH))
    }

    if (isBorderless && x <= monL && y <= monT && w >= monW && h >= monH) {
        currentTitle := WinGetTitle(exe)

        ; Reposition overlay if monitor changed or not yet shown
        if (!overlayVisible || monL != lastMonL) {
            HideOverlay()
            ShowOverlay(exe, monL, monT, monW, currentTitle)
        } else if (currentTitle != lastTitle) {
            UpdateOverlayText(currentTitle)
        }
    } else {
        HideOverlay()
    }
}

ToggleOverlay() {
    global autoMode

    if (autoMode) {
        autoMode := false
        HideOverlay()
    } else {
        autoMode := true
    }
}

; Returns pixel width of text rendered in the given font at given point size
MeasureTextPx(text, fontName, ptSize) {
    static LOGPIXELSY := 90
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    dpi := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", LOGPIXELSY, "Int")
    hFont := DllCall("CreateFont",
        "Int", -DllCall("MulDiv", "Int", ptSize, "Int", dpi, "Int", 72, "Int"),
        "Int", 0, "Int", 0, "Int", 0, "Int", 400,
        "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0,
        "Str", fontName, "Ptr")
    hOld := DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont)
    sz := Buffer(8, 0)
    DllCall("GetTextExtentPoint32W", "Ptr", hdc, "WStr", text, "Int", StrLen(text), "Ptr", sz)
    w := NumGet(sz, 0, "Int")
    DllCall("SelectObject", "Ptr", hdc, "Ptr", hOld)
    DllCall("DeleteObject", "Ptr", hFont)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return w
}

; Strips leading path components until title fits in monW pixels, keeping filename and count
FitTitleToWidth(title, monW, fontName, ptSize) {
    if MeasureTextPx(title, fontName, ptSize) <= monW
        return title

    ; Isolate the path segment (drive-letter absolute path ending in file extension)
    if !RegExMatch(title, "([A-Za-z]:\\[^\n\r]+\.[A-Za-z0-9]{2,5})", &m)
        return title

    fullPath := m[1]
    SplitPath(fullPath, &fname, &dir)

    ; Remove one leading component at a time: C:\a\b\c -> ...\b\c -> ...\c
    candidate := dir
    loop {
        if !RegExMatch(candidate, "^(?:\.\.\.)?\\?[^\\]+\\(.+)$", &cm)
            break
        candidate := "..." cm[1]
        rebuilt := StrReplace(title, fullPath, candidate "\" fname, , , 1)
        if MeasureTextPx(rebuilt, fontName, ptSize) <= monW
            return rebuilt
    }

    ; Filename itself is too long — binary search on stem length: keep ...stem_prefix...ext
    SplitPath(fname, , , &ext, &stem)
    dotExt := (ext != "") ? "." ext : ""
    lo := 0, hi := StrLen(stem)
    while lo < hi {
        mid := (lo + hi + 1) // 2
        rebuilt := StrReplace(title, fullPath, "..." SubStr(stem, 1, mid) "..." dotExt, , , 1)
        if MeasureTextPx(rebuilt, fontName, ptSize) <= monW
            lo := mid
        else
            hi := mid - 1
    }
    if lo > 0
        return StrReplace(title, fullPath, "..." SubStr(stem, 1, lo) "..." dotExt, , , 1)
    return StrReplace(title, fullPath, "..." dotExt, , , 1)
}

ShowOverlay(exe, monL, monT, monW, title) {
    global overlayGui, overlayVisible, lastTitle, lastMonL, lastMonW, textControl

    if (!title)
        return

    lastMonW := monW
    lastTitle := title
    lastMonL := monL

    title := FitTitleToWidth(title, monW, "Segoe UI", 9)
    DebugLog("ShowOverlay mon:" monL "," monT " w=" monW ' title="' title '"')
    textControl.Move(, , monW)
    textControl.Text := " " title
    overlayGui.Show("x" monL " y" monT " NoActivate")
    overlayVisible := true
}

UpdateOverlayText(newTitle) {
    global textControl, lastTitle

    if (textControl) {
        global lastMonW
        newTitle := FitTitleToWidth(newTitle, lastMonW, "Segoe UI", 9)
        DebugLog('UpdateText "' newTitle '"')
        textControl.Text := " " newTitle
        lastTitle := newTitle
    }
}

HideOverlay() {
    global overlayGui, overlayVisible, lastMonL

    if overlayVisible {
        DebugLog("HideOverlay")
        overlayGui.Hide()
    }
    overlayVisible := false
    lastMonL := ""
}
