# unzip.ps1 -- Instant Extraction Utility
# 2026-03-11 -- v1.0.0: Initial version

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
    Invoke-Unzip @args
}

