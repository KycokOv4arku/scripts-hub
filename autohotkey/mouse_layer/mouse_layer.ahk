#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

;-----------------------------------------------------------------------
; Toggles mouse mode on CapsLock hold (>0.2s) or CapsLock state on tap
; WASD = cursor movement with acceleration, Shift = fast, Ctrl = slow
; Space/E/Q = left/right/middle mouse buttons
; R/F = scroll wheel up/down
; Alt+A/D = browser back/forward
; Esc = exit mouse mode
; Changes cursor color (orange=off, pink=on) + shows toast notifications
; Blocks most keys while in mouse mode to prevent accidental input
;-----------------------------------------------------------------------

; === SPEED SETTINGS ===
holdTimeToCheck := 0.2
baseSpeed := 1
accelRate := 0.2
maxBaseSpeed := 30
fastSpeed := 50
slowSpeed := 1

; Global State
global mouseLayerActive := false

OnExit (*) => RestoreCursors()

; Apply orange cursors on startup
ApplyCursors(true)

; ==============================================================================
; === CAPSLOCK LOGIC ===
; ==============================================================================
CapsLock:: {
    ; If mouse mode is ON: turn OFF immediately on press
    if (mouseLayerActive) {
        ToggleMouseMode(false)
        KeyWait "CapsLock"
        return
    }

    ; If mouse mode is OFF: turn ON after hold, else toggle CapsLock
    if !KeyWait("CapsLock", "T" holdTimeToCheck) {
        ToggleMouseMode(true)
        KeyWait "CapsLock"
    } else {
        SetCapsLockState !GetKeyState("CapsLock", "T")
    }
}

; ==============================================================================
; === MOUSE LAYER HOTKEYS ===
; ==============================================================================
#HotIf mouseLayerActive && !GetKeyState("LWin", "P") && !GetKeyState("RWin", "P")

*Esc:: ToggleMouseMode(false)

!a:: Send "{Browser_Back}"
!d:: Send "{Browser_Forward}"

*w:: MoveCursor(0, -1)
*s:: MoveCursor(0, 1)
*a:: MoveCursor(-1, 0)
*d:: MoveCursor(1, 0)

*Space::LButton
*e::RButton
*q::MButton
*r:: Click "WheelUp"
*f:: Click "WheelDown"

#HotIf

; ==============================================================================
; === TOGGLE & CURSOR LOGIC ===
; ==============================================================================
ToggleMouseMode(isActive) {
    global mouseLayerActive := isActive

    if (mouseLayerActive) {
        ApplyCursors(false)  ; Pink when ON
        ShowToast("MOUSE MODE: ON", "ff00ff")
    } else {
        ApplyCursors(true)   ; Orange when OFF
        ShowToast("MOUSE MODE: OFF", "ff8c00")
    }
}

ApplyCursors(isOrange) {
    base_dir := "D:\yd\gd\cs\scripts-hub\autohotkey\mouse_layer\"
    cursor_dir := base_dir . (isOrange ? "orange\" : "pink\")

    cursor_map := Map(
        32512, "arrow_eoa.cur",
        32513, "ibeam_eoa.cur",
        32514, "wait_eoa.cur",
        32515, "cross_eoa.cur",
        32516, "up_eoa.cur",
        32640, "nesw_eoa.cur",
        32641, "ns_eoa.cur",
        32642, "nwse_eoa.cur",
        32643, "ew_eoa.cur",
        32644, "move_eoa.cur",
        32645, "unavail_eoa.cur",
        32646, "link_eoa.cur",
        32648, "busy_eoa.cur",
        32649, "helpsel_eoa.cur",
        32650, "pin_eoa.cur",
        32651, "person_eoa.cur"
    )

    for cursor_id, filename in cursor_map {
        CursorHandle := DllCall("LoadCursorFromFile", "Str", cursor_dir . filename, "Ptr")
        if (CursorHandle)
            DllCall("SetSystemCursor", "Ptr", CursorHandle, "Int", cursor_id)
    }
}

RestoreCursors() {
    DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0)
}

; ==============================================================================
; === MOVEMENT LOGIC ===
; ==============================================================================
MoveCursor(dirX, dirY) {
    if GetKeyState("Alt", "P")
        return

    currentSpeed := baseSpeed
    while (mouseLayerActive && (GetKeyState("w", "P") || GetKeyState("s", "P") || GetKeyState("a", "P") || GetKeyState(
        "d", "P"))) {
        if GetKeyState("LWin", "P") || GetKeyState("RWin", "P") || GetKeyState("Alt", "P")
            break

        if GetKeyState("Shift", "P")
            moveSpeed := fastSpeed
        else if GetKeyState("Ctrl", "P")
            moveSpeed := slowSpeed
        else {
            moveSpeed := currentSpeed
            currentSpeed += accelRate
            if (currentSpeed > maxBaseSpeed)
                currentSpeed := maxBaseSpeed
        }

        x := 0, y := 0
        if GetKeyState("w", "P")
            y := -1
        if GetKeyState("s", "P")
            y := 1
        if GetKeyState("a", "P")
            x := -1
        if GetKeyState("d", "P")
            x := 1

        MouseMove(x * moveSpeed, y * moveSpeed, 0, "R")
        Sleep(16)
    }
}

ShowToast(msg, textColor := "FFFFFF", duration := 1500) {
    try {
        global MyGui
        if IsSet(MyGui) && MyGui
            MyGui.Destroy()
    }

    MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    MyGui.BackColor := "161616"
    MyGui.SetFont("s16 w600", "Segoe UI")
    MyGui.Add("Text", "c" textColor " Center w300", msg)
    MyGui.Show("xCenter yCenter NoActivate")

    SetTimer () => (IsSet(MyGui) && MyGui ? MyGui.Destroy() : ""), -duration
}

BlockOtherKeys()
BlockOtherKeys() {
    global lastToast := 0
    keysToBlock := "1234567890-=yhujiklopt;zxcvbnm,./[]\'g``"
    HotIf (*) => mouseLayerActive && !GetKeyState("LWin", "P") && !GetKeyState("RWin", "P") && !GetKeyState("Alt", "P")
    loop parse keysToBlock {
        Hotkey "*" A_LoopField, (*) => (A_TickCount - lastToast > 500 ? (lastToast := A_TickCount, ShowToast(
            "MOUSE MODE: ON", "ff00ff")) : "")
    }
    HotIf
}
