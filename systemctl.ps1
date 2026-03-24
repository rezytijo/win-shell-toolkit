# systemctl.ps1 -- Service Daemon Manager for Windows
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Manages background Windows Services (start/stop/status)

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Command
    Specifies the Command parameter.

.PARAMETER ServiceName
    Specifies the ServiceName parameter.

.EXAMPLE
    systemctl
#>

function Invoke-Systemctl {
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateSet('status', 'start', 'stop', 'restart', 'list')]
        [string]$Command,

        [Parameter(Position=1)]
        [string]$ServiceName
    )

    if ($Command -eq 'list') {
        Get-Service | Where-Object Status -eq 'Running' | Sort-Object DisplayName | Format-Table -Property Status, Name, DisplayName -AutoSize
        return
    }

    if (-not $ServiceName) {
        Write-Host "  [Error] Please provide a Windows Service name. (e.g. systemctl status wuauserv)" -ForegroundColor Red
        return
    }

    try {
        $svc = Get-Service -Name $ServiceName -ErrorAction Stop
    } catch {
        Write-Host "  [Error] Service '$ServiceName' could not be found." -ForegroundColor Red
        return
    }

    switch ($Command) {
        'status' {
            $col = if ($svc.Status -eq 'Running') { 'Green' } else { 'DarkGray' }
            Write-Host ""
            Write-Host "● $($svc.Name) - $($svc.DisplayName)"
            Write-Host "   State   : " -NoNewline; Write-Host "$($svc.Status)" -ForegroundColor $col
            Write-Host "   Type    : $($svc.ServiceType)"
            Write-Host "   Start   : $($svc.StartType)"
            Write-Host ""
        }
        'start' {
            Write-Host "  Starting $ServiceName..." -ForegroundColor Yellow
            try { Start-Service -Name $ServiceName -ErrorAction Stop; Write-Host "  [OK] Started." -ForegroundColor Green }
            catch { Write-Host "  [Error] $($_.Exception.Message) (Tip: Try prefixing with 'sudo')" -ForegroundColor Red }
        }
        'stop' {
            Write-Host "  Stopping $ServiceName..." -ForegroundColor Yellow
            try { Stop-Service -Name $ServiceName -ErrorAction Stop; Write-Host "  [OK] Stopped." -ForegroundColor Green }
            catch { Write-Host "  [Error] $($_.Exception.Message) (Tip: Try prefixing with 'sudo')" -ForegroundColor Red }
        }
        'restart' {
            Write-Host "  Restarting $ServiceName..." -ForegroundColor Yellow
            try { Restart-Service -Name $ServiceName -ErrorAction Stop; Write-Host "  [OK] Restarted." -ForegroundColor Green }
            catch { Write-Host "  [Error] $($_.Exception.Message) (Tip: Try prefixing with 'sudo')" -ForegroundColor Red }
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Systemctl @args
}

