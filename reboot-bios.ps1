# reboot-bios.ps1 -- Restart directly into UEFI/BIOS Firmware
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Restarts the computer and enters the UEFI/BIOS settings automatically.

.DESCRIPTION
    Uses the Windows shutdown command with /fw flag to boot into firmware.
    Requires Administrator privileges and a UEFI-supported system.
    This script is part of the CustomScripts arsenal.

.EXAMPLE
    reboot-bios
#>

function Invoke-RebootBios {
    # Check for Admin privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "`n  [!] Error: Administrator privileges required." -ForegroundColor Red
        Write-Host "  Please run this command as Admin or use: sudo reboot-bios`n" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "`n  ========================================" -ForegroundColor Red
    Write-Host "     ⚠️  RESTARTING TO UEFI / BIOS  ⚠️" -ForegroundColor White
    Write-Host "  ========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Saving all work is recommended!" -ForegroundColor Yellow
    Write-Host "  The system will restart in 5 seconds..." -ForegroundColor White

    for ($i = 5; $i -gt 0; $i--) {
        Write-Host "  [$i]... " -NoNewline
        Start-Sleep -Seconds 1
    }

    Write-Host "Rebooting! 🚀" -ForegroundColor Cyan

    # shutdown /r (restart) /fw (firmware) /t 0 (time)
    # Note: This may fail if the hardware does not support UEFI boot-to-firmware
    try {
        shutdown.exe /r /fw /t 0 /f
    } catch {
        Write-Host "`n  [Error] Failed to trigger BIOS reboot." -ForegroundColor Red
        Write-Host "  This system might not support UEFI boot-to-firmware via software." -ForegroundColor Gray
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-RebootBios
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
