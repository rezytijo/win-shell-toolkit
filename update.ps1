# update.ps1 -- Automated system update script (winget + Windows Update)
# 2026-03-10 -- v2.0.2: Graceful handling for uninstalled packages, --force pin, --disable-interactivity

function Update-System {
    # --- [0/3] Update Script via Git ---
    Write-Host "--- Updating Script from Repository ---" -ForegroundColor Cyan
    $repoPath = $PSScriptRoot
    $repoUrl = "https://github.com/rezytijo/win-shell-toolkit.git"

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Push-Location $repoPath
        
        # 1. Jika belum menjadi Git repo, setup dan paksa ambil semuanya (clone in place)
        if (-not (Test-Path (Join-Path $repoPath ".git"))) {
            Write-Host "  [Init] Folder bukan Git repository. Mengunduh codebase..." -ForegroundColor Yellow
            git init | Out-Null
            git remote add origin $repoUrl | Out-Null
            git fetch origin | Out-Null
            git reset --hard origin/main | Out-Null
            git branch -M main | Out-Null
        } else {
            # Jika sudah git repo, pastikan remote URL tetap benar
            $currentRemote = git config --get remote.origin.url
            if ($currentRemote -ne $repoUrl) {
                git remote set-url origin $repoUrl | Out-Null
            }
        }

        # 2. Lakukan pull untuk update codebase terbaru
        $pullResult = git pull origin main 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  Auto-update script gagal: $pullResult"
        } else {
            Write-Host "  [OK] Script codebase berhasil di-update." -ForegroundColor Green
        }
        
        Pop-Location
    } else {
        Write-Warning "  Git tidak terinstall pada sistem ini. Membutuhkan Git untuk mengunduh versi script terbaru."
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