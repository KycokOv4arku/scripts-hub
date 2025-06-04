#Requires AutoHotkey v2.0

;------------------------------------------------------------------------------
; Obsidian Toggle – Win + A
;   When:
; • Nothing running/hidden → launch the exe, then set alpha 240
; • app not hidden - active or minimized → hide every visible “Obsidian.exe” window, store handles, alpha 240
; • 2nd press → restore all stored windows, activate the last, clear the list

; • Toast on both monitors for each action (“launching”, “hidden”, “restored”)
; Globals
;   – hiddenObsidian : Array of hidden HWNDs
;   – VsPath   : Full path to Obsidian.exe (edit to suit)
; Requires AutoHotkey v2.0 (no v2.1-only features).
;------------------------------------------------------------------------------

global hiddenObsidian := []                          ; remembers hidden Obsidian windows

;───────────────────────────────────────────────────────────────────────────────
ShowDualNotifications(leftMsg, rightMsg, duration := 2000) {
    LeftGui := Gui(, "Left"), RightGui := Gui(, "Right")
    for _, g in [LeftGui, RightGui] {
        g.Opt("+AlwaysOnTop -Caption +ToolWindow")
        g.SetFont("s18 w600", "Segoe UI")
        g.BackColor := "161616"
        g.Add("Text", "cdedede w240", (g = LeftGui) ? leftMsg : rightMsg)
    }
    LeftGui.Show("x-700 y522 NoActivate"), RightGui.Show("xCenter yCenter NoActivate")
    SetTimer () => (LeftGui.Destroy(), RightGui.Destroy()), -duration
}
;───────────────────────────────────────────────────────────────────────────────

#a:: {                                         ; toggle all Obsidian windows
    global hiddenObsidian
    path := "C:\Users\kycok\AppData\local\Programs\Obsidian\Obsidian.exe"

    ; 1) Are there any VISIBLE Obsidian windows right now?
    DetectHiddenWindows(false)                 ; ignore hidden ones
    visible := WinGetList("ahk_exe Obsidian.exe")  ; array of hwnds

    if (visible.Length) {                      ; → hide them all
        hiddenObsidian := []                         ; reset list
        for hwnd in visible {
            WinHide(hwnd)
            WinSetTransparent(240, hwnd)
            hiddenObsidian.Push(hwnd)
        }
        ShowDualNotifications("Obsidian windows hidden", "Obsidian windows hidden", 2000)
        return
    }

    ; 2) None visible, but do we have windows stored?
    if (hiddenObsidian.Length) {                     ; → restore them all
        for hwnd in hiddenObsidian {
            if WinExist(hwnd)                  ; skip closed windows
            {
                WinShow(hwnd)
                WinSetTransparent(240, hwnd)
            }
        }
        ; activate the last window that still exists
        while (hiddenObsidian.Length) {
            last := hiddenObsidian.Pop()
            if WinExist(last) {
                WinActivate(last)
                break
            }
        }
        ShowDualNotifications("Obsidian windows restored", "Obsidian windows restored", 2000)
        return
    }

    ; 3) Nothing to restore and nothing running → launch VS Obsidian
    Run path
    ShowDualNotifications("Obsidian is launching", "Obsidian is launching", 3000)
    WinWaitActive("ahk_exe Obsidian.exe", , 5)
    Sleep 500
    WinSetTransparent(240, "ahk_exe Obsidian.exe")
}
