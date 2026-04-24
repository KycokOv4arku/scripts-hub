#Requires AutoHotkey v2.0
#SingleInstance Force

TraySetIcon("D:\YandexDisk\images\Icons\joystick2.ico")
A_IconTip := "Stardew remap 'R' (SC013) -> Y (F5 toggle)"

;------------------------------------------------------------------------------
; Notification system (same pattern as yandex_music_remap.ahk / jbs_view.ahk)
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

;------------------------------------------------------------------------------
; Dev reload
;------------------------------------------------------------------------------
^+r:: {
    ShowDualNotifications("Reloading...", 1000)
    SetTimer(() => Reload(), 1100)
}

;------------------------------------------------------------------------------
; Stardew Valley remaps
;------------------------------------------------------------------------------
g_remapEnabled := true

#HotIf WinActive("ahk_exe Stardew Valley.exe") || WinActive("ahk_exe StardewModdingAPI.exe")

F5:: {
    global g_remapEnabled
    g_remapEnabled := !g_remapEnabled
    ShowDualNotifications("Remap Y->R " (g_remapEnabled ? "ON" : "OFF"), 1000)
}

SC013:: {  ; Physical R key (layout-independent) -> Y key down
    global g_remapEnabled
    if g_remapEnabled {
        SendEvent("{SC015 down}")  ; SC015 = Y key, layout-independent
        ShowDualNotifications("Y", 1000)
    } else
        SendEvent("{SC013 down}")
}

SC013 up:: {  ; Physical R key up -> Y key up
    global g_remapEnabled
    if g_remapEnabled
        SendEvent("{SC015 up}")
    else
        SendEvent("{SC013 up}")
}

#HotIf