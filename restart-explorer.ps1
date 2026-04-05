# restart-explorer.ps1 -- The Windows Taskbar & Explorer Fixer
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Force-kills and restarts Taskbar/Desktop safely

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.EXAMPLE
    restart-explorer
#>

function Invoke-RestartExplorer {
    $separator = "========================================"
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   RESTARTING WINDOWS EXPLORER..." -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [*] Terminating explorer.exe process..." -ForegroundColor Yellow
    
    try {
        # Gracefully stop, force if necessary
        Stop-Process -Name explorer -Force -ErrorAction Stop
        Write-Host "      [OK] Process killed." -ForegroundColor Green
        
        # Explorer usually restarts itself, but just in case:
        Start-Sleep -Seconds 1
        $check = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if (-not $check) {
            Write-Host "  [*] Starting explorer.exe..." -ForegroundColor Yellow
            Start-Process explorer.exe
        }
        
        Write-Host "      [OK] Explorer is running." -ForegroundColor Green
        Write-Host ""
        Write-Host "  Done! Taskbar and Desktop refreshed." -ForegroundColor Cyan
    } catch {
        Write-Host "  [Error] Failed to restart explorer: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-RestartExplorer
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
