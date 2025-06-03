#Requires AutoHotkey v2.0

;------------------------------------------------------------------------------
; VSCode Toggle – Win + C
; • 1st press → hide every visible “Code.exe” window, store handles, alpha 240
; • 2nd press → restore all stored windows, activate the last, clear the list
; • Nothing running/hidden → launch the exe, then set alpha 240
; • Toast on both monitors for each action (“hidden”, “restored”, “launching”)
; Globals
;   – hiddenVS : Array of hidden HWNDs
;   – VsPath   : Full path to Code.exe (edit to suit)
; Requires AutoHotkey v2.0 (no v2.1-only features).
;------------------------------------------------------------------------------

global hiddenVS := []                          ; remembers hidden Code windows

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

#c:: {                                         ; toggle all VS-Code windows
    global hiddenVS
    path := "C:\Users\kycok\AppData\Local\Programs\Microsoft VS Code\Code.exe"

    ; 1) Are there any VISIBLE VS-Code windows right now?
    DetectHiddenWindows(false)                 ; ignore hidden ones
    visible := WinGetList("ahk_exe Code.exe")  ; array of hwnds

    if (visible.Length) {                      ; → hide them all
        hiddenVS := []                         ; reset list
        for hwnd in visible {
            WinHide(hwnd)
            WinSetTransparent(240, hwnd)
            hiddenVS.Push(hwnd)
        }
        ShowDualNotifications("Code windows hidden", "Code windows hidden", 2000)
        return
    }

    ; 2) None visible, but do we have windows stored?
    if (hiddenVS.Length) {                     ; → restore them all
        for hwnd in hiddenVS {
            if WinExist(hwnd)                  ; skip closed windows
            {
                WinShow(hwnd)
                WinSetTransparent(240, hwnd)
            }
        }
        ; activate the last window that still exists
        while (hiddenVS.Length) {
            last := hiddenVS.Pop()
            if WinExist(last) {
                WinActivate(last)
                break
            }
        }
        ShowDualNotifications("Code windows restored", "Code windows restored", 2000)
        return
    }

    ; 3) Nothing to restore and nothing running → launch VS Code
    Run path
    ShowDualNotifications("Code is launching", "Code is launching", 3000)
    WinWaitActive("ahk_exe Code.exe", , 5)
    Sleep 500
    WinSetTransparent(240, "ahk_exe Code.exe")
}
