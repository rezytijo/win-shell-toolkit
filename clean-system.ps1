#Requires -RunAsAdministrator
# clean-system.ps1 -- System Maintenance & Cleaning Utility
# 2026-05-25 -- v1.1.0: Added shortcut, registry, and remnants cleaning

param(
    [parameter(Mandatory=$false)]
    [switch]$CleanRegistry,

    [parameter(Mandatory=$false)]
    [switch]$CleanLeftovers,

    [parameter(Mandatory=$false)]
    [switch]$SkipShortcuts
)

$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Cleans Temp folders, empty Recycle Bin, clears Win Update cache, deletes broken shortcuts, and cleans registry/folders remnants.

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER CleanRegistry
    If set, scans and removes phantom/stale uninstall keys in the registry.

.PARAMETER CleanLeftovers
    If set, sweeps empty directories from common AppData/ProgramData leftover folders.

.PARAMETER SkipShortcuts
    If set, skips the automatic scan and removal of broken shortcuts on the Desktop and Start Menu.

.EXAMPLE
    clean-system -CleanRegistry -CleanLeftovers
#>

function Get-ExecutablePathFromCommandLine {
    param([string]$CommandLine)
    if (-not $CommandLine) { return $null }
    $CommandLine = $CommandLine.Trim()
    
    # 1. If it starts with a quote, extract everything inside the first pair of quotes
    if ($CommandLine.StartsWith('"')) {
        $endQuoteIndex = $CommandLine.IndexOf('"', 1)
        if ($endQuoteIndex -gt 0) {
            return $CommandLine.Substring(1, $endQuoteIndex - 1).Trim()
        }
    }
    
    # 2. Otherwise, look for extensions or split by space
    if ($CommandLine -match '^(.*?\.(?:exe|msi|bat|cmd|com))(?:\s+|$)' -or $CommandLine -match '^([^"\s]+)') {
        return $Matches[1].Trim('"').Trim()
    }
    return $CommandLine.Trim('"').Trim()
}

function Clean-ShortcutsInternal {
    param(
        [string[]]$Paths = @(
            "$env:USERPROFILE\Desktop",
            "$env:PUBLIC\Desktop",
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
        )
    )

    Write-Host "  [*] Scanning for broken shortcuts..." -ForegroundColor Yellow
    $wshShell = New-Object -ComObject WScript.Shell
    $cleanedCount = 0

    foreach ($path in $Paths) {
        if (-not (Test-Path -Path $path -PathType Container)) {
            continue
        }

        $lnkFiles = Get-ChildItem -Path $path -Filter *.lnk -Recurse -File -ErrorAction SilentlyContinue
        if (-not $lnkFiles) { continue }

        foreach ($file in $lnkFiles) {
            try {
                $lnk = $wshShell.CreateShortcut($file.FullName)
                $target = $lnk.TargetPath
                if ($target) {
                    $expandedTarget = [System.Environment]::ExpandEnvironmentVariables($target)
                    # Check if target is a local file path or UNC path
                    if ($expandedTarget -match '^[A-Za-z]:\\' -or $expandedTarget -like '\\\\*') {
                        $drive = Split-Path -Qualifier $expandedTarget
                        $driveExists = $true
                        if ($drive) {
                            $driveExists = [bool](Get-PSDrive -Name $drive.TrimEnd(':') -ErrorAction SilentlyContinue)
                        }

                        if ($driveExists -and -not (Test-Path -Path $expandedTarget)) {
                            Write-Host "      [Removing] Broken Shortcut: $($file.FullName) -> $expandedTarget" -ForegroundColor DarkGray
                            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                            $cleanedCount++
                        }
                    }
                }
            } catch {
                # Skip if we encounter permission issues or invalid shortcuts
            }
        }
    }

    if ($cleanedCount -gt 0) {
        Write-Host "      [OK] Cleaned $cleanedCount broken shortcuts." -ForegroundColor Green
    } else {
        Write-Host "      [OK] No broken shortcuts found." -ForegroundColor Green
    }
}

