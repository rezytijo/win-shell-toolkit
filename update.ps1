# update.ps1 -- Automated system update script (winget + Windows Update)
# 2026-03-10 -- v2.0.2: Graceful handling for uninstalled packages, --force pin, --disable-interactivity

function Update-System {
    # --- [0/3] Update Script via Git ---
    Write-Host "--- Updating Script from Repository ---" -ForegroundColor Cyan
    $repoPath = $PSScriptRoot
    if (Test-Path (Join-Path $repoPath ".git")) {
        Push-Location $repoPath
        if (Get-Command git -ErrorAction SilentlyContinue) {
            # Git pull requires no login for public repositories.
            # We redirect standard error so it doesn't pollute the console if the user is offline.
            $pullResult = git pull origin main 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Auto-update failed: $pullResult"
            } else {
                Write-Host "  [OK] Script is up to date." -ForegroundColor Green
            }
        } else {
            Write-Warning "  Git is not installed on this system. Skipping script auto-update."
        }
        Pop-Location
    } else {
        Write-Warning "  Folder is not a Git repository. Skipping script auto-update."
    }

    # --- Package exclusion list (managed via winget pin) ---
    $excludedPackages = @(
        'Parsec.Parsec',
        'Spotify.Spotify',
        'Tonec.InternetDownloadManager'
    )

    # --- [1/3] Ensure Pins Are Active ---
    Write-Host "--- Configuring Upgrade Exclusions (Winget Pin) ---" -ForegroundColor Cyan

    # Retrieve currently pinned packages once for comparison
    $pinnedOutput = winget pin list --accept-source-agreements 2>&1 | Out-String

    foreach ($packageId in $excludedPackages) {
        if ($pinnedOutput -match [regex]::Escape($packageId)) {
            Write-Host "  [Pinned] $packageId -- already excluded" -ForegroundColor DarkGray
        } else {
            Write-Host "  [Pinning] $packageId ..." -ForegroundColor Yellow
            $pinResult = winget pin add $packageId --force --accept-source-agreements 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] $packageId pinned successfully" -ForegroundColor Green
            } elseif ($pinResult -match 'No installed package found') {
                # Package not installed on this system -- no pin needed, winget won't upgrade it
                Write-Host "  [Skip] $packageId -- not installed, no pin needed" -ForegroundColor DarkGray
            } else {
                Write-Warning "  Failed to pin $packageId. Output: $($pinResult.Trim())"
            }
        }
    }

    # --- [2/3] Upgrade All (Respects Pins) ---
    Write-Host "`n--- Updating Apps (Winget Upgrade All) ---" -ForegroundColor Cyan
    winget upgrade --all --silent --include-unknown --accept-source-agreements --accept-package-agreements --disable-interactivity

    # --- [3/3] Windows Update (Requires Admin) ---
    Write-Host "`n--- Checking Windows Updates ---" -ForegroundColor Cyan
    if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
        Get-WindowsUpdate -Install -AcceptAll -AutoReboot
    } else {
        Write-Warning "Modul PSWindowsUpdate tidak ditemukan. Menggunakan native USOClient."
        UsoClient StartScan
        UsoClient StartDownload
        UsoClient StartInstall
    }
}

# If the script is executed directly (not dot-sourced), run the update function
if ($MyInvocation.InvocationName -ne '.') {
    Update-System
}