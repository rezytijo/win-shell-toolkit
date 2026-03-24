# setup.ps1 -- CustomScripts Setup Tool
# 2026-03-11 -- v2.1.0: Added dependency installation, fixed argument forwarding in profile functions

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Update,
    [switch]$List,
    [switch]$Deps
)

# Get the directory where this script is running (works on any PC)
$ScriptDir = $PSScriptRoot

# Path to PowerShell profile
$ProfilePath = $PROFILE

function Ensure-ProfileFile {
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

    $configStatus = Get-WindowsSudoConfig
    if ($configStatus -match 'Force New Window') {
        Write-Host "  [OK] Sudo for Windows -- already enabled (Force New Window)" -ForegroundColor DarkGray
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
    <#
    .SYNOPSIS
    Installs all dependencies required by scripts in the CustomScripts folder.
    Supports: PowerShell modules, winget packages, and Windows optional features.
    #>

    Write-Host ""
    Write-Host "=== Installing Dependencies ===" -ForegroundColor Cyan
    Write-Host "Scanning scripts for required dependencies..." -ForegroundColor DarkGray
    Write-Host ""

    $totalSteps = 3
    $currentStep = 0
    $isAdmin = Test-IsAdministrator

    # --- [1] PowerShell Modules ---
    $currentStep++
    Write-Host "[$currentStep/$totalSteps] PowerShell Modules" -ForegroundColor Yellow

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
            Write-Host "               Used by: $($mod.UsedBy)" -ForegroundColor DarkGray
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
    $currentStep++
    Write-Host "[$currentStep/$totalSteps] System Tools (Winget)" -ForegroundColor Yellow

    # Check if winget is available
    $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetAvailable) {
        Write-Warning "  winget is not available. Skipping system tool checks."
        Write-Warning "  Install App Installer from Microsoft Store to enable winget."
    } else {
        $requiredTools = @(
            @{
                Id          = 'Microsoft.PowerShell'
                Name        = 'PowerShell 7 (Core)'
                UsedBy      = 'System / All Scripts'
                Description = 'Modern and faster PowerShell environment'
                Optional    = $false
            }
        )

        foreach ($tool in $requiredTools) {
            # Check if already installed via winget
            $checkResult = winget list --id $tool.Id --accept-source-agreements 2>&1 | Out-String
            if ($checkResult -match [regex]::Escape($tool.Id)) {
                Write-Host "  [OK] $($tool.Name) -- already installed" -ForegroundColor DarkGray
            } else {
                Write-Host "  [Required] $($tool.Name) -- $($tool.Description)" -ForegroundColor White
                try {
                    winget install $tool.Id --silent --accept-source-agreements --accept-package-agreements
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  [OK] $($tool.Name) installed successfully" -ForegroundColor Green
                    } else {
                        Write-Warning "  Failed to install $($tool.Name) (exit code: $LASTEXITCODE)"
                    }
                } catch {
                    Write-Warning "  Failed to install $($tool.Name): $($_.Exception.Message)"
                }
            }
        }

        # --- Speedtest CLI (Special Handling: Winget -> Manual Fallback) ---
        $speedtestInstalled = Get-Command speedtest -ErrorAction SilentlyContinue
        if ($speedtestInstalled) {
            Write-Host "  [OK] Ookla Speedtest CLI -- already installed" -ForegroundColor DarkGray
        } else {
            Write-Host "  [Optional] Ookla Speedtest CLI -- Network speed test" -ForegroundColor White
            $installedViaWinget = $false
            if ($wingetAvailable) {
                Write-Host "             Attempting installation via winget..." -ForegroundColor DarkGray
                winget install Ookla.Speedtest.CLI --silent --accept-source-agreements --accept-package-agreements | Out-Null
                if ($LASTEXITCODE -eq 0) { 
                    Write-Host "  [OK] Speedtest CLI installed via winget" -ForegroundColor Green
                    $installedViaWinget = $true
                }
            }

            if (-not $installedViaWinget) {
                Write-Host "             Winget failed or unavailable. Manual installation..." -ForegroundColor Yellow
                if ($isAdmin) {
                    try {
                        $url = "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip"
                        $zipPath = "$env:TEMP\ookla-speedtest.zip"
                        $extractPath = "$env:TEMP\ookla-speedtest"
                        $installPath = "C:\Program Files\Ookla Speedtest"

                        Invoke-WebRequest -Uri $url -OutFile $zipPath -ErrorAction Stop
                        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
                        if (!(Test-Path $installPath)) { New-Item -ItemType Directory -Path $installPath -Force | Out-Null }
                        Move-Item -Path "$extractPath\*" -Destination $installPath -Force
                        
                        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                        if ($currentPath -notlike "*$installPath*") {
                            $newPath = $currentPath + ";$installPath"
                            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
                            $env:Path += ";$installPath"
                        }
                        Remove-Item $zipPath -Force
                        Remove-Item $extractPath -Recurse -Force
                        Write-Host "  [OK] Speedtest CLI installed manually to Program Files" -ForegroundColor Green
                    } catch {
                        Write-Warning "             Manual installation failed: $($_.Exception.Message)"
                    }
                } else {
                    Write-Host "             Skipped. Run as Admin for manual installation fallback." -ForegroundColor DarkGray
                }
            }
        }
    }
    Write-Host ""

    # --- [3] Windows Features ---
    $currentStep++
    Write-Host "[$currentStep/$totalSteps] Windows Features" -ForegroundColor Yellow

    $requiredFeatures = @(
        @{
            Name        = 'Printing-PrintToPDFServices-Features'
            DisplayName = 'Microsoft Print to PDF'
            UsedBy      = 'ExportToPdf.ps1'
        }
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    foreach ($feature in $requiredFeatures) {
        try {
            $state = Get-WindowsOptionalFeature -Online -FeatureName $feature.Name -ErrorAction Stop
            if ($state.State -eq 'Enabled') {
                Write-Host "  [OK] $($feature.DisplayName) -- enabled" -ForegroundColor DarkGray
            } else {
                Write-Host "  [Disabled] $($feature.DisplayName)" -ForegroundColor White
                Write-Host "             Used by: $($feature.UsedBy)" -ForegroundColor DarkGray
                if ($isAdmin) {
                    Write-Host "  [Enabling] $($feature.DisplayName)..." -ForegroundColor Yellow
                    Enable-WindowsOptionalFeature -Online -FeatureName $feature.Name -NoRestart -ErrorAction Stop | Out-Null
                    Write-Host "  [OK] $($feature.DisplayName) enabled" -ForegroundColor Green
                } else {
                    Write-Host "             Run as Admin to enable, or enable via:" -ForegroundColor DarkGray
                    Write-Host "             Settings > Apps > Optional Features > More Windows Features" -ForegroundColor DarkGray
                }
            }
        } catch {
            Write-Host "  [Skip] Cannot check $($feature.DisplayName) (requires Admin)" -ForegroundColor DarkGray
        }
    }

    Enable-WindowsSudoMode

    Write-Host ""
    Write-Host "=== Dependency check complete ===" -ForegroundColor Cyan
    Write-Host ""
}

