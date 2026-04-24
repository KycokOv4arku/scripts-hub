#Requires AutoHotkey v2.0
#SingleInstance Force
; Win+V two-level chord: JBS control shortcut — coauthored w/ Claude

DEBUG_MODE := false
if DEBUG_MODE {
    try TraySetIcon("D:\YandexDisk\images\Icons\autohotkey-red.ico")
    try FileDelete(A_ScriptDir "\debug.log")
} else
    A_IconHidden := true
A_IconTip := "jbs_view — JBS wallpaper control chord"

DebugLog(msg) {
    global DEBUG_MODE
    if !DEBUG_MODE
        return
    try FileAppend(FormatTime(, "HH:mm:ss") " " msg "`n", A_ScriptDir "\debug.log")
}

; JBS hotkeys from Settings.xml (all use Ctrl+Alt modifier)
JBS_PREV_KEY := "^!l"  ; view previous picture
JBS_CUR_KEY := "^!k"  ; view current picture
JBS_NEXT_KEY := "^!i"  ; next picture
JBS_CLEAR_KEY := "^!p"  ; clear background
JBS_SETTINGS_KEY := "^!o"  ; show settings

CHORD_TIMEOUT := 10    ; seconds; user input wait + matching popup duration
JBS_LOAD_TIMEOUT := 30 ; seconds; max wait for JBS dialog to appear

g_ih := 0
g_notifLeft := 0
g_notifRight := 0
g_notifTimer := 0
g_poll_label := ""
g_pre_typed := false

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

; Capture one keypress by physical key (layout-independent); mouse/timeout returns ""
; Uses EndKey instead of L1 so Russian/other layouts map to Latin VK names
WaitKey(timeout := 10) {
    global g_ih
    g_ih := InputHook("T" timeout)
    g_ih.KeyOpt("{a}{b}{c}{d}{e}{f}{g}{h}{i}{j}{k}{l}{m}{n}{o}{p}{q}{r}{s}{t}{u}{v}{w}{x}{y}{z}{Escape}{Space}", "ES")
    g_ih.Start()
    g_ih.Wait()
    key := (g_ih.EndReason = "EndKey") ? StrLower(g_ih.EndKey) : ""
    g_ih := 0
    return key
}

; Cancel chord on mouse buttons — stops hook, WaitKey returns ""
CancelChord() {
    global g_ih
    if g_ih
        try g_ih.Stop()
}
~LButton:: CancelChord()
~RButton:: CancelChord()
~MButton:: CancelChord()
~XButton1:: CancelChord()
~XButton2:: CancelChord()

_PollPreTyped() {
    global g_ih, g_poll_label, g_pre_typed, JBS_LOAD_TIMEOUT
    if g_pre_typed || !g_ih
        return
    if g_ih.EndReason = "EndKey" {
        g_pre_typed := true
        ShowDualNotifications("queued: " g_poll_label " → " (StrLower(g_ih.EndKey) = "a" ? "left" : "right"), (JBS_LOAD_TIMEOUT + 5) * 1000)
    }
}

; Opens JBS dialog, waits for a/d to pick left/right monitor.
; Hook starts before SendEvent so fast-typed a/d is buffered while JBS loads.
ViewWithMonitor(jbs_key, label) {
    global g_ih, CHORD_TIMEOUT, JBS_LOAD_TIMEOUT, g_poll_label, g_pre_typed
    g_ih := InputHook("T" CHORD_TIMEOUT)
    g_ih.KeyOpt("{a}{d}{Escape}{Space}", "ES")
    g_ih.Start()
    DebugLog("ViewWithMonitor label=" label " hook_started")
    SendEvent jbs_key
    ShowDualNotifications("a=left   d=right", CHORD_TIMEOUT * 1000)

    g_poll_label := label
    g_pre_typed := false
    SetTimer(_PollPreTyped, 100)

    if !WinWait("Select Background", , JBS_LOAD_TIMEOUT) {
        SetTimer(_PollPreTyped, 0)
        try g_ih.Stop()
        g_ih := 0
        DismissNotification()
        DebugLog("ViewWithMonitor label=" label " dialog_not_found")
        ShowDualNotifications("JBS dialog not found")
        return
    }
    SetTimer(_PollPreTyped, 0)
    DebugLog("ViewWithMonitor label=" label " dialog_found hook_reason=" g_ih.EndReason)
    SetWinDelay -1
    WinActivate "Select Background"
    g_ih.Wait()
    key := (g_ih.EndReason = "EndKey") ? StrLower(g_ih.EndKey) : ""
    g_ih := 0
    DismissNotification()
    DebugLog("ViewWithMonitor label=" label " key=" key)
    if key != "a" && key != "d" {
        ShowDualNotifications("JBS abort")
        return
    }
    WinActivate "Select Background"
    SendEvent (key = "a") ? "{Tab}{Tab}{Right}{Left}{Enter}" : "{Tab}{Tab}{Right}{Enter}"
    ShowDualNotifications("JBS " label " " (key = "a" ? "left" : "right"))
}

; Win+V → first chord → action
;   a  view prev    (then a/d for monitor)
;   s  view cur     (then a/d for monitor)
;   d  next pic
;   c  clear bg
;   b  settings
#HotIf !WinActive("ahk_exe overwatch.exe")
#v:: {
    global JBS_PREV_KEY, JBS_CUR_KEY, JBS_NEXT_KEY, JBS_CLEAR_KEY, JBS_SETTINGS_KEY
    DebugLog("#v chord_start")
    ShowDualNotifications("a - view prev`ns - view cur`nd - next`nc - clear`nb - settings", CHORD_TIMEOUT * 1000)
    key := WaitKey(CHORD_TIMEOUT)
    DismissNotification()
    DebugLog("#v chord_key=" key)
    switch key {
        case "a": ViewWithMonitor(JBS_PREV_KEY, "prev")
        case "s": ViewWithMonitor(JBS_CUR_KEY, "cur")
        case "d":
            SendEvent JBS_NEXT_KEY
            ShowDualNotifications("JBS next")
        case "c":
            SendEvent JBS_CLEAR_KEY
            ShowDualNotifications("JBS clearing bg")
        case "b":
            SendEvent JBS_SETTINGS_KEY
            ShowDualNotifications("JBS settings")
        default:
            ShowDualNotifications("JBS abort")
    }
}
#HotIf WinActive("ahk_exe overwatch.exe")
#v:: ShowDualNotifications("win+v game-mode blocked")
#HotIf
