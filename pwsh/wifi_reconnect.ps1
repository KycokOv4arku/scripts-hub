# wifi_reconnect.ps1
# Reconnects Wi-Fi at logon if auto-connect fails to trigger after reboot
# Exponential backoff: delay = 2^attempt, capped at 10min
#
# --- Register scheduled task (run once) ---
# schtasks /create /tn "Wifi_Reconnect" /tr "C:\Users\kycok\AppData\Local\Microsoft\WindowsApps\wt.exe -w new nt pwsh -nol -nop -File `"D:\YandexDisk\gd\cs\scripts-hub\pwsh\wifi_reconnect.ps1`"" /sc onlogon /rl highest /f
#
# --- Verify ---
# schtasks /query /tn "Wifi_Reconnect" /fo csv /v
#
# --- Test manually ---
# schtasks /run /tn "Wifi_Reconnect"
#
# --- Log ---
# Get-Content "D:\YandexDisk\gd\cs\scripts-hub\pwsh\wifi_reconnect.log" -Tail 20
# --- SSID ---
# Deliberately not hardcoded: this repo is public, and SSIDs are geolocatable
# through public wardriving databases. Set it once per machine:
#   [Environment]::SetEnvironmentVariable("WIFI_SSID", "<your-ssid>", "User")
# or pass -Ssid "<your-ssid>" (append it to the schtasks /tr line above).
param([string]$Ssid = $env:WIFI_SSID)

$adapterName = "Wi-Fi"
$maxAttempts = 10
$maxDelaySeconds = 600
$logFile = "D:\YandexDisk\gd\cs\scripts-hub\pwsh\wifi_reconnect.log"

function Write-Log {
    param([string]$msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $msg" | Out-File -FilePath $logFile -Append -Encoding utf8
}

if (-not $Ssid) {
    Write-Log "No SSID configured - set `$env:WIFI_SSID or pass -Ssid. Aborting."
    exit 1
}

Write-Log "--- Reconnect attempt started ---"

for ($i = 1; $i -le $maxAttempts; $i++) {
    $wlanState = (netsh wlan show interfaces | Select-String "State").ToString()

    if ($wlanState -match ":\s*connected\s*$") {
        Write-Log "Already connected on attempt $i. Exiting."
        exit 0
    }

    Write-Log "Attempt $i - state: $wlanState. Trying netsh wlan connect."
    netsh wlan connect name="$Ssid"

    $delay = [Math]::Min([Math]::Pow(2, $i), $maxDelaySeconds)
    Write-Log "Waiting $delay seconds before next check."
    Start-Sleep -Seconds $delay
}

$finalState = (netsh wlan show interfaces | Select-String "State").ToString()
Write-Log "Final state after $maxAttempts attempts: $finalState"