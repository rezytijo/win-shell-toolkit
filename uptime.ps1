# uptime.ps1 -- Linux `uptime` equivalent for Windows
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Linux `uptime`, outputs the active system alive time

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.EXAMPLE
    uptime
#>

function Invoke-Uptime {
    $os = Get-CimInstance Win32_OperatingSystem
    $lastBootTime = $os.LastBootUpTime
    $uptime = (Get-Date) - $lastBootTime
    
    $currentTime = (Get-Date).ToString("HH:mm:ss")
    
    $upString = "up "
    if ($uptime.Days -gt 0) { $upString += "$($uptime.Days) days, " }
    
    $hours = $uptime.Hours.ToString().PadLeft(2, '0')
    $mins = $uptime.Minutes.ToString().PadLeft(2, '0')
    $upString += "$hours:$mins"
    
    $usersCount = 1
    try {
        # Check active RDP/Local sessions via quser
        $quserResult = quser 2>$null
        if ($quserResult) {
            $quserLines = ($quserResult | Measure-Object -Line).Lines
            if ($quserLines -gt 1) { $usersCount = $quserLines - 1 }
        }
    } catch {}
    
    Write-Host ""
    Write-Host " $currentTime $upString,  $usersCount user(s)" -ForegroundColor White
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-Uptime
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
