# hosts.ps1 -- Edit Windows Hosts File
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Quickly opens the Windows `hosts` file securely as Administrator

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.EXAMPLE
    hosts
#>

function Invoke-Hosts {
    $hostsPath = "$env:WINDIR\System32\drivers\etc\hosts"

    Write-Host "  [*] Requesting elevated privileges to open Hosts file..." -ForegroundColor Yellow

    try {
        Start-Process notepad.exe -ArgumentList $hostsPath -Verb RunAs -ErrorAction Stop
        Write-Host "  [OK] Notepad launched as Administrator." -ForegroundColor Green
    } catch {
        Write-Host "  [Error] Failed to elevate privileges or open Notepad." -ForegroundColor Red
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-Hosts
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
