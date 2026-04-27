#Requires AutoHotkey v2.0
#SingleInstance Force

DEBUG_MODE := false
if DEBUG_MODE {
    try TraySetIcon("D:\YandexDisk\images\Icons\autohotkey-red.ico")
    try FileDelete(A_ScriptDir "\debug.log")
} else
    A_IconHidden := true
A_IconTip := "mouse_layer — CapsLock-hold WASD cursor layer with OSL Shift-tap"

Hotkey "F5", ReloadInLayer

ReloadInLayer(*) {
    if !mouseLayerActive
        return
    ShowToast("restarting script", "FFD700", 600)
    SetTimer(() => Reload(), -150)
}

DebugLog(msg) {
    global DEBUG_MODE
    if !DEBUG_MODE
        return
    try FileAppend(FormatTime(, "HH:mm:ss") " " msg "`n", A_ScriptDir "\debug.log")
}

;-----------------------------------------------------------------------
; Toggles mouse mode on CapsLock hold (>0.2s) or CapsLock state on tap
; WASD = cursor movement (velocity profile A or B, switch with 1/2)
; Space/E/Q = left/right/middle mouse buttons
; Alt+W/S = scroll vertical, Alt+A/D = scroll horizontal
; Ctrl+W/S = zoom in/out (sends Ctrl+= / Ctrl+-)
; Z/X = browser back/forward
; LShift tap (no WASD held) = one-shot to base layer for 1.5s
; Esc = exit mouse mode
; Changes cursor color (orange=off, pink=on) + shows toast notifications
; Blocks most keys while in mouse mode to prevent accidental input
;-----------------------------------------------------------------------

; === CAPSLOCK ===
holdTimeToCheck := 0.2

; === VELOCITY ===
g_velocityProfile := "A"            ; "A" = nudge → creep → cruise, "B" = nudge → linear

; Profile A (recommended primary)
TAP_NUDGE_PX      := 2              ; instant nudge on key-down
TAP_THRESHOLD_MS  := 100            ; below this, no continuous movement at all
FINE_SPEED_PX     := 2              ; px/tick during fine phase
FINE_THRESHOLD_MS := 300            ; switch to cruise after this
CRUISE_START_PX   := 8              ; px/tick at start of cruise phase
CRUISE_MAX_PX     := 100            ; cruise ramp cap
CRUISE_RAMP_PX    := 2              ; px added per tick during cruise

; Profile B (linear comparison)
LINEAR_START_PX   := 2
LINEAR_MAX_PX     := 50
LINEAR_RAMP_MS    := 300            ; ms to reach max from start

TICK_MS           := 16
OSL_TAP_MS        := 200            ; Shift-tap must be shorter than this
OSL_DURATION_MS   := 1500

; Global State
global mouseLayerActive := false
global g_shiftDownTime := 0
global g_oslActive     := false
global g_movingActive  := false
global g_hudGui        := 0
global g_hudText       := 0
global g_lastDur       := 0
global g_lastDist      := 0
global g_lastMaxSpeed  := 0

OnExit (*) => RestoreCursors()

; Apply orange cursors on startup
ApplyCursors(true)

; Init debug HUD if in DEBUG_MODE
InitDebugHud()

; === BLOCK IN GAMES / APPS (active window process) ===
blockedProcs := Map("overwatch.exe", true)
IsBlockedAppActive() {
    global blockedProcs
    try {
        p := StrLower(WinGetProcessName("A"))
        return blockedProcs.Has(p)
    } catch {
        return false
    }
}

; Auto-disable mouse mode if a blocked app becomes active
SetTimer CheckBlockedApp, 100
CheckBlockedApp() {
    global mouseLayerActive
    if (mouseLayerActive && IsBlockedAppActive())
        ToggleMouseMode(false)
}

; ==============================================================================
; === CAPSLOCK LOGIC ===
; ==============================================================================
#HotIf !IsBlockedAppActive()
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
#HotIf

; ==============================================================================
; === MOUSE LAYER HOTKEYS ===
; ==============================================================================
#HotIf mouseLayerActive && !g_oslActive && !IsBlockedAppActive() && !GetKeyState("LWin", "P") && !GetKeyState("RWin", "P")

*Esc:: ToggleMouseMode(false)

; Movement (plain WASD only — modified versions fall through to bindings below)
w:: MoveCursor(0, -1)
s:: MoveCursor(0, 1)
a:: MoveCursor(-1, 0)
d:: MoveCursor(1, 0)

; Mouse buttons
*Space::LButton
*e::RButton
*q::MButton

; Vertical scroll (Alt+W/S) — Send releases held Alt, sends plain wheel
!w::Send "{WheelUp}"
!s::Send "{WheelDown}"

; Horizontal scroll (Alt+A/D) → Shift+wheel (universal across apps)
!a::Send "+{WheelUp}"
!d::Send "+{WheelDown}"

; Zoom (Ctrl+W/S) → Ctrl+wheel (universal across apps)
^w::Send "^{WheelUp}"
^s::Send "^{WheelDown}"

