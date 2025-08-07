#Requires AutoHotkey v2.0

; Hold CapsLock + arrow keys for mouse movement
CapsLock & Up:: MouseMove(0, -10, 0, "R")
CapsLock & Down:: MouseMove(0, 10, 0, "R")
CapsLock & Left:: MouseMove(-10, 0, 0, "R")
CapsLock & Right:: MouseMove(10, 0, 0, "R")

; Optional: Add clicks while in mouse mode
CapsLock & Space:: Click()
CapsLock & Enter:: Click("Right")