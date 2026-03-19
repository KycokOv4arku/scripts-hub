#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

;------------------------------------------------------------------------------
; Script: yandex_music_remap.ahk
; Purpose: WASD-style controls for Yandex Music (active window only)
; Layout-independent: scan codes for input, arrow/VK codes for output
; Temporary until media_button branch is merged
;
; Hotkeys (only when Yandex Music is focused):
;   Space    → play/pause       Q/E     → like/dislike
;   W/S      → vol up/down      Z       → mute
;   A/D      → rewind/forward   X       → shuffle
;   Shift+A  → prev track       R       → repeat
;   Shift+D  → next track       F       → fullscreen
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Notification system (same pattern as jbs_view.ahk)
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
; Yandex Music remaps
;------------------------------------------------------------------------------
#HotIf WinActive("ahk_exe Яндекс Музыка.exe")

SC039:: {  ; Space → play/pause
    Send "{vk4B}"
    ShowDualNotifications("YM play/pause")
}
SC011:: {  ; W → volume up
    Send "{Up}"
    ShowDualNotifications("YM vol up")
}
SC01F:: {  ; S → volume down
    Send "{Down}"
    ShowDualNotifications("YM vol down")
}
SC01E:: {  ; A → rewind
    Send "{Left}"
    ShowDualNotifications("YM rewind")
}
SC020:: {  ; D → skip forward
    Send "{Right}"
    ShowDualNotifications("YM forward")
}
+SC01E:: {  ; Shift+A → prev track
    Send "{vk50}"
    ShowDualNotifications("YM prev")
}
+SC020:: {  ; Shift+D → next track
    Send "{vk4E}"
    ShowDualNotifications("YM next")
}
SC010:: {  ; Q → like
    Send "{vk46}"
    ShowDualNotifications("YM like")
}
SC012:: {  ; E → dislike
    Send "{vk44}"
    ShowDualNotifications("YM dislike")
}
SC02C:: {  ; Z → mute
    Send "{vk4D}"
    ShowDualNotifications("YM mute")
}
SC02D:: {  ; X → shuffle
    Send "{vk53}"
    ShowDualNotifications("YM shuffle")
}
SC013:: {  ; R → toggle repeat
    Send "{vk52}"
    ShowDualNotifications("YM repeat")
}
SC021:: {  ; F → fullscreen
    Send "{vk57}"
    ShowDualNotifications("YM fullscreen")
}

#HotIf
