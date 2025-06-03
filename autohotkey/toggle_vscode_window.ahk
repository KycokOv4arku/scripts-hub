#Requires AutoHotkey v2.0

; -----------------------------------------------------------------------------
; VSCode Toggle & Notifications (AutoHotkey v2.0)
; • Hotkey: Win+C
;   – If VS Code is active: hides window, resets transparency to 240, “Code hidden to tray”
;   – If VS Code is hidden: shows/activates window, resets transparency to 240,
;     “Code is now active”
;   – If VS Code isn’t running: launches executable, waits for activation,
;     resets transparency to 240, “Code is launching”
; • Globals:
;   – vscode_hwnd: stores VS Code window handle for hide/show logic
; • Function:
;   – ShowDualNotifications(leftMessage, rightMessage, duration := 2000)
;       • Builds two always-on-top GUIs (one per monitor) with custom font/background
;       • Displays messages at specified positions for given duration
; -----------------------------------------------------------------------------

global vscode_hwnd := 0  ; Store VS Code window handle

#c:: {
    global vscode_hwnd  ; Ensure global variable is accessible inside function

    if WinActive("ahk_exe Code.exe") {
        vscode_hwnd := WinGetID("ahk_exe Code.exe")  ; Store window handle
        WinHide(vscode_hwnd)  ; Hide VS Code

        ; show notification
        ShowDualNotifications(
            "Code hidden to tray",
            "Code hidden to tray",
            2000
        )

        WinSetTransparent 240, vscode_hwnd ; ensure transparency being back to default.

    } else if vscode_hwnd && WinExist(vscode_hwnd) {
        WinShow(vscode_hwnd)  ; Restore hidden window
        WinActivate(vscode_hwnd)
        WinSetTransparent 240, vscode_hwnd ; ensure transparency being back to default.

        ; show notification
        ShowDualNotifications(
            "Code is now active",
            "Code is now active",
            2000
        )
    } else {
        Run "C:\Users\kycok\AppData\Local\Programs\Microsoft VS Code\Code.exe"
        ; show notification
        ShowDualNotifications(
            "Code is launching",
            "Code is launching",
            3000
        )
        WinWaitActive("ahk_exe Code.exe", , 5)
        Sleep 500
        vscode_hwnd := WinGetID("ahk_exe Code.exe")  ; Store new instance
        WinSetTransparent 240, vscode_hwnd ; ensure transparency being back to default.

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
