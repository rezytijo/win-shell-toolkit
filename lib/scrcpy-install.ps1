Set-StrictMode -Version Latest

function Get-ScrcpyArchitectureInfo {
    $is64Bit = [Environment]::Is64BitOperatingSystem
    $programFilesRoot = if ($is64Bit) { $env:ProgramFiles } else { ${env:ProgramFiles(x86)} }
    if (-not $programFilesRoot) {
        $programFilesRoot = $env:ProgramFiles
    }

    return [PSCustomObject]@{
        Is64Bit          = $is64Bit
        AssetNamePattern = if ($is64Bit) { 'scrcpy-win64-' } else { 'scrcpy-win32-' }
        InstallRoot      = Join-Path $programFilesRoot 'scrcpy'
    }
}

function Get-ScrcpyInstallRoot {
    if ($env:CUSTOMSCRIPTS_SCRCPY_INSTALL_ROOT) {
        return $env:CUSTOMSCRIPTS_SCRCPY_INSTALL_ROOT
    }

    return (Get-ScrcpyArchitectureInfo).InstallRoot
}

function Get-ScrcpyExecutablePath {
    param(
        [switch]$AllowMissing
    )

    if ($env:SCRCPY_WRAPPER_SCRCPY_EXE) {
        return $env:SCRCPY_WRAPPER_SCRCPY_EXE
    }

    $installRoot = Get-ScrcpyInstallRoot
    $candidates = @(
        (Join-Path $installRoot 'scrcpy.exe'),
        (Join-Path $installRoot 'scrcpy.ps1')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    if ($AllowMissing) {
        return $null
    }

    throw "scrcpy is not installed. Run .\setup.ps1 -Install as Administrator to download and install the official Windows release."
}

function Get-ScrcpyAdbPath {
    param(
        [switch]$AllowMissing
    )

    if ($env:SCRCPY_WRAPPER_ADB_EXE) {
        return $env:SCRCPY_WRAPPER_ADB_EXE
    }

    $installRoot = Get-ScrcpyInstallRoot
    $candidates = @(
        (Join-Path $installRoot 'adb.exe'),
        (Join-Path $installRoot 'adb.ps1')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    if ($AllowMissing) {
        return $null
    }

    throw "scrcpy is installed incompletely. adb was not found under '$installRoot'. Run .\setup.ps1 -Install again."
}

function Get-ScrcpyReleaseAsset {
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/Genymobile/scrcpy/releases/latest' -Headers @{
        'Accept'     = 'application/vnd.github+json'
        'User-Agent' = 'CustomScripts-scrcpy-installer'
    }

    $arch = Get-ScrcpyArchitectureInfo
    $asset = @($release.assets | Where-Object { $_.name -like "$($arch.AssetNamePattern)*.zip" } | Select-Object -First 1)
    if (-not $asset) {
        throw "Could not find a Windows scrcpy asset matching pattern '$($arch.AssetNamePattern)*.zip' in release $($release.tag_name)."
    }

    return [PSCustomObject]@{
        Version            = $release.tag_name
        AssetName          = $asset.name
        DownloadUrl        = $asset.browser_download_url
        PublishedAt        = $release.published_at
        InstallRoot        = $arch.InstallRoot
        Is64Bit            = $arch.Is64Bit
        ExpectedSha256     = $null
    }
}

function Add-ScrcpyToSystemPath {
    param(
        [string]$InstallRoot
    )

    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $segments = @($machinePath -split ';' | Where-Object { $_ })
    if ($segments -notcontains $InstallRoot) {
        $newPath = ($segments + $InstallRoot) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine')
    }

    $processSegments = @($env:Path -split ';' | Where-Object { $_ })
    if ($processSegments -notcontains $InstallRoot) {
        $env:Path = (($processSegments + $InstallRoot) -join ';')
    }
}

function Remove-ScrcpyInstallRoot {
    param(
        [string]$InstallRoot
    )

    if (Test-Path -LiteralPath $InstallRoot) {
        Remove-Item -LiteralPath $InstallRoot -Recurse -Force
    }
}

function Install-ScrcpyRuntime {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )) {
        throw 'Installing scrcpy to Program Files requires Administrator privileges. Re-run setup/update in an elevated PowerShell window.'
    }

    $asset = Get-ScrcpyReleaseAsset
    $installRoot = Get-ScrcpyInstallRoot
    $stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('scrcpy-install-' + [guid]::NewGuid().ToString('N'))
    $zipPath = Join-Path $stagingRoot $asset.AssetName
    $extractRoot = Join-Path $stagingRoot 'extract'

    try {
        New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
        Write-Host "  [Downloading] $($asset.AssetName) from official scrcpy release..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $asset.DownloadUrl -OutFile $zipPath
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force

        $payloadRoot = Get-ChildItem -LiteralPath $extractRoot -Directory | Select-Object -First 1
        if (-not $payloadRoot) {
            throw "The downloaded scrcpy archive did not contain an extracted directory."
        }

        if (Test-Path -LiteralPath $installRoot) {
            Remove-ScrcpyInstallRoot -InstallRoot $installRoot
        }

        New-Item -ItemType Directory -Path (Split-Path -Parent $installRoot) -Force | Out-Null
        Move-Item -LiteralPath $payloadRoot.FullName -Destination $installRoot
        # Add-ScrcpyToSystemPath -InstallRoot $installRoot

        return [PSCustomObject]@{
            Version     = $asset.Version
            InstallRoot = $installRoot
            DownloadUrl = $asset.DownloadUrl
            AssetName   = $asset.AssetName
        }
    } finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-ScrcpyInstalledVersion {
    $scrcpyExe = Get-ScrcpyExecutablePath -AllowMissing
    if (-not $scrcpyExe) {
        return $null
    }

    $result = & $scrcpyExe '--version' 2>&1
    foreach ($line in @($result)) {
        if ([string]$line -match '^scrcpy\s+([^\s]+)') {
            return $matches[1]
        }
    }

    return $null
}