; Browser nav (plain Z/X — Ctrl+Z, Ctrl+X still pass through)
z::Send "{Browser_Back}"
x::Send "{Browser_Forward}"

; Velocity profile
*1:: {
    global g_velocityProfile := "A"
    ShowToast("PROFILE A: nudge → fine → cruise", "00ff88")
    DebugLog("profile=A")
    UpdateHud(0, "IDLE", 0)
}
*2:: {
    global g_velocityProfile := "B"
    ShowToast("PROFILE B: nudge → linear", "00ffff")
    DebugLog("profile=B")
    UpdateHud(0, "IDLE", 0)
}

#HotIf

; ==============================================================================
; === TOGGLE & CURSOR LOGIC ===
; ==============================================================================
ToggleMouseMode(isActive) {
    global mouseLayerActive
    mouseLayerActive := isActive

    if (mouseLayerActive) {
        ApplyCursors(false)  ; Pink when ON
        ShowToast("MOUSE MODE: ON", "ff00ff")
        DebugLog("layer=ON profile=" g_velocityProfile)
        ShowHud()
    } else {
        ApplyCursors(true)   ; Orange when OFF
        ShowToast("MOUSE MODE: OFF", "ff8c00")
        DebugLog("layer=OFF")
        HideHud()
    }
}

ShowHud() {
    global g_hudGui
    if g_hudGui
        g_hudGui.Show("x" (A_ScreenWidth - 300) " y10 NoActivate")
}

