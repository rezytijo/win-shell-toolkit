# tail.ps1 -- Minimal Linux standard `tail` with real-time follow support
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Linux `tail`, monitors end of a file cleanly (`-f` auto-updates)

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Path
    Specifies the Path parameter.

.PARAMETER Lines
    Specifies the Lines parameter.

.PARAMETER Follow
    Specifies the Follow parameter.

.EXAMPLE
    tail
#>

function Invoke-Tail {
    param(
        [Parameter(Mandatory=$true, Position=0, HelpMessage="File path to tail")]
        [string]$Path,
        
        [Alias('n')]
        [int]$Lines = 10,
        
        [Alias('f')]
        [switch]$Follow
    )
    
    if (-not (Test-Path $Path)) {
        Write-Host "  [Error] Cannot find file '$Path'" -ForegroundColor Red
        return
    }
    
    Write-Host "  [*] Tailing last $Lines lines of $Path ..." -ForegroundColor DarkGray
    Write-Host ""
    
    try {
        if ($Follow) {
            Get-Content -Path $Path -Tail $Lines -Wait -ErrorAction Stop
        } else {
            Get-Content -Path $Path -Tail $Lines -ErrorAction Stop
        }
    } catch {
        Write-Host "  [Error] $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Tail @args
}

