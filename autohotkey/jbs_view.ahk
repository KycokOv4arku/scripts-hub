#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
; Win+V chord: view current JBS wallpaper per monitor — coauthored w/ Claude

JBS_VIEW_KEY := "^!v"  ; Ctrl+Alt+V — view current hotkey from JBS settings
g_ih := 0

; Returns screen-center coords of the leftmost monitor
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

ShowDualNotifications(msg, duration := 1000) {
    LeftGui := Gui(, "Left"), RightGui := Gui(, "Right")
    for _, g in [LeftGui, RightGui] {
        g.Opt("+AlwaysOnTop -Caption +ToolWindow")
        g.SetFont("s18 w600", "Segoe UI")
        g.BackColor := "2c2c2c"
        g.Add("Text", "cdedede", msg)  ; no fixed width — auto-sizes to content
    }
    LeftMonitorCenter(&lx, &ly)
    ; show off-screen first, measure, then center on left monitor
    LeftGui.Show("x-99999 y-99999 NoActivate")
    LeftGui.GetPos(, , &gw, &gh)
    LeftGui.Move(lx - gw // 2, ly - gh // 2)
    RightGui.Show("xCenter yCenter NoActivate")
    SetTimer(() => (LeftGui.Destroy(), RightGui.Destroy()), -duration)
}

; Only suppress 1/2 (InputHook captures them); everything else stops hook
; and passes the key through to JBS dialog
ChordKeyFilter(ih, vk, sc) {
    if Chr(vk) = "1" || Chr(vk) = "2"
        return 1  ; suppress — InputHook captures it
    ih.Stop()
    return 0      ; don't suppress — passes through to JBS dialog
}

; Cancel chord on mouse buttons — hook stops, JBS dialog keeps focus
CancelChord() {
    global g_ih
    if g_ih
        g_ih.Stop()
}
~LButton:: CancelChord()
~RButton:: CancelChord()
~MButton:: CancelChord()
~XButton1:: CancelChord()
~XButton2:: CancelChord()

; Win+V: open JBS dialog immediately, then:
;   1 → auto-select monitor 1 (left)
;   2 → auto-select monitor 2 (right)
;   timeout / any other key / mouse → dialog stays open for manual use
#v:: {
    global g_ih, JBS_VIEW_KEY
    SendEvent JBS_VIEW_KEY
    if !WinWait("Select Background", , 10) {
        ShowDualNotifications("JBS dialog not found")
        return
    }
    SetWinDelay -1
    WinActivate "Select Background"  ; force focus in case user clicked away during load
    g_ih := InputHook("L1 T10")
    g_ih.OnKeyDown := ChordKeyFilter
    g_ih.Start()
    g_ih.Wait()
    key := g_ih.Input
    g_ih := 0
    if key != "1" && key != "2" {
        ShowDualNotifications("JBS abort")
        return
    }
    WinActivate "Select Background"  ; reactivate in case focus shifted while waiting
    SendEvent (key = "1") ? "{Tab}{Tab}{Right}{Left}{Enter}" : "{Tab}{Tab}{Right}{Enter}"
    ShowDualNotifications("JBS current " (key = "1" ? "left" : "right"))
}
