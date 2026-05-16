Set-StrictMode -Version Latest

function Get-VddInstallRoot {
    if ($env:CUSTOMSCRIPTS_VDD_INSTALL_ROOT) {
        return $env:CUSTOMSCRIPTS_VDD_INSTALL_ROOT
    }
    return (Join-Path $env:ProgramFiles 'VirtualDisplayDriver')
}

function Get-VddReleaseAsset {
    $repo = 'VirtualDrivers/Virtual-Display-Driver'
    Write-Host "  [Checking] Latest release from $repo..." -ForegroundColor DarkGray
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{
        'Accept'     = 'application/vnd.github+json'
        'User-Agent' = 'CustomScripts-VDD-Installer'
    }

    $asset = @($release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1)
    if (-not $asset) {
        throw "Could not find a .zip asset in VDD release $($release.tag_name)."
    }

    return [PSCustomObject]@{
        Version     = $release.tag_name
        AssetName   = $asset.name
        DownloadUrl = $asset.browser_download_url
    }
}

function Install-VddDriver {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Installing Virtual Display Driver requires Administrator privileges.'
    }

    $asset = Get-VddReleaseAsset
    $installRoot = Get-VddInstallRoot
    $stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('vdd-install-' + [guid]::NewGuid().ToString('N'))
    $zipPath = Join-Path $stagingRoot $asset.AssetName
    $extractRoot = Join-Path $stagingRoot 'extract'

    try {
        New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
        Write-Host "  [Downloading] $($asset.AssetName)..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $asset.DownloadUrl -OutFile $zipPath

        Write-Host "  [Extracting] driver files..." -ForegroundColor Gray
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force

        # The ZIP usually contains the driver files directly or in a subfolder
        $infFile = Get-ChildItem -Path $extractRoot -Filter "VirtualDisplayDriver.inf" -Recurse | Select-Object -First 1
        if (-not $infFile) {
            throw "Could not find VirtualDisplayDriver.inf in the downloaded archive."
        }
        $driverSourceDir = $infFile.DirectoryName

        # Copy to permanent location
        if (Test-Path $installRoot) {
            Remove-Item $installRoot -Recurse -Force
        }
        New-Item -ItemType Directory -Path (Split-Path $installRoot -Parent) -Force | Out-Null
        Copy-Item -Path $driverSourceDir -Destination $installRoot -Recurse -Force

        # Install Certificate (Crucial for IDD drivers)
        $certFile = Get-ChildItem -Path $installRoot -Filter "*.cer" | Select-Object -First 1
        if ($certFile) {
            Write-Host "  [Trusting] Driver certificate..." -ForegroundColor Yellow
            Import-Certificate -FilePath $certFile.FullName -CertStoreLocation Cert:\LocalMachine\TrustedPublisher | Out-Null
            Import-Certificate -FilePath $certFile.FullName -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
        }

        # Install Driver via Pnputil
        Write-Host "  [Installing] Driver to Windows Driver Store..." -ForegroundColor Yellow
        $infPath = Join-Path $installRoot "VirtualDisplayDriver.inf"
        & pnputil /add-driver $infPath /install | Out-Null

        Write-Host "  [OK] Virtual Display Driver installed successfully." -ForegroundColor Green
        return $installRoot
    } finally {
        if (Test-Path $stagingRoot) {
            Remove-Item $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-VddMonitorStatus {
    # Check if the driver is listed in PnP devices
    $device = Get-PnpDevice -FriendlyName "*Virtual Display*" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'OK' }
    return $device
}
