# update.ps1 -- Automated system update script (winget + Windows Update + Dev environments)
# 2026-04-05 -- v2.0.5: Added global error handling

param(
    [Parameter(Position = 0)]
    [ValidateSet("apps", "windows", "npm", "python", "dev", "all")]
    [string]$Target = "apps"
)

$ErrorActionPreference = 'Stop'

function Update-System {
    param(
        [string]$Target = "apps"
    )

    # --- [0/4] Update Script via Git ---
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

    # --- [1/4] Winget App Upgrade (apps or all) ---
    if ($Target -eq "apps" -or $Target -eq "all") {
        # --- Package exclusion list (managed via winget pin) ---
        $excludedPackages = @(
            'Parsec.Parsec',
            'Spotify.Spotify',
            'Tonec.InternetDownloadManager'
        )

        Write-Host "`n--- Updating Apps (Winget Upgrade All) ---" -ForegroundColor Cyan

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

        # Upgrade All (Respects Pins)
        winget upgrade --all --silent --include-unknown --accept-source-agreements --accept-package-agreements --disable-interactivity
    }

    # --- [2/4] NPM Environment Update (npm, dev, or all) ---
    if ($Target -eq "npm" -or $Target -eq "dev" -or $Target -eq "all") {
        Write-Host "`n--- Updating NPM Core and Environment ---" -ForegroundColor Cyan
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            Write-Host "  [*] Updating npm binary to latest version..." -ForegroundColor Yellow
            npm install -g npm | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $v = (& npm -v).Trim()
                Write-Host "  [OK] npm updated to v$v" -ForegroundColor Green
            }

            Write-Host "  [*] Updating all global npm packages..." -ForegroundColor Yellow
            npm update -g
            Write-Host "  [OK] Global npm environment up-to-date." -ForegroundColor Green
        } else {
            Write-Host "  [Skip] NPM is not installed on this system." -ForegroundColor DarkGray
        }
    }

    # --- [3/4] Python Environment Update (python, dev, or all) ---
    if ($Target -eq "python" -or $Target -eq "dev" -or $Target -eq "all") {
        Write-Host "`n--- Updating Python Environment ---" -ForegroundColor Cyan
        $pyCmd = if (Get-Command python -ErrorAction SilentlyContinue) { "python" } elseif (Get-Command py -ErrorAction SilentlyContinue) { "py" } else { $null }

        if ($pyCmd) {
            Write-Host "  [*] Upgrading pip for $pyCmd environment..." -ForegroundColor Yellow
            & $pyCmd -m pip install --upgrade pip
            if ($LASTEXITCODE -eq 0) {
                $v = (& $pyCmd --version).Trim()
                Write-Host "  [OK] $v pip upgraded." -ForegroundColor Green
            }
        } else {
            Write-Host "  [Skip] Python is not installed on this system." -ForegroundColor DarkGray
        }
    }

    # --- [4/4] Windows Update (Only if requested: windows or all) ---
    if ($Target -eq "windows" -or $Target -eq "all") {
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
}

# If the script is executed directly (not dot-sourced), run the update function
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Update-System -Target $Target
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}