# pwdc.ps1 -- Print Working Directory and Copy to Clipboard
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Prints the current working directory and instantly copies it to the clipboard.

.DESCRIPTION
    A quick utility to grab the current path without manual selection.
    This script is part of the CustomScripts arsenal.

.EXAMPLE
    pwdc
#>

function Invoke-Pwdc {
    $currentPath = (Get-Location).Path
    $currentPath | Set-Clipboard

    Write-Host ""
    Write-Host "  [PWD Copy]" -ForegroundColor Cyan
    Write-Host "  Path   : " -NoNewline; Write-Host $currentPath -ForegroundColor Green
    Write-Host "  Status : Copied to clipboard! $([char]::ConvertFromUtf32(0x1F4CB))" -ForegroundColor Yellow
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-Pwdc
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