function Clean-RegistryInternal {
    param(
        [string[]]$RegistryPaths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
    )

    Write-Host "  [*] Scanning for phantom registry entries..." -ForegroundColor Yellow
    $cleanedCount = 0

    foreach ($regPath in $RegistryPaths) {
        # Check if the base path (without wildcard) exists
        $basePath = $regPath.TrimEnd('*').TrimEnd('\')
        if (-not (Test-Path -Path $basePath)) {
            continue
        }

        $subkeys = Get-Item -Path $regPath -ErrorAction SilentlyContinue
        if (-not $subkeys) { continue }

        foreach ($key in $subkeys) {
            try {
                $displayName = $key.GetValue("DisplayName")
                $uninstallString = $key.GetValue("UninstallString")
                $quietUninstallString = $key.GetValue("QuietUninstallString")
                $installLocation = $key.GetValue("InstallLocation")
                $displayIcon = $key.GetValue("DisplayIcon")
                $systemComponent = $key.GetValue("SystemComponent")

                if ($displayName -and -not $systemComponent) {
                    $hasInvalidUninstall = $false
                    $hasInvalidLocation = $false
                    $hasInvalidIcon = $false

                    $isLocalUninstall = $false
                    $isLocalLocation = $false
                    $isLocalIcon = $false

                    # Check UninstallString
                    $uninstPath = $null
                    if ($uninstallString) {
                        $uninstPath = Get-ExecutablePathFromCommandLine $uninstallString
                    } elseif ($quietUninstallString) {
                        $uninstPath = Get-ExecutablePathFromCommandLine $quietUninstallString
                    }

                    if ($uninstPath) {
                        $expandedUninst = [System.Environment]::ExpandEnvironmentVariables($uninstPath)
                        if ($expandedUninst -match '^[A-Za-z]:\\' -or $expandedUninst -like '\\\\*') {
                            $isLocalUninstall = $true
                            $drive = Split-Path -Qualifier $expandedUninst
                            $driveExists = $true
                            if ($drive) {
                                $driveExists = [bool](Get-PSDrive -Name $drive.TrimEnd(':') -ErrorAction SilentlyContinue)
                            }
                            if ($driveExists -and -not (Test-Path -Path $expandedUninst -PathType Leaf)) {
                                $hasInvalidUninstall = $true
                            }
                        } else {
                            # Check if it resolves to a system command/executable in the PATH
                            $isLocalUninstall = $true
                            if (-not (Get-Command -Name $expandedUninst -ErrorAction SilentlyContinue)) {
                                $hasInvalidUninstall = $true
                            }
                        }
                    }

                    # Check InstallLocation
                    if ($installLocation) {
                        $expandedLoc = [System.Environment]::ExpandEnvironmentVariables($installLocation).Trim('"').Trim()
                        if ($expandedLoc -match '^[A-Za-z]:\\' -or $expandedLoc -like '\\\\*') {
                            $isLocalLocation = $true
                            $drive = Split-Path -Qualifier $expandedLoc
                            $driveExists = $true
                            if ($drive) {
                                $driveExists = [bool](Get-PSDrive -Name $drive.TrimEnd(':') -ErrorAction SilentlyContinue)
                            }
                            if ($driveExists -and -not (Test-Path -Path $expandedLoc -PathType Container)) {
                                $hasInvalidLocation = $true
                            }
                        }
                    }

                    # Check DisplayIcon
                    if ($displayIcon) {
                        $iconPath = $displayIcon -replace ',\s*-?\d+$', ''
                        $expandedIcon = [System.Environment]::ExpandEnvironmentVariables($iconPath).Trim('"').Trim()
                        if ($expandedIcon -match '^[A-Za-z]:\\' -or $expandedIcon -like '\\\\*') {
                            $isLocalIcon = $true
                            $drive = Split-Path -Qualifier $expandedIcon
                            $driveExists = $true
                            if ($drive) {
                                $driveExists = [bool](Get-PSDrive -Name $drive.TrimEnd(':') -ErrorAction SilentlyContinue)
                            }
                            if ($driveExists -and -not (Test-Path -Path $expandedIcon -PathType Leaf)) {
                                $hasInvalidIcon = $true
                            }
                        }
                    }

                    # Determine if key is stale
                    $isStale = $false
                    $hasLocalPath = $false
                    $allLocalPathsInvalid = $true

                    if ($isLocalUninstall) {
                        $hasLocalPath = $true
                        if (-not $hasInvalidUninstall) { $allLocalPathsInvalid = $false }
                    }
                    if ($isLocalLocation) {
                        $hasLocalPath = $true
                        if (-not $hasInvalidLocation) { $allLocalPathsInvalid = $false }
                    }
                    if ($isLocalIcon) {
                        $hasLocalPath = $true
                        if (-not $hasInvalidIcon) { $allLocalPathsInvalid = $false }
                    }

                    if ($hasLocalPath -and $allLocalPathsInvalid) {
                        $isStale = $true
                    }

                    if ($isStale) {
                        Write-Host "      [Removing] Phantom Registry Entry: $displayName ($($key.PSChildName))" -ForegroundColor DarkGray
                        Remove-Item -Path $key.PSPath -Force -Recurse -ErrorAction SilentlyContinue
                        $cleanedCount++
                    }
                }
            } catch {
                # Skip this key if there are permissions or read errors
            }
        }
    }

    if ($cleanedCount -gt 0) {
        Write-Host "      [OK] Cleaned $cleanedCount phantom registry entries." -ForegroundColor Green
    } else {
        Write-Host "      [OK] No phantom registry entries found." -ForegroundColor Green
    }
}

function Clean-LeftoversInternal {
    param(
        [string[]]$Paths = @(
            "C:\Program Files",
            "C:\Program Files (x86)",
            "C:\ProgramData",
            $env:APPDATA,
            $env:LOCALAPPDATA
        )
    )

    Write-Host "  [*] Sweeping empty folders from application directories..." -ForegroundColor Yellow
    $cleanedCount = 0

    foreach ($path in $Paths) {
        if (-not (Test-Path -Path $path -PathType Container)) {
            continue
        }

        try {
            # Find subfolders bottom-up
            $directories = Get-ChildItem -Path $path -Recurse -Directory -ErrorAction SilentlyContinue |
                           Sort-Object -Property @{ Expression={$_.FullName.Length}; Descending=$true }

            if ($directories) {
                foreach ($dir in $directories) {
                    $items = Get-ChildItem -Path $dir.FullName -Force -ErrorAction SilentlyContinue
                    # Check empty safely without causing errors under StrictMode Latest
                    if (-not $items) {
                        Write-Host "      [Removing] Empty Folder: $($dir.FullName)" -ForegroundColor DarkGray
                        Remove-Item -Path $dir.FullName -Force -ErrorAction SilentlyContinue
                        $cleanedCount++
                    }
                }
            }
        } catch {
            # Skip if we encounter permission errors (common in Program Files)
        }
    }

    if ($cleanedCount -gt 0) {
        Write-Host "      [OK] Swept $cleanedCount empty directories." -ForegroundColor Green
    } else {
        Write-Host "      [OK] No empty directories found." -ForegroundColor Green
    }
}

function Invoke-CleanSystem {
    $separator = "=========================================="
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   SYSTEM CLEANER" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""

    # 1. Clear User Temp
    Write-Host "  [*] Cleaning User Temp..." -ForegroundColor Yellow
    $userTemp = $env:TEMP
    try {
        Remove-Item "$userTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "      [OK] User Temp cleaned." -ForegroundColor Green
    } catch {
        Write-Host "      [Notice] Some User Temp files are in use." -ForegroundColor DarkGray
    }

    # 2. Clear System Temp
    Write-Host "  [*] Cleaning Windows Temp..." -ForegroundColor Yellow
    $sysTemp = "$env:WINDIR\Temp"
    try {
        Remove-Item "$sysTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "      [OK] Windows Temp cleaned." -ForegroundColor Green
    } catch {
        Write-Host "      [Notice] Some System Temp files are in use." -ForegroundColor DarkGray
    }

    # 3. Empty Recycle Bin
    Write-Host "  [*] Emptying Recycle Bin..." -ForegroundColor Yellow
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Host "      [OK] Recycle Bin emptied." -ForegroundColor Green
    } catch {
        Write-Host "      [Notice] Recycle Bin is already empty or skipping." -ForegroundColor DarkGray
    }

    # 4. Windows Update Cache (SoftwareDistribution)
    # Note: Requires stopping wuauserv service
    Write-Host "  [*] Cleaning Windows Update Cache..." -ForegroundColor Yellow
    try {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Remove-Item "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        Write-Host "      [OK] Update cache cleaned." -ForegroundColor Green
    } catch {
        Write-Host "      [Warning] Failed to clean Windows Update Cache." -ForegroundColor Red
    }

    # 5. Clean Shortcuts (Default, unless skipped)
    if (-not $SkipShortcuts) {
        Clean-ShortcutsInternal
    }

    # 6. Clean Registry (Optional, enabled via -CleanRegistry)
    if ($CleanRegistry) {
        Clean-RegistryInternal
    }

    # 7. Clean Leftovers (Optional, enabled via -CleanLeftovers)
    if ($CleanLeftovers) {
        Clean-LeftoversInternal
    }

    Write-Host ""
    Write-Host "  Clean-up finished successfully!" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-CleanSystem
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

