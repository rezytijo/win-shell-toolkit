Set-StrictMode -Version Latest

function Get-PlatformToolsInstallRoot {
    if ($env:CUSTOMSCRIPTS_PLATFORM_TOOLS_INSTALL_ROOT) {
        return $env:CUSTOMSCRIPTS_PLATFORM_TOOLS_INSTALL_ROOT
    }

    return (Join-Path $env:ProgramFiles 'platform-tools')
}

function Get-PlatformToolsAdbPath {
    param(
        [switch]$AllowMissing
    )

    $installRoot = Get-PlatformToolsInstallRoot
    $candidate = Join-Path $installRoot 'adb.exe'
    if (Test-Path -LiteralPath $candidate) {
        return (Resolve-Path -LiteralPath $candidate).Path
    }

    if ($AllowMissing) {
        return $null
    }

    throw "Android platform-tools is not installed. Run .\setup.ps1 -Install as Administrator to download and install it into Program Files."
}

function Add-PlatformToolsToSystemPath {
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

function Install-PlatformToolsRuntime {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )) {
        throw 'Installing Android platform-tools to Program Files requires Administrator privileges. Re-run setup/update in an elevated PowerShell window.'
    }

    $installRoot = Get-PlatformToolsInstallRoot
    $downloadUrl = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'

    try {
        $headers = (Invoke-WebRequest -Uri $downloadUrl -Method Head -UseBasicParsing -ErrorAction SilentlyContinue).Headers
        $remoteETag = if ($headers['ETag']) { $headers['ETag'] -replace '"', '' } else { $null }
    } catch {
        $remoteETag = $null
    }

    $etagPath = Join-Path $installRoot '.etag'
    if ($remoteETag -and (Test-Path -LiteralPath $etagPath)) {
        $localETag = (Get-Content -LiteralPath $etagPath -Raw).Trim()
        if ($localETag -eq $remoteETag) {
            Write-Host '  [OK] platform-tools is already up-to-date. Skipping download.' -ForegroundColor Green
            return [PSCustomObject]@{
                InstallRoot = $installRoot
                DownloadUrl = $downloadUrl
                Skipped     = $true
            }
        }
    }

    $stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('platform-tools-install-' + [guid]::NewGuid().ToString('N'))
    $zipPath = Join-Path $stagingRoot 'platform-tools-latest-windows.zip'
    $extractRoot = Join-Path $stagingRoot 'extract'

    try {
        New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
        Write-Host '  [Downloading] platform-tools-latest-windows.zip from Google Android repository...' -ForegroundColor Yellow
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force

        $payloadRoot = Join-Path $extractRoot 'platform-tools'
        if (-not (Test-Path -LiteralPath $payloadRoot)) {
            throw 'The downloaded platform-tools archive did not contain the expected platform-tools directory.'
        }

        if (Test-Path -LiteralPath $installRoot) {
            Remove-Item -LiteralPath $installRoot -Recurse -Force
        }

        New-Item -ItemType Directory -Path (Split-Path -Parent $installRoot) -Force | Out-Null
        Move-Item -LiteralPath $payloadRoot -Destination $installRoot
        if ($remoteETag) {
            Set-Content -Path (Join-Path $installRoot '.etag') -Value $remoteETag -Force
        }
        # Add-PlatformToolsToSystemPath -InstallRoot $installRoot

        return [PSCustomObject]@{
            InstallRoot = $installRoot
            DownloadUrl = $downloadUrl
        }
    } finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
