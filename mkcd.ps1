# mkcd.ps1 -- Make Directory and CD into it
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Creates a new directory and instantly CDs into it

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Path
    Specifies the Path parameter.

.EXAMPLE
    mkcd
#>

# Note: This script MUST be dot-sourced (.) to change the parent shell's location

param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Path of the new directory")]
    [string]$Path
)

function Invoke-Mkcd {
    try {
        if (-not (Test-Path -Path $Path)) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Write-Host "  [OK] Created directory: $Path" -ForegroundColor Green
        } else {
            Write-Host "  [Info] Directory already exists: $Path" -ForegroundColor DarkGray
        }
        
        # Change location
        Set-Location -Path $Path
    } catch {
        Write-Host "  [Error] Failed to create or enter $Path : $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-Mkcd
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