function Update-Dependencies {
    <#
    .SYNOPSIS
    Updates the installed PowerShell modules required by the scripts.
    #>
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

function Uninstall-Dependencies {
    <#
    .SYNOPSIS
    Removes the PowerShell modules that were installed by this setup.
    #>
    Write-Host ""
    Write-Host "=== Removing Dependencies ===" -ForegroundColor Red
    
    $requiredModules = @('PSWindowsUpdate', 'QRCodeGenerator')
    foreach ($mod in $requiredModules) {
        Write-Host "  [Removing] $mod ... " -NoNewline -ForegroundColor DarkGray
        try {
            # Attempt to cleanly wipe out all versions of the module silently
            Uninstall-Module -Name $mod -AllVersions -Force -ErrorAction Stop
            Write-Host "Removed" -ForegroundColor Green
        } catch {
            Write-Host "Skipped (Not found or in use)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

# ============================================================================
# Script Discovery & Alias Management
# ============================================================================

function Get-ScriptAliases {
    <#
    .SYNOPSIS
    Discovers all .bat and .ps1 files in $ScriptDir and generates PowerShell alias commands.
    #>
    $aliases = @()

    # Scripts that MUST be dot-sourced to affect the parent shell (e.g., Change Directory)
    $dotSourceRequired = @('mkcd', 'mkproj')

    # Get all .ps1 files (excluding setup.ps1 itself)
    Get-ChildItem $ScriptDir -Filter "*.ps1" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "setup.ps1" } |
        ForEach-Object {
            $name = $_.BaseName
            $fullPath = $_.FullName
            # Use dot-source (.) if required, otherwise call operator (&)
            $operator = if ($name -in $dotSourceRequired) { "." } else { "&" }
            $aliases += [PSCustomObject]@{
                Type     = "Function"
                Name     = $name
                FullPath = $fullPath
                Command  = "$operator `"$fullPath`""
            }
        }

    # Get all .bat files
    Get-ChildItem $ScriptDir -Filter "*.bat" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $name = $_.BaseName
            $fullPath = $_.FullName
            $aliases += [PSCustomObject]@{
                Type     = "Alias"
                Name     = $name
                FullPath = $fullPath
                Command  = "&`"$fullPath`""
            }
        }

    return $aliases
}

function Create-CmdShims {
    <#
    .SYNOPSIS
    Creates .bat shims for all .ps1 scripts and adds the folder to User PATH
    to make them available in CMD (Command Prompt).
    #>
    Write-Host "Creating CMD shims (.bat) for all script(s)..." -ForegroundColor Cyan
    
    $psFiles = Get-ChildItem $ScriptDir -Filter "*.ps1" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "setup.ps1" }
    
    foreach ($file in $psFiles) {
        $name = $file.BaseName
        $batPath = Join-Path $ScriptDir "$name.bat"
        
        # Robust shim content that tries pwsh first, then powershell
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
        # Only create if it doesn't exist or is a generic shim
        if (-not (Test-Path $batPath)) {
            $shimContent | Out-File -FilePath $batPath -Encoding ascii
            Write-Host "  [+] Created shim: $name.bat" -ForegroundColor DarkGray
        }
    }

    # Add to PATH if not already there
    Write-Host "Checking system PATH for CMD accessibility..." -ForegroundColor Cyan
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$ScriptDir*") {
        Write-Host "  [!] Adding $ScriptDir to User PATH..." -ForegroundColor Yellow
        $newPath = $userPath.TrimEnd(';') + ";$ScriptDir"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path += ";$ScriptDir"
        Write-Host "  [OK] PATH updated. (Restart CMD to take effect)" -ForegroundColor Green
    } else {
        Write-Host "  [OK] $ScriptDir already in PATH" -ForegroundColor DarkGray
    }
}

function Install-Aliases {
    <#
    .SYNOPSIS
    Installs dependencies, then adds aliases/functions for all scripts to PowerShell profile.
    #>

    Ensure-ProfileFile

    # Step 1: Install dependencies first
    Install-Dependencies

    # Step 2: Create CMD shims for all .ps1 files
    Create-CmdShims

    # Step 2: Configure profile aliases
    Write-Host "Setting up PowerShell aliases from: $ScriptDir" -ForegroundColor Cyan

    $aliases = Get-ScriptAliases

    if ($aliases.Count -eq 0) {
        Write-Host "Warning: No .ps1 or .bat files found in $ScriptDir" -ForegroundColor Yellow
        return
    }

    # Check if profile already has our setup marker
    $profileContent = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
    if ($profileContent -like "*# === CustomScripts Auto-Setup ===*") {
        Write-Host "Warning: Profile already configured. Removing old setup..." -ForegroundColor Yellow
        Uninstall-Aliases
    }

    # Build the setup block
    $setupBlock = @"

# === CustomScripts Auto-Setup ===
# Auto-generated setup for scripts.
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

`$CustomScriptsDir = (Resolve-Path (Join-Path (Split-Path `$PROFILE) "..\CustomScripts") -ErrorAction SilentlyContinue).Path
if (-not `$CustomScriptsDir) {
    `$CustomScriptsDir = `"$ScriptDir`"
}

