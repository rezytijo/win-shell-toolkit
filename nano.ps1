# nano.ps1 -- Edit files with Administrator privileges (Linux `nano` equivalent)
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Linux `nano`, securely edits protected files as Administrator

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Path
    Specifies the Path parameter.

.EXAMPLE
    nano
#>

function Invoke-Nano {
    param(
        [Parameter(Mandatory=$true, Position=0, HelpMessage="File path to edit")]
        [string]$Path
    )
    
    $resolvedPath = ""
    
    try {
        if (Test-Path $Path) {
            $resolvedPath = (Resolve-Path $Path).Path
        } else {
            # Handle creation of new absolute paths
            $resolvedPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine((Get-Location).Path, $Path))
        }
    } catch {
        $resolvedPath = $Path
    }

    Write-Host "  [*] Opening '$resolvedPath' in elevated Notepad..." -ForegroundColor DarkGray
    Write-Host "  [!] Please accept the UAC prompt if it appears." -ForegroundColor Yellow
    
    try {
        Start-Process -FilePath "notepad.exe" -ArgumentList "`"$resolvedPath`"" -Verb RunAs -ErrorAction Stop
        Write-Host "  [OK] Editor launched securely as Administrator." -ForegroundColor Green
    } catch {
        Write-Host "  [Error] Failed to elevate: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-Nano @args
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
