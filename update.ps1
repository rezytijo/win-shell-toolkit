# update.ps1 -- Automated system update script (winget + Windows Update + Dev environments)
# 2026-04-05 -- v2.0.5: Added global error handling

param(
    [Parameter(Position = 0)]
    [ValidateSet("apps", "windows", "npm", "python", "dev", "all")]
    [string]$Target = "apps"
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'lib\scrcpy-install.ps1')
. (Join-Path $ScriptDir 'lib\platform-tools-install.ps1')


function ConvertTo-CleanVersion {
    param([AllowNull()][string]$Version)
    if ([string]::IsNullOrWhiteSpace($Version)) { return $null }
    $clean = ($Version.Trim() -replace '^[vV]', '' -replace '[^0-9\.].*$', '')
    try { return [version]$clean } catch { return $null }
}

function Find-ToolExecutable {
    param([Parameter(Mandatory = $true)][string]$ExecutableName)

    $cmd = Get-Command $ExecutableName -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }

    $roots = @(
        $ScriptDir,
        (Join-Path $ScriptDir 'bin'),
        (Join-Path $ScriptDir 'tools'),
        (Join-Path $ScriptDir 'runtime'),
        (Join-Path $ScriptDir 'runtimes'),
        (Join-Path $env:ProgramFiles 'platform-tools'),
        (Join-Path $env:ProgramFiles 'scrcpy'),
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools')
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($root in $roots) {
        $found = Get-ChildItem -Path $root -Filter $ExecutableName -File -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Get-InstalledAdbVersion {
    $adbPath = Find-ToolExecutable -ExecutableName 'adb.exe'
    if (-not $adbPath) { $adbPath = Find-ToolExecutable -ExecutableName 'adb' }
    if (-not $adbPath) { return $null }

    try {
        $output = & $adbPath version 2>&1 | Out-String
        if ($output -match 'Version\s+([0-9]+(?:\.[0-9]+){1,3})') {
            return [pscustomobject]@{ Version = $matches[1]; Path = $adbPath }
        }
    } catch {}
    return $null
}

function Get-LatestPlatformToolsVersion {
    $metadataUrl = 'https://dl.google.com/android/repository/repository2-1.xml'
    try {
        $response = Invoke-WebRequest -Uri $metadataUrl -UseBasicParsing
        [xml]$xml = $response.Content

        $pkg = $xml.SelectSingleNode("//*[local-name()='remotePackage' and @path='platform-tools']")
        if (-not $pkg) { return $null }

        $revision = $pkg.SelectSingleNode("*[local-name()='revision']")
        if (-not $revision) { return $null }

        $majorNode = $revision.SelectSingleNode("*[local-name()='major']")
        $minorNode = $revision.SelectSingleNode("*[local-name()='minor']")
        $microNode = $revision.SelectSingleNode("*[local-name()='micro']")
        if (-not $majorNode) { return $null }

        $major = [int]$majorNode.InnerText
        $minor = if ($minorNode) { [int]$minorNode.InnerText } else { 0 }
        $micro = if ($microNode) { [int]$microNode.InnerText } else { 0 }
        return "$major.$minor.$micro"
    } catch {
        Write-Warning "  Gagal mengambil metadata platform-tools terbaru: $($_.Exception.Message)"
        return $null
    }
}

function Get-InstalledScrcpyVersion {
    $scrcpyPath = Find-ToolExecutable -ExecutableName 'scrcpy.exe'
    if (-not $scrcpyPath) { $scrcpyPath = Find-ToolExecutable -ExecutableName 'scrcpy' }
    if (-not $scrcpyPath) { return $null }

    try {
        $output = & $scrcpyPath --version 2>&1 | Out-String
        if ($output -match 'scrcpy\s+([0-9]+(?:\.[0-9]+){1,3})') {
            return [pscustomobject]@{ Version = $matches[1]; Path = $scrcpyPath }
        }
    } catch {}

    $marker = Join-Path (Join-Path $env:ProgramFiles 'scrcpy') '.scrcpy-version'
    if (Test-Path $marker) {
        try {
            $v = (Get-Content $marker -ErrorAction Stop | Select-Object -First 1).Trim()
            if ($v) { return [pscustomobject]@{ Version = $v; Path = $scrcpyPath } }
        } catch {}
    }
    return $null
}

function Get-LatestScrcpyVersion {
    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/Genymobile/scrcpy/releases/latest' -UseBasicParsing -Headers @{ 'User-Agent' = 'win-shell-toolkit-update' }
        if ($release -and $release.tag_name) { return ($release.tag_name -replace '^[vV]', '') }
    } catch {
        Write-Warning "  Gagal mengambil versi scrcpy terbaru dari GitHub: $($_.Exception.Message)"
    }
    return $null
}

function Test-ShouldUpdateRuntime {
    param([AllowNull()][string]$InstalledVersion, [AllowNull()][string]$LatestVersion)

    if ([string]::IsNullOrWhiteSpace($LatestVersion)) {
        # Fail-safe: kalau latest tidak bisa dicek, jangan download/install berulang-ulang.
        return $false
    }
    if ([string]::IsNullOrWhiteSpace($InstalledVersion)) { return $true }

    $installed = ConvertTo-CleanVersion $InstalledVersion
    $latest = ConvertTo-CleanVersion $LatestVersion
    if ($installed -and $latest) { return ($installed -lt $latest) }

    return ($InstalledVersion.Trim() -ne $LatestVersion.Trim())
}

function Update-PlatformToolsIfNeeded {
    Write-Host "  [*] Checking Android platform-tools / ADB version..." -ForegroundColor Yellow

    $installed = Get-InstalledAdbVersion
    $latestVersion = Get-LatestPlatformToolsVersion
    $installedVersion = if ($installed) { [string]$installed.Version } else { $null }

    if ($installedVersion) {
        Write-Host "  [Info] Installed ADB: $installedVersion ($($installed.Path))" -ForegroundColor DarkGray
    } else {
        Write-Host "  [Info] ADB belum ditemukan." -ForegroundColor DarkGray
    }
    if ($latestVersion) { Write-Host "  [Info] Latest platform-tools: $latestVersion" -ForegroundColor DarkGray }

    if (Test-ShouldUpdateRuntime -InstalledVersion $installedVersion -LatestVersion $latestVersion) {
        Write-Host "  [+] Updating Android platform-tools / ADB..." -ForegroundColor Cyan
        $result = Install-PlatformToolsRuntime
        if ($result -and ($result.PSObject.Properties.Name -contains 'InstallRoot')) {
            Write-Host "  [OK] platform-tools installed to $($result.InstallRoot)" -ForegroundColor Green
        } else {
            Write-Host "  [OK] platform-tools install/update selesai." -ForegroundColor Green
        }
    } else {
        Write-Host "  [OK] ADB/platform-tools sudah up-to-date atau latest version tidak bisa dicek. Skip download." -ForegroundColor Green
    }
}


function Install-ScrcpyRuntimeSafe {
    param(
        [Parameter(Mandatory = $true)][string]$LatestVersion
    )

    $installRoot = Join-Path $env:ProgramFiles 'scrcpy'
    $tempRoot = Join-Path $env:TEMP ('scrcpy-update-' + [guid]::NewGuid().ToString('N'))
    $zipPath = Join-Path $tempRoot 'scrcpy.zip'
    $extractRoot = Join-Path $tempRoot 'extract'

    try {
        New-Item -ItemType Directory -Path $tempRoot, $extractRoot -Force | Out-Null

        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/Genymobile/scrcpy/releases/latest' -UseBasicParsing -Headers @{ 'User-Agent' = 'win-shell-toolkit-update' }
        $asset = $release.assets | Where-Object { $_.name -match 'win64.*\.zip$' } | Select-Object -First 1
        if (-not $asset) { throw 'Asset scrcpy win64 zip tidak ditemukan pada release terbaru.' }

        Write-Host "  [Downloading] $($asset.name) from official scrcpy release..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force

        $sourceDir = Get-ChildItem -Path $extractRoot -Directory -Recurse -Force |
            Where-Object { Test-Path (Join-Path $_.FullName 'scrcpy.exe') } |
            Select-Object -First 1
        if (-not $sourceDir) { throw 'scrcpy.exe tidak ditemukan di hasil ekstraksi.' }

        # Kurangi risiko file terkunci saat replace.
        foreach ($procName in @('scrcpy', 'adb')) {
            Get-Process -Name $procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }

        New-Item -ItemType Directory -Path $installRoot -Force | Out-Null

        # adb.exe sering terkunci / butuh admin saat berada di Program Files.
        # scrcpy tetap bisa memakai ADB dari platform-tools yang sudah dikelola terpisah.
        $robocopyArgs = @(
            $sourceDir.FullName,
            $installRoot,
            '/E',
            '/R:1',
            '/W:1',
            '/NFL',
            '/NDL',
            '/NJH',
            '/NJS',
            '/XF',
            'adb.exe'
        )
        & robocopy @robocopyArgs | Out-Null
        $rc = $LASTEXITCODE
        if ($rc -gt 7) { throw "Robocopy gagal dengan exit code $rc" }

        # Jika adb.exe belum ada dan bisa dicopy, copy sekali. Kalau gagal, abaikan karena platform-tools punya adb.
        $srcAdb = Join-Path $sourceDir.FullName 'adb.exe'
        $dstAdb = Join-Path $installRoot 'adb.exe'
        if ((Test-Path $srcAdb) -and -not (Test-Path $dstAdb)) {
            Copy-Item -Path $srcAdb -Destination $dstAdb -Force -ErrorAction SilentlyContinue
        }

        Set-Content -Path (Join-Path $installRoot '.scrcpy-version') -Value $LatestVersion -Encoding ASCII -Force

        return [pscustomobject]@{
            Version = $LatestVersion
            InstallRoot = $installRoot
        }
    } finally {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Update-ScrcpyIfNeeded {
    Write-Host "  [*] Checking scrcpy version..." -ForegroundColor Yellow

    $installed = Get-InstalledScrcpyVersion
    $latestVersion = Get-LatestScrcpyVersion
    $installedVersion = if ($installed) { [string]$installed.Version } else { $null }

    if ($installedVersion) {
        Write-Host "  [Info] Installed scrcpy: $installedVersion ($($installed.Path))" -ForegroundColor DarkGray
    } else {
        Write-Host "  [Info] scrcpy belum ditemukan." -ForegroundColor DarkGray
    }
    if ($latestVersion) { Write-Host "  [Info] Latest scrcpy: $latestVersion" -ForegroundColor DarkGray }

    if (Test-ShouldUpdateRuntime -InstalledVersion $installedVersion -LatestVersion $latestVersion) {
        Write-Host "  [+] Updating scrcpy runtime..." -ForegroundColor Cyan
        $result = Install-ScrcpyRuntimeSafe -LatestVersion $latestVersion
        if ($result -and ($result.PSObject.Properties.Name -contains 'Version') -and ($result.PSObject.Properties.Name -contains 'InstallRoot')) {
            Write-Host "  [OK] scrcpy $($result.Version) installed to $($result.InstallRoot)" -ForegroundColor Green
        } else {
            Write-Host "  [OK] scrcpy install/update selesai." -ForegroundColor Green
        }
    } else {
        Write-Host "  [OK] scrcpy sudah up-to-date atau latest version tidak bisa dicek. Skip download." -ForegroundColor Green
    }
}

function Update-System {
    param(
        [string]$Target = "apps"
    )

    # --- [0/4] Update Script via Git ---
    # Disabled by default so local fixes are not overwritten before runtime checks.
    # Run with: $env:UPDATE_PS1_SELF_UPDATE = "1"; .\update.ps1 apps
    if ($env:UPDATE_PS1_SELF_UPDATE -ne "1") {
        Write-Host "--- Skipping Script Self-Update (set UPDATE_PS1_SELF_UPDATE=1 to enable) ---" -ForegroundColor DarkGray
    } else {
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

        try {
            Update-PlatformToolsIfNeeded
        } catch {
            Write-Warning "  Failed to check/update platform-tools: $($_.Exception.Message)"
        }

        try {
            Update-ScrcpyIfNeeded
        } catch {
            Write-Warning "  Failed to check/update scrcpy runtime: $($_.Exception.Message)"
        }

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

            Write-Host "  [*] Checking for outdated global npm packages..." -ForegroundColor Yellow
            $npmOutdatedStr = npm outdated -g --json 2>&1 | Out-String
            try {
                $outdatedNpmJson = $npmOutdatedStr | ConvertFrom-Json
            } catch {
                $outdatedNpmJson = $null
            }

            if ($outdatedNpmJson) {
                foreach ($pkg in $outdatedNpmJson.psobject.properties) {
                    $name = $pkg.Name
                    $info = $pkg.Value
                    Write-Host "  [+] Upgrading NPM package: $name ($($info.current) -> $($info.latest))" -ForegroundColor Cyan
                    npm install -g "$name@latest" | Out-Null
                }
                Write-Host "  [OK] Outdated NPM packages have been upgraded." -ForegroundColor Green
            } else {
                Write-Host "  [OK] All global NPM packages are already up-to-date." -ForegroundColor Green
            }
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
            & $pyCmd -m pip install --upgrade pip | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $v = (& $pyCmd --version).Trim()
                Write-Host "  [OK] $v pip upgraded." -ForegroundColor Green
            }

            Write-Host "  [*] Checking for outdated global PIP packages..." -ForegroundColor Yellow
            $pipOutdatedStr = & $pyCmd -m pip list --outdated --format=json 2>&1 | Out-String
            try {
                $outdatedPip = $pipOutdatedStr | ConvertFrom-Json
            } catch {
                $outdatedPip = $null
            }

            if ($outdatedPip) {
                foreach ($pkg in $outdatedPip) {
                    Write-Host "  [+] Upgrading PIP package: $($pkg.name) ($($pkg.version) -> $($pkg.latest_version))" -ForegroundColor Cyan
                    & $pyCmd -m pip install --upgrade $($pkg.name) | Out-Null
                }
                Write-Host "  [OK] Outdated PIP packages have been upgraded." -ForegroundColor Green
            } else {
                Write-Host "  [OK] All global PIP packages are already up-to-date." -ForegroundColor Green
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
