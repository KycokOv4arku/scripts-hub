param([string]$Url)

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
    yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" -o $VideoFile --no-warnings "$Url"

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

    ffmpeg -y -v error -stats -i $VideoFile -i $AudioFile -filter_complex $Filter -map 0:v -map "[out]" -c:v copy -c:a aac -shortest "$OutputFile"

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