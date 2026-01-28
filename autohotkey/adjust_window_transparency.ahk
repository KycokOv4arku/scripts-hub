#Requires AutoHotkey v2.0
#SingleInstance Force Force
#NoTrayIcon

; -----------------------------------------------------------------------------
; Window Transparency Manager (AutoHotkey v2.0)
; - Saves/restores active window transparency via “transparency.ini”
; - Ctrl+Shift+Alt + Wheel Up:   +5 transparency (max 255)
; - Ctrl+Shift+Alt + Wheel Down: –5 transparency (min 1)
;
; File:
; • transparency.ini: Last-used transparency (1–255)
;
; Functions:
; • RestoreTransparency():
;     • If “transparency.ini” has a valid number, apply it
;     • Else use defaultTransparency (255)
; • AdjustTransparency(step):
;     • Get current transparency (fallback to default if invalid)
;     • newTransparency = clamp(current + step, 1, 255)
;     • Apply newTransparency and save to “transparency.ini”
; -----------------------------------------------------------------------------

transparencyFile := A_ScriptDir "\transparency.ini"
defaultTransparency := 255  ; Set default transparency to 255

RestoreTransparency() {
    if FileExist(transparencyFile) {
        savedTransparency := Trim(FileRead(transparencyFile))  ; Read & trim spaces/newlines
        if (savedTransparency != "" && savedTransparency Is Number) {
            WinSetTransparent(savedTransparency + 0, "A")
            OutputDebug("Restored Transparency: " savedTransparency)
            return
        }
    }
    ; If no valid saved transparency, set to default (240)
    WinSetTransparent(defaultTransparency, "A")
    OutputDebug("No saved transparency. Setting default: " defaultTransparency)
}

AdjustTransparency(step) {
    currentTransparency := WinGetTransparent("A")
    OutputDebug("Current Transparency: " currentTransparency)

    if (currentTransparency = "" || !IsNumber(currentTransparency))  ; Handle empty/invalid values
        currentTransparency := defaultTransparency  ; Use default 240 if needed

    newTransparency := Max(1, Min(currentTransparency + step, 255))  ; Keep in range 1-255
    WinSetTransparent(newTransparency, "A")

    FileDelete transparencyFile
    FileAppend newTransparency, transparencyFile  ; Save new transparency
    OutputDebug("New Transparency: " newTransparency)
}

^+!WheelUp:: AdjustTransparency(5)   ; Increase transparency
^+!WheelDown:: AdjustTransparency(-5)  ; Decrease transparency

RestoreTransparency()  ; Restore saved
