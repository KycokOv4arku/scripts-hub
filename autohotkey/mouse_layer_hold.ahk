#Requires AutoHotkey v2.0

; === SPEED SETTINGS - ADJUST THESE ===
startSpeed := 5          ; Speed when you first press (lower = more precise)
accelerationRate := 2    ; How fast it speeds up (higher = faster acceleration)
maxSpeed := 100          ; Maximum speed cap
sleepTime := 22          ; Milliseconds between movements (lower = smoother)

; Movement functions
CapsLock & Up:: {
    speed := startSpeed
    while GetKeyState("CapsLock", "P") && GetKeyState("Up", "P") {
        deltaX := 0, deltaY := -speed
        if GetKeyState("Left", "P")
            deltaX := -speed
        if GetKeyState("Right", "P")
            deltaX := speed

        MouseMove(deltaX, deltaY, 0, "R")
        Sleep(sleepTime)

        speed += accelerationRate
        if (speed > maxSpeed)
            speed := maxSpeed
    }
}

CapsLock & Down:: {
    speed := startSpeed
    while GetKeyState("CapsLock", "P") && GetKeyState("Down", "P") {
        deltaX := 0, deltaY := speed
        if GetKeyState("Left", "P")
            deltaX := -speed
        if GetKeyState("Right", "P")
            deltaX := speed

        MouseMove(deltaX, deltaY, 0, "R")
        Sleep(sleepTime)

        speed += accelerationRate
        if (speed > maxSpeed)
            speed := maxSpeed
    }
}

CapsLock & Left:: {
    speed := startSpeed
    while GetKeyState("CapsLock", "P") && GetKeyState("Left", "P") {
        deltaX := -speed, deltaY := 0
        if GetKeyState("Up", "P")
            deltaY := -speed
        if GetKeyState("Down", "P")
            deltaY := speed

        MouseMove(deltaX, deltaY, 0, "R")
        Sleep(sleepTime)

        speed += accelerationRate
        if (speed > maxSpeed)
            speed := maxSpeed
    }
}

CapsLock & Right:: {
    speed := startSpeed
    while GetKeyState("CapsLock", "P") && GetKeyState("Right", "P") {
        deltaX := speed, deltaY := 0
        if GetKeyState("Up", "P")
            deltaY := -speed
        if GetKeyState("Down", "P")
            deltaY := speed

        MouseMove(deltaX, deltaY, 0, "R")
        Sleep(sleepTime)

        speed += accelerationRate
        if (speed > maxSpeed)
            speed := maxSpeed
    }
}

; Clicks
CapsLock & Space:: Click()
CapsLock & `:: Click("Right")