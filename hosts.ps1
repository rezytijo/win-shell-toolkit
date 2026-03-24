# hosts.ps1 -- Edit Windows Hosts File
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Quickly opens the Windows `hosts` file securely as Administrator

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.EXAMPLE
    hosts
#>

$hostsPath = "$env:WINDIR\System32\drivers\etc\hosts"

Write-Host "  [*] Requesting elevated privileges to open Hosts file..." -ForegroundColor Yellow

try {
    Start-Process notepad.exe -ArgumentList $hostsPath -Verb RunAs
    Write-Host "  [OK] Notepad launched as Administrator." -ForegroundColor Green
} catch {
    Write-Host "  [Error] Failed to elevate privileges or open Notepad." -ForegroundColor Red
}

