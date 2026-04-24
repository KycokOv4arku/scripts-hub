# scripts-hub project context

## Repo layout

```
scripts-hub/
  TODO.md           ← single backlog for the whole repo (root, not per-subdir)
  autohotkey/       ← PRIMARY — most active work happens here
    make_all_ahk_run_on_startup.ps1
    toggle_apps.ahk, yandex_music_remap.ahk, ...
  python/, pwsh/, browser-extensions/, regedit/, tempermonkey/
                    ← sparse, mostly stale — occasional one-offs
```

## AHK conventions

- AHK v2 only (`#Requires AutoHotkey v2.0`)
- `#SingleInstance Force` always
- Every script must set a tray icon + tooltip:
  ```ahk
  TraySetIcon("D:\YandexDisk\images\Icons\<icon>.ico")
  A_IconTip := "<script name> — <one-line description>"
  ```
- For game/fullscreen input: use `SendEvent("{key down}") / SendEvent("{key up}")`, not bare `Send()`
- For layout-insensitive hotkeys (works in EN + RU): use scan codes (`SC013` = R/к key), not letter literals
- Window matching by exe name (`ahk_exe`), never by PID

## AHK notification popup pattern

Dual-monitor OSD (same code in `yandex_music_remap.ahk`, `jbs_view.ahk`, `stardew_y_remap.ahk`). Copy verbatim — do not invent alternatives:

```ahk
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
```

Call as `ShowDualNotifications("message", durationMs)`. Default duration 1000ms.

## AHK debug mode pattern

Every non-trivial script should support a `DEBUG_MODE` toggle at the top. Copy verbatim:

```ahk
DEBUG_MODE := false
if DEBUG_MODE {
    try TraySetIcon("D:\YandexDisk\images\Icons\autohotkey-red.ico")
    try FileDelete(A_ScriptDir "\debug.log")
} else
    A_IconHidden := true
A_IconTip := "<script name> — <one-line description>"

DebugLog(msg) {
    global DEBUG_MODE
    if !DEBUG_MODE
        return
    try FileAppend(FormatTime(, "HH:mm:ss") " " msg "`n", A_ScriptDir "\debug.log")
}
```

- Red tray icon = debug build; hidden tray = production
- Log file is cleared on each debug start so it doesn't accumulate across runs
- Call `DebugLog("key=value ...")` at state transitions (window pos, monitor, visibility changes)
- `*.log` is in `.gitignore` — safe to leave `DebugLog()` calls in committed code

## Shared icon library

All icons are at `D:\YandexDisk\images\Icons\` — this is outside the repo (Yandex Disk personal storage, not version-controlled). Reference by absolute path in scripts. Notable ones:
- `autohotkey.ico`, `autohotkey-red.ico` — for debug vs normal mode pattern
- `joystick2.ico` — game-related scripts
- Many others: robot, microchip, beehive, tv, musical-note, etc.

## AHK dev workflow

1. At session start: set `DEBUG_MODE := true`, restart the script.
2. After each change that's ready to test: restart the script so `#SingleInstance Force` kills the old instance.
   Restart command: `Start-Process "autohotkey/<script>.ahk"` (relative path works — don't cd, working dir is already repo root)
3. Before committing: set `DEBUG_MODE := false`, restart once more — user keeps using the production build.

Never commit with `DEBUG_MODE := true`.

## Startup

`autohotkey/make_all_ahk_run_on_startup.ps1` registers AHK scripts to run at login via Task Scheduler.
Run with: `pwsh autohotkey/make_all_ahk_run_on_startup.ps1`
When adding a new AHK script that should persist, add it there.

## Backlog

`TODO.md` (repo root) — single running log for bugs, workarounds, hunting notes, and todos. Append there; don't create separate files.
