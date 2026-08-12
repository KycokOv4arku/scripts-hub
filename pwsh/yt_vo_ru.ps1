<#
.SYNOPSIS
    Download a YouTube video and overlay a Russian voice-over (Yandex VOT) with
    auto-ducked original audio. Saves the result to ~\Downloads.

.DESCRIPTION
    Pipeline:
      1. yt-dlp pulls best video+audio, remuxes to mp4.
      2. vot-cli-live fetches the Yandex Russian voice-over track URL.
      3. curl downloads the voice-over.
      4. ffmpeg sidechain-compresses the original audio against the voice-over
         (auto-ducking) and mixes them; progress is rendered as an inline
         ASCII bar by parsing ffmpeg's `-progress pipe:1` output.

    Requires on PATH: yt-dlp, ffmpeg, ffprobe, curl, npx (Node).
    Honors $env:HTTPS_PROXY / $env:HTTP_PROXY (yt-dlp + npx pick them up).

.PARAMETER Url
    YouTube video URL.

.EXAMPLE
    # Win+R (via yt_vo_ru.bat shim on PATH):
    yt_vo_ru https://www.youtube.com/watch?v=XXXXXXXXXXX

.EXAMPLE
    # Direct:
    pwsh -ExecutionPolicy Bypass -File yt_vo_ru.ps1 "https://youtu.be/XXXXXXXXXXX"
#>
param([string]$Url)
# extract video ID from any youtube URL or bare ID
if ($Url -match '(?:v=|youtu\.be/)([a-zA-Z0-9_-]{11})') {
    $Url = "https://www.youtube.com/watch?v=$($matches[1])"
}
elseif ($Url -match '^[a-zA-Z0-9_-]{11}$') {
    $Url = "https://www.youtube.com/watch?v=$Url"
}



Write-Host "[debug] HTTPS_PROXY=[$env:HTTPS_PROXY]" -ForegroundColor DarkGray
Write-Host "[debug] HTTP_PROXY=[$env:HTTP_PROXY]"  -ForegroundColor DarkGray

# 1. Setup Environment
$DownloadsDir = "C:\Users\kycok\Downloads"
Set-Location -Path $DownloadsDir
$TempDir = Join-Path $DownloadsDir "yt_vo_temp"

# Clear/Create temp dir
if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

Write-Host "🎬 Starting Process for: $Url" -ForegroundColor Cyan

try {
    # 2. Get the proper Filename (Video Title)
    Write-Host "🔍 Fetching video title..." -ForegroundColor Yellow
    # We force .mp4 extension for the final name to match ffmpeg output
    $FinalFileName = yt-dlp --get-filename -o "%(title)s.mp4" --no-warnings "$Url"
    # Sanitize filename just in case (remove illegal chars)
    $FinalFileName = $FinalFileName -replace '[\\/*?:"<>|]', "_"

    # 3. Download Video (High Quality)
    Write-Host "📥 Downloading Video..." -ForegroundColor Green
    $VideoFile = Join-Path $TempDir "video_source.mp4"
    # Download best video+audio, merge to mp4 to ensure compatibility
    yt-dlp -f "bv*+ba/b" --merge-output-format mp4 -o $VideoFile --no-warnings "$Url"
    if ($LASTEXITCODE -ne 0) { throw "yt-dlp video download failed (exit $LASTEXITCODE)" }

    # 4. Get Audio Link & Download
    Write-Host "🎤 Fetching Lively Voice URL..." -ForegroundColor Magenta
    # We use npx to get the URL (--quiet outputs only the link)
    $AudioUrl = npx -y vot-cli-live "$Url" --voice-style=live --quiet
    $AudioUrl = $AudioUrl.Trim()

    if ($AudioUrl -notmatch "^http") {
        throw "Failed to get Audio URL. VOT-CLI output: $AudioUrl"
    }

    Write-Host "📥 Downloading Translation Audio..." -ForegroundColor Magenta
    $AudioFile = Join-Path $TempDir "audio_source.mp3"
    # Use curl because it's faster/easier than PS Invoke-WebRequest for large files
    curl.exe -L -o $AudioFile "$AudioUrl"

    # 5. Merge with FFmpeg (Auto-Ducking)
    Write-Host "🎛️  Mixing Audio (Auto-Ducking)..." -ForegroundColor Cyan
    $OutputFile = Join-Path $DownloadsDir $FinalFileName

    # Your specific filter chain
    $Filter = "[1:a]aresample=48000,volume=1.5,asplit=2[trigger][voice];[0:a][trigger]sidechaincompress=threshold=0.01:ratio=20:attack=5:release=700[ducked_bg];[ducked_bg][voice]amix=inputs=2:duration=first[out]"

    $DurationSec = [double](& ffprobe -v error -show_entries format=duration -of default=nokey=1:noprint_wrappers=1 $VideoFile)

    & ffmpeg -y -v error -nostats -stats_period 0.5 -progress pipe:1 -i $VideoFile -i $AudioFile -filter_complex $Filter -map 0:v -map "[out]" -c:v copy -c:a aac -shortest "$OutputFile" | ForEach-Object {
        if ($_ -match '^out_time=(\d+):(\d+):([\d.]+)') {
            $cur = [int]$matches[1] * 3600 + [int]$matches[2] * 60 + [double]$matches[3]
            $pct = if ($DurationSec -gt 0) { [math]::Min(100, $cur / $DurationSec * 100) } else { 0 }
            $w = 30; $f = [int]($pct / 100 * $w)
            Write-Host ("`r  [{0}{1}] {2,5:N1}% {3,6:N1}/{4:N1}s" -f ('#' * $f), ('-' * ($w - $f)), $pct, $cur, $DurationSec) -NoNewline
        }
    }
    Write-Host ""

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Done! Saved to: $OutputFile" -ForegroundColor Green
        # Cleanup
        Remove-Item $TempDir -Recurse -Force
        # Open the folder
        Start-Process explorer.exe -ArgumentList "/select,`"$OutputFile`""
    }
    else {
        Write-Host "❌ FFmpeg failed." -ForegroundColor Red
        Pause
    }

}
catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    Pause
}