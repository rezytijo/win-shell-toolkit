# unzip.ps1 -- Instant Extraction Utility
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Extracts `.zip` files seamlessly in the terminal

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Path
    Specifies the Path parameter.

.PARAMETER DestinationPath
    Specifies the DestinationPath parameter.

.EXAMPLE
    unzip
#>

function Invoke-Unzip {
    param(
        [Parameter(Mandatory=$true, Position=0, HelpMessage="Zip File to extract")]
        [string]$Path,
        
        [Parameter(Position=1, HelpMessage="Destination folder (optional)")]
        [string]$DestinationPath = "."
    )
    
    Write-Host "  [*] Extracting $Path ..." -ForegroundColor DarkGray
    
    try {
        Expand-Archive -Path $Path -DestinationPath $DestinationPath -Force -ErrorAction Stop
        Write-Host "  [OK] Extracted to $DestinationPath" -ForegroundColor Green
    } catch {
        Write-Host "  [Error] Extraction failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-Unzip @args
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
