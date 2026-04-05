# setup.ps1 -- CustomScripts Setup Tool
# 05 April 2026 -- v2.2.1: Fixed duplicate function generation and quote escaping
param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Update,
    [switch]$List,
    [switch]$Deps
)

$ErrorActionPreference = 'Stop'

# Get the directory where this script is running (works on any PC)
$ScriptDir = $PSScriptRoot

# Path to PowerShell profile
$ProfilePath = $PROFILE

function Initialize-ProfileFile {
    # Ensure profile directory exists
    $ProfileDir = Split-Path $ProfilePath
    if (!(Test-Path $ProfileDir)) {
        New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
    }

    # Ensure profile file exists
    if (!(Test-Path $ProfilePath)) {
        New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
    }
}

function Test-IsAdministrator {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Get-WindowsSudoCommand {
    return Get-Command sudo -ErrorAction SilentlyContinue
}

function Get-WindowsSudoConfig {
    return (& sudo config 2>&1 | Out-String).Trim()
}

function Set-WindowsSudoConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

    $output = & sudo config --enable $Mode 2>&1 | Out-String
    return [PSCustomObject]@{
        ExitCode = $LASTEXITCODE
        Output   = $output.Trim()
    }
}

function Enable-WindowsSudoMode {
    param(
        [string]$Mode = 'forceNewWindow'
    )

    Write-Host "  [Check] Sudo for Windows" -ForegroundColor White

    $sudoCommand = Get-WindowsSudoCommand
    if (-not $sudoCommand) {
        Write-Host "         Not available on this Windows version. Requires Windows 11 24H2+." -ForegroundColor DarkGray
        return
    }

    try {
        $configStatus = Get-WindowsSudoConfig
        if ($configStatus -match 'Force New Window') {
            Write-Host "  [OK] Sudo for Windows -- already enabled (Force New Window)" -ForegroundColor DarkGray
            return
        }
    } catch {
        Write-Host "         Sudo detected but config not accessible." -ForegroundColor DarkGray
        return
    }

    if (-not (Test-IsAdministrator)) {
        Write-Host "         Run setup as Administrator to enable Windows sudo mode." -ForegroundColor DarkGray
        return
    }

    Write-Host "  [Enabling] Sudo for Windows (forceNewWindow)..." -ForegroundColor Yellow
    $result = Set-WindowsSudoConfig -Mode $Mode
    if ($result.ExitCode -eq 0) {
        Write-Host "  [OK] Sudo for Windows enabled" -ForegroundColor Green
    } else {
        Write-Warning "  Failed to enable Sudo for Windows: $($result.Output)"
    }
}

# ============================================================================
# Dependency Management
# ============================================================================

