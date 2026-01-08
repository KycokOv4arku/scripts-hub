#Requires AutoHotkey v2.0

; Disable Win+S and pass through (by default search. same as just pressing Win)
; Win+S to minimize/maximize AIMP and handle window focus
global hiddenAIMP := 0

#s::
{
    global hiddenAIMP

    ; Check if we have a hidden AIMP window FIRST
    if (hiddenAIMP && WinExist(hiddenAIMP)) {
        ShowDualNotifications(
            "AIMP active",
            "AIMP active",
            2000
        )
        WinShow hiddenAIMP
        WinActivate hiddenAIMP
        hiddenAIMP := 0
    }
    ; AIMP exists and visible
    else if WinExist("ahk_exe AIMP.exe") {
        if WinActive("ahk_exe AIMP.exe") {
            ShowDualNotifications(
                "AIMP hidden",
                "AIMP hidden",
                2000
            )
            hiddenAIMP := WinExist("A")
            WinHide hiddenAIMP
        }
        else {
            ShowDualNotifications(
                "AIMP active",
                "AIMP active",
                2000
            )
            if WinGetMinMax("ahk_exe AIMP.exe") = -1
                WinRestore "ahk_exe AIMP.exe"
            WinActivate "ahk_exe AIMP.exe"
        }
    }
    else {
        ShowDualNotifications(
            "AIMP launching",
            "AIMP launching",
            2000
        )
        Run "D:\Programs\AIMP_portable\AIMP.exe"
        WinWait "ahk_exe AIMP.exe", , 3
        WinActivate "ahk_exe AIMP.exe"
        hiddenAIMP := 0
    }
}

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
