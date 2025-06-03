#Requires AutoHotkey v2.0

; -----------------------------------------------------------------------------
; Telegram Toggle & Notifications (AutoHotkey v2.0)
; • Hotkey: Win+Q
;   – If Telegram is active: hides window and sends “TG hidden to tray” notification
;   – If Telegram is hidden: shows and activates window, “TG is now active” notification
;   – If Telegram is not running: launches executable, waits for it, then “TG is launching” notification
; • Notifications:
;   – Shown on both left and right monitors
;   – Customizable message and duration
; • Globals:
;   – tg_hwnd: stores Telegram window handle for hide/show logic
; • Functions:
;   – ShowDualNotifications(leftMessage, rightMessage, duration := 2000)
;       • Builds two transparent GUIs (one per monitor) with custom font and background
;       • Displays messages at specified positions for given duration
; -----------------------------------------------------------------------------

global tg_hwnd := 0  ; Store TG window handle

#q:: {
    global tg_hwnd  ; Ensure global variable is accessible inside function

    if WinActive("ahk_exe Telegram.exe") {
        tg_hwnd := WinGetID("ahk_exe Telegram.exe")  ; Store window handle
        WinHide(tg_hwnd)  ; Hide TG

        ; show notification
        ShowDualNotifications(
            "TG hidden to tray",
            "TG hidden to tray",
            2000
        )

        WinSetTransparent 255, tg_hwnd ; ensure transparency being back to default.

    } else if tg_hwnd && WinExist(tg_hwnd) {
        WinShow(tg_hwnd)  ; Restore hidden window
        WinActivate(tg_hwnd)
        WinSetTransparent 255, tg_hwnd ; ensure transparency being back to default.

        ; show notification
        ShowDualNotifications(
            "TG is now active",
            "TG is now active",
            2000
        )
    } else {
        Run "D:\Programs\Telegram_portable_5.9.0\Telegram.exe"
        ; show notification
        ShowDualNotifications(
            "TG is launching",
            "TG is launching",
            3000
        )
        WinWaitActive("ahk_exe Telegram.exe", , 5)
        Sleep 500
        tg_hwnd := WinGetID("ahk_exe Telegram.exe")  ; Store new instance
        WinSetTransparent 255, tg_hwnd ; ensure transparency being back to default.

    }
}

; claude helped to do notifications for both monitors.
ShowDualNotifications(leftMessage, rightMessage, duration := 2000) {
    ; Create GUIs for both monitors
    LeftGui := Gui(, "Left Monitor")
    RightGui := Gui(, "Right Monitor")

    ; Style Left GUI
    LeftGui.Opt("+AlwaysOnTop -Caption +ToolWindow")
    LeftGui.SetFont("s18 w600", "Segoe UI")
    LeftGui.BackColor := "161616"

    ; Style Right GUI
    RightGui.Opt("+AlwaysOnTop -Caption +ToolWindow")
    RightGui.SetFont("s18 w600", "Segoe UI")
    RightGui.BackColor := "161616"

    ; Add text with custom styling
    textOpts := "cdedede w240" ; play with w400 as width of a notification box. based on longest msg.
    LeftGui.Add("Text", textOpts, leftMessage)
    RightGui.Add("Text", textOpts, rightMessage)

    ; Calculate center positions
    leftX := -700   ; Center of left monitor
    leftY := 522    ; Center of left monitor height
    rightX := 960   ; Center of right monitor
    rightY := 540   ; Center of right monitor height

    ; Show both GUIs
    LeftGui.Show(Format("x{} y{} NoActivate", leftX, leftY))
    ; w := LeftGui.Pos.W, h := LeftGui.Pos.H
    ; LeftGui.Show(Format("x{} y{} NoActivate", leftX - w / 2, leftY - h / 2))
    RightGui.Show("xCenter yCenter NoActivate")

    ; Set up destruction timers
    SetTimer () => (LeftGui.Destroy(), RightGui.Destroy()), -duration
}
