# watch.ps1 -- Execute a program periodically
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Linux `watch`, repeatedly runs a command every N secs

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER CommandArgs
    Specifies the CommandArgs parameter.

.PARAMETER Interval
    Specifies the Interval parameter.

.EXAMPLE
    watch
#>

function Invoke-Watch {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$CommandArgs,

        [Alias('n')]
        [int]$Interval = 2
    )

    if (-not $CommandArgs) {
        Write-Host "  Usage: watch [-n interval] <command>"
        Write-Host "  Example: watch -n 5 `"top-proc CPU`""
        return
    }

    $cmdString = $CommandArgs -join ' '
    
    while ($true) {
        Clear-Host
        Write-Host "Every $($Interval).0s: $cmdString" -ForegroundColor DarkGray
        Write-Host ""
        
        try {
            Invoke-Expression $cmdString
        } catch {
            Write-Host "Error executing command: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        Start-Sleep -Seconds $Interval
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Watch @args
}