function Install-Dependencies {
    Write-Host ""
    Write-Host "=== Installing Dependencies ===" -ForegroundColor Cyan
    Write-Host "Scanning scripts for required dependencies..." -ForegroundColor DarkGray
    Write-Host ""

    $isAdmin = Test-IsAdministrator

    # --- [1] PowerShell Modules ---
    Write-Host "[1/3] PowerShell Modules" -ForegroundColor Yellow

    $requiredModules = @(
        @{
            Name        = 'PSWindowsUpdate'
            UsedBy      = 'update.ps1'
            Description = 'Windows Update management via PowerShell'
        },
        @{
            Name        = 'QRCodeGenerator'
            UsedBy      = 'qr.ps1, wifi-qr.ps1'
            Description = 'Offline QR Code image generator'
        }
    )

    foreach ($mod in $requiredModules) {
        $installed = Get-Module -ListAvailable -Name $mod.Name -ErrorAction SilentlyContinue
        if ($installed) {
            $ver = ($installed | Sort-Object Version -Descending | Select-Object -First 1).Version
            Write-Host "  [OK] $($mod.Name) v$ver -- already installed" -ForegroundColor DarkGray
        } else {
            Write-Host "  [Installing] $($mod.Name) -- $($mod.Description)" -ForegroundColor White
            try {
                Install-Module -Name $mod.Name -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
                Write-Host "  [OK] $($mod.Name) installed successfully" -ForegroundColor Green
            } catch {
                Write-Warning "  Failed to install $($mod.Name): $($_.Exception.Message)"
            }
        }
    }
    Write-Host ""

    # --- [2] System Tools (winget packages) ---
    Write-Host "[2/3] System Tools (Winget)" -ForegroundColor Yellow
    $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetAvailable) {
        Write-Warning "  winget is not available."
    } else {
        # Check PowerShell 7
        $checkResult = winget list --id Microsoft.PowerShell --accept-source-agreements 2>&1 | Out-String
        if ($checkResult -match 'Microsoft.PowerShell') {
            Write-Host "  [OK] PowerShell 7 -- already installed" -ForegroundColor DarkGray
        } else {
            Write-Host "  [Required] PowerShell 7" -ForegroundColor White
            try {
                winget install Microsoft.PowerShell --silent --accept-source-agreements --accept-package-agreements
            } catch {
                Write-Warning "  Failed to install pwsh: $($_.Exception.Message)"
            }
        }
    }
    Write-Host ""

    # --- [3] Windows Features ---
    Write-Host "[3/3] Windows Features" -ForegroundColor Yellow
    try {
        if ($isAdmin) {
            $state = Get-WindowsOptionalFeature -Online -FeatureName 'Printing-PrintToPDFServices-Features' -ErrorAction Stop
            if ($state.State -eq 'Enabled') {
                Write-Host "  [OK] Microsoft Print to PDF -- enabled" -ForegroundColor DarkGray
            } else {
                Write-Host "  [Enabling] Microsoft Print to PDF..." -ForegroundColor Yellow
                Enable-WindowsOptionalFeature -Online -FeatureName 'Printing-PrintToPDFServices-Features' -NoRestart -ErrorAction Stop | Out-Null
                Write-Host "  [OK] Enabled" -ForegroundColor Green
            }
        } else {
            Write-Host "  [Skip] Cannot check Windows Features (Requires Admin)" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "  [Skip] Failed to check features." -ForegroundColor DarkGray
    }

    Enable-WindowsSudoMode
    Write-Host ""
}

function Update-Dependencies {
    Write-Host ""
    Write-Host "=== Updating Dependencies ===" -ForegroundColor Cyan
    $requiredModules = @('PSWindowsUpdate', 'QRCodeGenerator')
    foreach ($mod in $requiredModules) {
        Write-Host "  [Updating] $mod ... " -NoNewline -ForegroundColor Yellow
        try {
            Update-Module -Name $mod -Force -ErrorAction Stop
            Write-Host "OK" -ForegroundColor Green
        } catch {
            Write-Host "Failed or Not Installed" -ForegroundColor Red
        }
    }
    Write-Host ""
}

function Remove-Dependencies {
    Write-Host ""
    Write-Host "=== Removing Dependencies ===" -ForegroundColor Red
    $requiredModules = @('PSWindowsUpdate', 'QRCodeGenerator')
    foreach ($mod in $requiredModules) {
        Write-Host "  [Removing] $mod ... " -NoNewline -ForegroundColor DarkGray
        try {
            Uninstall-Module -Name $mod -AllVersions -Force -ErrorAction Stop
            Write-Host "Removed" -ForegroundColor Green
        } catch {
            Write-Host "Skipped" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

# ============================================================================
# Script Discovery & Alias Management
# ============================================================================

function Get-ScriptAliases {
    $aliases = @()
    $dotSourceRequired = @('mkcd', 'mkproj')

    # Prioritize .ps1 files
    $psFiles = Get-ChildItem $ScriptDir -Filter "*.ps1" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "setup.ps1" }
    foreach ($file in $psFiles) {
        $name = $file.BaseName
        $operator = if ($name -in $dotSourceRequired) { "." } else { "&" }
        $aliases += [PSCustomObject]@{
            Name     = $name
            Command  = "$operator `"`$CustomScriptsDir\$($file.Name)`""
        }
    }

    # Only add .bat if no .ps1 exists with same name
    $batFiles = Get-ChildItem $ScriptDir -Filter "*.bat" -ErrorAction SilentlyContinue
    foreach ($file in $batFiles) {
        $name = $file.BaseName
        if (-not ($aliases.Name -contains $name)) {
            $aliases += [PSCustomObject]@{
                Name     = $name
                Command  = "& `"`$CustomScriptsDir\$($file.Name)`""
            }
        }
    }

    return $aliases
}

function New-CmdShims {
    Write-Host "Creating CMD shims (.bat) for all script(s)..." -ForegroundColor Cyan
    $psFiles = Get-ChildItem $ScriptDir -Filter "*.ps1" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "setup.ps1" }
    foreach ($file in $psFiles) {
        $name = $file.BaseName
        $batPath = Join-Path $ScriptDir "$name.bat"
        $shimContent = @"
@echo off
SET "scpath=%~dp0$($file.Name)"
WHERE pwsh >nul 2>nul
IF %ERRORLEVEL% EQU 0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%scpath%" %*
) ELSE (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%scpath%" %*
)
"@
        if (-not (Test-Path $batPath)) {
            $shimContent | Out-File -FilePath $batPath -Encoding ascii
            Write-Host "  [+] Created shim: $name.bat" -ForegroundColor DarkGray
        }
    }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$ScriptDir*") {
        $newPath = $userPath.TrimEnd(';') + ";$ScriptDir"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path += ";$ScriptDir"
    }
}

