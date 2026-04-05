# nc.ps1 -- Quick TCP port active scanner (Netcat style)
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Rapid Netcat (`nc`), checks if a TCP port on an IP is open

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER ComputerName
    Specifies the ComputerName parameter.

.PARAMETER Port
    Specifies the Port parameter.

.EXAMPLE
    nc
#>

function Invoke-Nc {
    param(
        [Parameter(Mandatory=$true, Position=0, HelpMessage="Host / IP Address")]
        [string]$ComputerName,
        
        [Parameter(Mandatory=$true, Position=1, HelpMessage="TCP Port")]
        [int]$Port
    )
    
    Write-Host "  [*] Testing TCP Connection to $ComputerName port $Port ... " -NoNewline -ForegroundColor DarkGray
    
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcp.BeginConnect($ComputerName, $Port, $null, $null)
        
        # 3 seconds timeout
        $success = $asyncResult.AsyncWaitHandle.WaitOne([timespan]::FromSeconds(3))
        
        if ($success) {
            $tcp.EndConnect($asyncResult)
            Write-Host "OPEN" -ForegroundColor Green
        } else {
            Write-Host "CLOSED (Timeout)" -ForegroundColor Red
        }
        $tcp.Close()
    } catch {
        Write-Host "CLOSED ($($_.Exception.Message))" -ForegroundColor Red
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-Nc @args
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
