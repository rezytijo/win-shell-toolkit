# tail.ps1 -- Minimal Linux standard `tail` with real-time follow support
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

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
    try {
        Invoke-Tail @args
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