function Remove-Aliases {
    Initialize-ProfileFile
    $content = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
    if ($content) {
        $newContent = $content -replace '(?s)# === CustomScripts Auto-Setup ===.*?# === End CustomScripts Setup ===\s*', ''
        Set-Content $ProfilePath $newContent
    }
}

function Get-ScriptList {
    $aliases = Get-ScriptAliases
    Write-Host "`nScripts found in: $ScriptDir`n" -ForegroundColor Cyan
    foreach ($alias in $aliases) {
        Write-Host "  * $($alias.Name)" -ForegroundColor Green
    }
    Write-Host "`nTotal: $($aliases.Count) script(s)" -ForegroundColor Cyan
}

function Sync-Aliases {
    Initialize-ProfileFile
    Install-Dependencies
    New-CmdShims

    Write-Host "Registering commands in profile..." -ForegroundColor Cyan
    $aliases = Get-ScriptAliases
    Remove-Aliases

    $setupBlock = @"

# === CustomScripts Auto-Setup ===
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
`$CustomScriptsDir = `"$ScriptDir`"
"@

    foreach ($alias in $aliases) {
        $helpPath = Join-Path $ScriptDir "$($alias.Name).ps1"
        if (Test-Path $helpPath) {
            $setupBlock += "`nfunction $($alias.Name) { if ('-h' -in `$args -or '--help' -in `$args) { Get-Help `"`$CustomScriptsDir\$($alias.Name).ps1`" -Detailed } else { $($alias.Command) @args } }"
        } else {
            $setupBlock += "`nfunction $($alias.Name) { $($alias.Command) @args }"
        }
    }

    $setupBlock += "`n# === End CustomScripts Setup ===`n"
    Add-Content $ProfilePath $setupBlock

    Write-Host "Successfully registered $($aliases.Count) commands." -ForegroundColor Green
    try { . $ProfilePath; Write-Host "Profile reloaded." -ForegroundColor Gray } catch {}
}

function Invoke-Setup {
    if ($Install) { Sync-Aliases }
    elseif ($Uninstall) { Remove-Aliases; Remove-Dependencies }
    elseif ($Update) { Update-Dependencies }
    elseif ($List) { Get-ScriptList }
    elseif ($Deps) { Install-Dependencies }
    else {
        Write-Host "CustomScripts Setup Tool`n" -ForegroundColor Cyan
        Write-Host "  -Install   : Setup everything"
        Write-Host "  -Uninstall : Cleanup everything"
        Write-Host "  -Update    : Update modules"
        Write-Host "  -List      : Show scripts"
    }
}

if ($env:CUSTOMSCRIPTS_SKIP_MAIN -ne '1') {
    if ($MyInvocation.InvocationName -ne '.') {
        try { Invoke-Setup } catch {
            Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
}
