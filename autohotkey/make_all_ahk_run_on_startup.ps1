ls *.ahk -r | foreach { 
    $linkPath = "C:\Users\kycok\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\$($_.Name)"
    if (!(Test-Path $linkPath)) {
        ni -ItemType SymbolicLink -Path $linkPath -Target $_.FullName
    }
    else {
        Write-Host "$($_.Name) skipped - already exists"
    }
}
pause