HideHud() {
    global g_hudGui
    if g_hudGui
        g_hudGui.Hide()
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
; === ONE-SHOT LAYER (Shift-tap → base layer for OSL_DURATION_MS) ===
; ==============================================================================
AnyMoveKeyDown() {
    return GetKeyState("w", "P") || GetKeyState("s", "P") || GetKeyState("a", "P") || GetKeyState("d", "P")
}

EnterOSL() {
    global g_oslActive := true
    ShowToast("→ BASE", "ffff00", OSL_DURATION_MS)
    SetTimer ExitOSL, -OSL_DURATION_MS
    DebugLog("osl=ENTER duration=" OSL_DURATION_MS)
}

ExitOSL() {
    global g_oslActive := false
    ShowToast("← MOUSE", "ff00ff", 600)
    DebugLog("osl=EXIT")
}

#HotIf mouseLayerActive
~LShift:: {
    global g_shiftDownTime
    if (g_shiftDownTime = 0)         ; ignore auto-repeats / re-entries while held
        g_shiftDownTime := A_TickCount
}
~LShift Up:: {
    global g_shiftDownTime
    if (g_shiftDownTime
        && A_TickCount - g_shiftDownTime < OSL_TAP_MS
        && !AnyMoveKeyDown())
        EnterOSL()
    g_shiftDownTime := 0
}
#HotIf

; ==============================================================================
; === DEBUG HUD ===
; ==============================================================================
InitDebugHud() {
    global g_hudGui, g_hudText, DEBUG_MODE
    if !DEBUG_MODE
        return
    g_hudGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    g_hudGui.BackColor := "1a1a1a"
    g_hudGui.SetFont("s10 w400", "Consolas")
    g_hudText := g_hudGui.Add("Text", "cffffff w280 r22", "")
    UpdateHud(0, "IDLE", 0)
}

UpdateHud(elapsed, phase, speed, dist := 0, maxSpeed := 0) {
    global g_hudGui, g_hudText, g_velocityProfile
    global g_lastDur, g_lastDist, g_lastMaxSpeed
    global TAP_NUDGE_PX, TAP_THRESHOLD_MS, FINE_SPEED_PX, FINE_THRESHOLD_MS
    global CRUISE_START_PX, CRUISE_MAX_PX, CRUISE_RAMP_PX
    global LINEAR_START_PX, LINEAR_MAX_PX, LINEAR_RAMP_MS
    if !g_hudText
        return
    if (g_velocityProfile = "A") {
        constants := "TAP_NUDGE_PX:      " TAP_NUDGE_PX "`n"
                   . "TAP_THRESHOLD_MS:  " TAP_THRESHOLD_MS "`n"
                   . "FINE_SPEED_PX:     " FINE_SPEED_PX "`n"
                   . "FINE_THRESHOLD_MS: " FINE_THRESHOLD_MS "`n"
                   . "CRUISE_START_PX:   " CRUISE_START_PX "`n"
                   . "CRUISE_MAX_PX:     " CRUISE_MAX_PX "`n"
                   . "CRUISE_RAMP_PX:    " CRUISE_RAMP_PX
    } else {
        constants := "TAP_NUDGE_PX:      " TAP_NUDGE_PX "`n"
                   . "LINEAR_START_PX:   " LINEAR_START_PX "`n"
                   . "LINEAR_MAX_PX:     " LINEAR_MAX_PX "`n"
                   . "LINEAR_RAMP_MS:    " LINEAR_RAMP_MS
    }
    txt := "PROFILE: " g_velocityProfile "`n"
         . "elapsed: " elapsed " ms`n"
         . "phase:   " phase "`n"
         . "speed:   " Round(speed, 1) " px/tick`n"
         . "dist:    " Round(dist) " px`n"
         . "----`n"
         . "LAST PRESS`n"
         . "  dur:    " g_lastDur " ms`n"
         . "  dist:   " Round(g_lastDist) " px`n"
         . "  maxSpd: " Round(g_lastMaxSpeed, 1) " px/tick`n"
         . "----`n" constants
    g_hudText.Text := txt
}

ComputePhase(elapsed) {
    global g_velocityProfile
    if (elapsed < TAP_THRESHOLD_MS)
        return "TAP"
    if (g_velocityProfile = "A") {
        if (elapsed < FINE_THRESHOLD_MS)
            return "FINE"
        return "CRUISE"
    }
    return "LINEAR"
}

; ==============================================================================
; === MOVEMENT LOGIC ===
; ==============================================================================
MoveCursor(dirX, dirY) {
    global g_movingActive, g_lastDur, g_lastDist, g_lastMaxSpeed

    ; Always-on precision nudge — fires on every key-down
    MouseMove(dirX * TAP_NUDGE_PX, dirY * TAP_NUDGE_PX, 0, "R")

    if g_movingActive
        return                      ; running loop will pick up the new direction

    g_movingActive := true
    startTime := A_TickCount
    dist := TAP_NUDGE_PX            ; count the initial nudge
    maxSpeed := 0
    DebugLog("move=START dir=" dirX "," dirY " profile=" g_velocityProfile)

    try {
        while (mouseLayerActive && !g_oslActive && AnyMoveKeyDown()) {
            if GetKeyState("Alt", "P") || GetKeyState("Ctrl", "P")
             || GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
                break

            x := 0, y := 0
            if GetKeyState("w", "P")
                y := -1
            if GetKeyState("s", "P")
                y :=  1
            if GetKeyState("a", "P")
                x := -1
            if GetKeyState("d", "P")
                x :=  1

            elapsed := A_TickCount - startTime
            speed := ComputeSpeed(elapsed)

            if (speed > 0) {
                MouseMove(x * speed, y * speed, 0, "R")
                dist += speed
                if (speed > maxSpeed)
                    maxSpeed := speed
            }

            UpdateHud(elapsed, ComputePhase(elapsed), speed, dist, maxSpeed)
            Sleep TICK_MS
        }
    } finally {
        g_movingActive := false
        g_lastDur := A_TickCount - startTime
        g_lastDist := dist
        g_lastMaxSpeed := maxSpeed
        DebugLog("move=STOP dur=" g_lastDur " dist=" Round(dist) " maxSpd=" Round(maxSpeed, 1))
        UpdateHud(0, "IDLE", 0, 0, 0)
    }
}

ComputeSpeed(elapsed) {
    global g_velocityProfile
    if (elapsed < TAP_THRESHOLD_MS)
        return 0                                 ; shared tap-only window
    if (g_velocityProfile = "A") {
        if (elapsed < FINE_THRESHOLD_MS)
            return FINE_SPEED_PX                 ; slow creep for precision
        ramp := (elapsed - FINE_THRESHOLD_MS) * CRUISE_RAMP_PX / TICK_MS
        return Min(CRUISE_START_PX + ramp, CRUISE_MAX_PX)
    }
    ; Profile B: smooth linear from start to max over LINEAR_RAMP_MS
    ratio := Min(1, (elapsed - TAP_THRESHOLD_MS) / LINEAR_RAMP_MS)
    return LINEAR_START_PX + (LINEAR_MAX_PX - LINEAR_START_PX) * ratio
}

ShowToast(msg, textColor := "FFFFFF", duration := 1500) {
    global MyGui

    if IsSet(MyGui) && MyGui
        try MyGui.Destroy()

    MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    MyGui.BackColor := "161616"
    MyGui.SetFont("s16 w600", "Segoe UI")
    MyGui.Add("Text", "c" textColor " Center w300", msg)
    MyGui.Show("xCenter yCenter NoActivate")

    capturedGui := MyGui
    DestroyToast() {
        try capturedGui.Destroy()
    }
    SetTimer(DestroyToast, -duration)
}

BlockOtherKeys()
BlockOtherKeys() {
    global lastToast := 0
    keysToBlock := "34567890-=yhujiklopt;cvbnm,./[]\'grf``"
    HotIf (*) => mouseLayerActive
        && !g_oslActive
        && !IsBlockedAppActive()
        && !GetKeyState("LWin", "P") && !GetKeyState("RWin", "P")
        && !GetKeyState("Alt", "P") && !GetKeyState("Ctrl", "P")
    loop parse keysToBlock {
        Hotkey "*" A_LoopField, (*) => (A_TickCount - lastToast > 500 ? (lastToast := A_TickCount, ShowToast(
            "MOUSE MODE: ON", "ff00ff")) : "")
    }
    HotIf
}
