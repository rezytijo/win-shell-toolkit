# pwdc.ps1 -- Print Working Directory and Copy to Clipboard
# 2026-03-16 -- v1.0.0: Initial version

<#
.SYNOPSIS
    Prints the current working directory and instantly copies it to the clipboard.

.DESCRIPTION
    A quick utility to grab the current path without manual selection.
    This script is part of the CustomScripts arsenal.

.EXAMPLE
    pwdc
#>

$currentPath = (Get-Location).Path
$currentPath | Set-Clipboard

Write-Host ""
Write-Host "  [PWD Copy]" -ForegroundColor Cyan
Write-Host "  Path   : " -NoNewline; Write-Host $currentPath -ForegroundColor Green
Write-Host "  Status : Copied to clipboard! 📋" -ForegroundColor Yellow
Write-Host ""
