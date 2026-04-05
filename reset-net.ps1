#Requires -RunAsAdministrator
# reset-net.ps1 -- Network Troubleshooter
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Flushes DNS, releases/renews IP, clears ARP. Support `-Hard` reset

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Hard
    Specifies the Hard parameter.

.EXAMPLE
    reset-net
#>

param(
    [switch]$Hard
)

function Invoke-ResetNetwork {
    $separator = "=========================================="
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   NETWORK RESET PROTOCOL" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  [*] Flushing DNS Cache..." -ForegroundColor Yellow
    ipconfig /flushdns | Out-Null
    Write-Host "      [OK] DNS Flushed." -ForegroundColor Green

    Write-Host "  [*] Releasing IP Address..." -ForegroundColor Yellow
    ipconfig /release | Out-Null
    Write-Host "      [OK] IP Released." -ForegroundColor Green

    Write-Host "  [*] Renewing IP Address..." -ForegroundColor Yellow
    ipconfig /renew | Out-Null
    Write-Host "      [OK] IP Renewed." -ForegroundColor Green

    Write-Host "  [*] Clearing ARP Cache..." -ForegroundColor Yellow
    arp -d * | Out-Null
    Write-Host "      [OK] ARP Cleared." -ForegroundColor Green

    if ($Hard) {
        Write-Host "  [*] Hard Reset: Winsock and Int IP..." -ForegroundColor Red
        netsh winsock reset | Out-Null
        netsh int ip reset | Out-Null
        Write-Host "      [OK] Winsock & IP Catalog Reset." -ForegroundColor Green
        Write-Host "      [!] A SYSTEM RESTART IS REQUIRED." -ForegroundColor Magenta
    }

    Write-Host ""
    Write-Host "  Network reset complete." -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ResetNetwork
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
