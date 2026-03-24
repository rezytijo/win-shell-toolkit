# sys-lock.ps1 -- Instantly lock the Windows Screen
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Instantly lock the Windows session from the terminal

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.EXAMPLE
    sys-lock
#>

function Invoke-SysLock {
    Write-Host "  [*] Locking screen..." -ForegroundColor DarkGray
    try {
        rundll32.exe user32.dll,LockWorkStation
        Write-Host "  [OK] System Locked." -ForegroundColor Green
    } catch {
        Write-Host "  [Error] Failed to lock screen." -ForegroundColor Red
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-SysLock
}

