#Requires -RunAsAdministrator
# clean-system.ps1 -- System Maintenance & Cleaning Utility

<#
.SYNOPSIS
Cleans Temp folders, empty Recycle Bin, clears Win Update cache

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.EXAMPLE
    clean-system
#>

# 2026-03-11 -- v1.0.0: Initial version

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

    Write-Host ""
    Write-Host "  Clean-up finished successfully!" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-CleanSystem
}

