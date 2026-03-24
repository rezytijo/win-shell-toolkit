# sys-sleep.ps1 -- Put computer into Sleep / Standby
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Immediately enters ACPI Sleep mode (Standby)

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.EXAMPLE
    sys-sleep
#>

function Invoke-SysSleep {
    Write-Host "  [*] Putting system to sleep in 3 seconds..." -ForegroundColor Yellow
    Write-Host "  [!] Press CTRL+C immediately to abort!" -ForegroundColor Red
    Start-Sleep -Seconds 3
    
    try {
        # SetSuspendState: false, true, false = Sleep (not Hibernate)
        rundll32.exe powrprof.dll,SetSuspendState 0,1,0
    } catch {
        Write-Host "  [Error] Failed to invoke Sleep ACPI call." -ForegroundColor Red
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-SysSleep
}