"@

    foreach ($alias in $aliases) {
        if ($alias.Type -eq "Function") {
            if ($alias.Name -eq "mkcd") {
                # mkcd needs to be dot-sourced (.) to change the parent shell's location
                $setupBlock += "function $($alias.Name) { if ('-h' -in `$args -or '--help' -in `$args) { Get-Help `"`$CustomScriptsDir\$($alias.Name).ps1`" -Detailed } else { . `"`$CustomScriptsDir\$($alias.Name).ps1`" @args } }`n"
            } else {
                $setupBlock += "function $($alias.Name) { if ('-h' -in `$args -or '--help' -in `$args) { Get-Help `"`$CustomScriptsDir\$($alias.Name).ps1`" -Detailed } else { & `"`$CustomScriptsDir\$($alias.Name).ps1`" @args } }`n"
            }
        } else {
            $setupBlock += "function $($alias.Name) { & `"`$CustomScriptsDir\$($alias.Name).bat`" @args }`n"
        }
    }

    $setupBlock += @"

# === End CustomScripts Setup ===
"@

    # Append to profile
    Add-Content $ProfilePath $setupBlock

    Write-Host "Successfully added $($aliases.Count) command(s) to profile" -ForegroundColor Green
    Write-Host ""
    Write-Host "Commands added:" -ForegroundColor Cyan
    foreach ($alias in $aliases) {
        Write-Host "  * $($alias.Name) ($($alias.Type))" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Reloading profile to activate aliases..." -ForegroundColor Yellow
    try {
        . $ProfilePath
        Write-Host "Profile reloaded successfully." -ForegroundColor Green
    } catch {
        Write-Host "Warning: Failed to reload profile. Please restart PowerShell or run: . `$PROFILE" -ForegroundColor Yellow
    }
}

