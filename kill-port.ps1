# kill-port.ps1 -- Find and terminate process occupying a given port
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Finds and terminates process occupying a specific TCP port

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Port
    Specifies the Port parameter.

.PARAMETER Force
    Specifies the Force parameter.

.EXAMPLE
    kill-port
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="The port number to kill (e.g., 8080)")]
    [int]$Port,
    
    [switch]$Force
)

function Invoke-KillPort {
    $separator = "=========================================="
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   PORT TERMINATION: $Port" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""

    # Find listening connections using netstat
    $connections = netstat -ano | Select-String "LISTENING" | Select-String ":$Port\b"

    if (-not $connections) {
        Write-Host "  [*] No process is listening on port $Port." -ForegroundColor Green
        Write-Host ""
        return
    }

    # Extract Unique PIDs
    $pids = @()
    foreach ($conn in $connections) {
        $parts = $conn.ToString() -split '\s+' | Where-Object { $_ -ne '' }
        $pidNum = $parts[-1]
        
        if ($pidNum -ne "0" -and $pidNum -notin $pids) {
            $pids += $pidNum
        }
    }

    if ($pids.Count -eq 0) {
        Write-Host "  [*] Connection found but could not determine PID (might require Admin)." -ForegroundColor Yellow
        return
    }

    foreach ($pidNum in $pids) {
        try {
            $process = Get-Process -Id $pidNum -ErrorAction Stop
            Write-Host "  [Found] Process : $($process.ProcessName) (PID: $pidNum)" -ForegroundColor Yellow
            
            if ($Force) {
                Stop-Process -Id $pidNum -Force -ErrorAction Stop
                Write-Host "      [Killed] Process terminated successfully." -ForegroundColor Green
            } else {
                $confirm = Read-Host "      Kill this process? (Y/N)"
                if ($confirm -match "^[yY]$") {
                    Stop-Process -Id $pidNum -Force -ErrorAction Stop
                    Write-Host "      [Killed] Process terminated successfully." -ForegroundColor Green
                } else {
                    Write-Host "      [Skipped] Process left running." -ForegroundColor DarkGray
                }
            }
        } catch {
            Write-Host "      [Error] Failed to access/kill PID $pidNum. Consider running as Administrator." -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-KillPort
}

