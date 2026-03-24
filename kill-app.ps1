# kill-app.ps1 -- Linux killall equivalent
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Force-kills apps by name (akin to Linux `killall`)

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Name
    Specifies the Name parameter.

.EXAMPLE
    kill-app
#>

function Invoke-KillApp {
    param(
        [Parameter(Mandatory=$true, Position=0, HelpMessage="Name of the app/process to destroy (e.g. 'chrome')")]
        [string]$Name
    )
    
    $procs = Get-Process -Name "*$Name*" -ErrorAction SilentlyContinue
    if (-not $procs) {
        Write-Host "  [!] No active processes matching '$Name' found." -ForegroundColor DarkGray
        return
    }
    
    foreach ($p in $procs) {
        Write-Host "  [Killing] $($p.ProcessName) (PID: $($p.Id))..." -NoNewline -ForegroundColor Yellow
        try {
            Stop-Process -Id $p.Id -Force -ErrorAction Stop
            Write-Host " OK" -ForegroundColor Green
        } catch {
            Write-Host " FAILED ($($_.Exception.Message))" -ForegroundColor Red
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-KillApp @args
}

