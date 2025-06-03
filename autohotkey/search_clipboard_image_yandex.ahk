 #Requires AutoHotkey v2.0

 ; -----------------------------------------------------------------------------
 ; Search Clipboard Image on Yandex (AutoHotkey v2.0)
 ; • Hotkey: Win+Y
 ; • Workflow:
 ;     – Copy an image to the clipboard (e.g., PrintScreen → select → Ctrl+C)
 ;     – Press Win+Y
 ;     – Opens Yandex Images and pastes the clipboard contents
 ; -----------------------------------------------------------------------------

 #y:: {
     Run "https://yandex.ru/images/"
     Sleep 2000
     ; Paste clipboard content
     Send "^v"
     Sleep 100
 }