function Uninstall-Aliases {
    <#
    .SYNOPSIS
    Removes the CustomScripts setup block from PowerShell profile.
    #>
    Ensure-ProfileFile
    Write-Host "Removing CustomScripts setup from profile..." -ForegroundColor Red

    $content = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        Write-Host "Warning: Profile is empty or doesn't exist." -ForegroundColor Yellow
        return
    }

    # Remove the setup block
    $newContent = $content -replace '(?s)# === CustomScripts Auto-Setup ===.*?# === End CustomScripts Setup ===\s*', ''

    Set-Content $ProfilePath $newContent
    Write-Host "CustomScripts setup removed from profile" -ForegroundColor Green
}

function Show-ScriptList {
    <#
    .SYNOPSIS
    Lists all detected scripts and their commands.
    #>
    $aliases = Get-ScriptAliases

    if ($aliases.Count -eq 0) {
        Write-Host "Warning: No scripts found in $ScriptDir" -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Scripts found in: $ScriptDir" -ForegroundColor Cyan
    Write-Host ""

    foreach ($alias in $aliases) {
        Write-Host "  [$($alias.Type.PadRight(8))] $($alias.Name)" -ForegroundColor Green
        Write-Host "                 -> $($alias.FullPath)" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "Total: $($aliases.Count) script(s)" -ForegroundColor Cyan
}

# ============================================================================
# Main Execution
# ============================================================================

if ($env:CUSTOMSCRIPTS_SKIP_MAIN -ne '1') {
    if ($Install) {
        Install-Aliases
    } elseif ($Uninstall) {
        Uninstall-Aliases
        Uninstall-Dependencies
    } elseif ($Update) {
        Update-Dependencies
    } elseif ($List) {
        Show-ScriptList
    } elseif ($Deps) {
        Install-Dependencies
    } else {
        Write-Host "CustomScripts Setup Tool" -ForegroundColor Cyan
        Write-Host "========================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  .\setup.ps1 -Install   -> Install dependencies + add scripts to profile" -ForegroundColor White
        Write-Host "  .\setup.ps1 -Deps      -> Install/check dependencies only" -ForegroundColor White
        Write-Host "  .\setup.ps1 -Update    -> Check and update installed PowerShell modules" -ForegroundColor White
        Write-Host "  .\setup.ps1 -List      -> Show available scripts" -ForegroundColor White
        Write-Host "  .\setup.ps1 -Uninstall -> Remove CustomScripts from profile and Wipe Modules" -ForegroundColor White
        Write-Host ""
        Write-Host "After installation, restart PowerShell or run: . `$PROFILE" -ForegroundColor Gray
    }
}
