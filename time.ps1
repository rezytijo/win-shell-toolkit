# time.ps1 -- Execution time measurement (Linux time equivalent)
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Linux `time`, measures exact elapsed execution length

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER CommandArgs
    Specifies the CommandArgs parameter.

.EXAMPLE
    time
#>

function Invoke-Time {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$CommandArgs
    )
    
    if (-not $CommandArgs) {
        Write-Host "Usage: time <command>"
        return
    }

    $cmdString = $CommandArgs -join ' '
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        Invoke-Expression $cmdString
    } catch {
        Write-Host "Command Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $stopwatch.Stop()
    
    Write-Host ""
    Write-Host "real    $($stopwatch.Elapsed.TotalSeconds.ToString('F3'))s" -ForegroundColor DarkGray
    Write-Host "user    (Win32 Not Trackable)" -ForegroundColor DarkGray
    Write-Host "sys     (Win32 Not Trackable)" -ForegroundColor DarkGray
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-Time @args
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
